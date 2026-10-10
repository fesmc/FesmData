# NetCDF output shared by all pipelines: fields on a grid, grid files, and the
# provenance attributes of every file.

using FesmUtils
using NCDatasets

include(joinpath(@__DIR__, "provenance.jl"))

const FILLVALUE = -9999f0

"Units and long names of the fields written by the pipeline."
const VARINFO = Dict(
    "z_bed"    => ("m", "bed elevation"),
    "z_srf"    => ("m", "surface elevation"),
    "H_ice"    => ("m", "ice thickness"),
    "z_bed_sd" => ("m", "standard deviation of bed elevation within the cell"),
    "f_ocn"    => ("1", "area fraction of ice-free ocean"),
    "f_land"   => ("1", "area fraction of ice-free land"),
    "f_grnd"   => ("1", "area fraction of grounded ice"),
    "f_flt"    => ("1", "area fraction of floating ice"),
    "f_ice"    => ("1", "area fraction of glacier ice"),
    "f_valid"  => ("1", "area fraction covered by source data"),
    "mask"     => ("1", "dominant surface type"),
    "src_id"   => ("1", "source with the largest weight"),
)

"""
    Dim(name, values, attrib)

A dimension of fields besides the grid (e.g. month, time, depth), with the values and
attributes of its coordinate variable.
"""
struct Dim
    name::String
    values::Vector
    attrib::Vector{Pair{String,Any}}
end

"""
    write_fields(path, g, fields; dataset, attrib=[], varattrib=Dict(), dims=Dict())

Write the fields on grid `g` (projected or lon-lat) to a new NetCDF file of `dataset` (e.g. "topo"), with
the provenance attributes of the dataset and the global attributes `attrib`. A field
is 2D, or has the extra dimensions `dims[name]` (a vector of `Dim`) after the grid
dimensions. Float fields are written as Float32 with NaN as missing; integer fields
(e.g. masks) are written as they are, with a fill value if they have missing values.
`varattrib[name]` gives extra attributes of a variable (e.g. flag values), and
replaces its default units or long name.
"""
function write_fields(path::AbstractString, g::Union{ProjGrid,LonLatGrid}, fields::AbstractDict; dataset::AbstractString,
                      attrib=Pair{String,String}[], varattrib=Dict{String,Vector{Pair{String,Any}}}(),
                      dims=Dict{String,Vector{Dim}}())
    gatts = global_attrib(dataset, attrib)
    mapping = g isa ProjGrid ? ["grid_mapping" => "crs"] : Pair{String,String}[]
    extra = Dict{String,Dim}()
    for ds in values(dims), d in ds
        haskey(extra, d.name) && extra[d.name].values != d.values && error("dimension $(d.name) differs between fields")
        extra[d.name] = d
    end
    mkpath(dirname(path))
    NCDataset(path, "c") do ds
        init_grid_nc!(ds, g)
        foreach(((k, v),) -> ds.attrib[k] = v, gatts)
        for d in sort(collect(values(extra)); by=d -> d.name)
            defVar(ds, d.name, d.values, (d.name,); attrib=d.attrib)
        end
        for name in sort(collect(keys(fields)))
            units, long_name = get(VARINFO, name, ("", name))
            atts = get(varattrib, name, Pair{String,Any}[])
            given = Set(first.(atts))
            atts = vcat(filter(p -> !(first(p) in given), vcat(["units" => units, "long_name" => long_name], mapping)),
                        atts)
            vdims = (grid_dims(g)..., (d.name for d in get(dims, name, Dim[]))...)
            F = fields[name]
            if nonmissingtype(eltype(F)) <: Integer
                if any(ismissing, F)
                    T = nonmissingtype(eltype(F))
                    T = typemin(T) <= -9999 ? T : Int32
                    defVar(ds, name, Array{Union{Missing,T}}(F), vdims; fillvalue=T(-9999), deflatelevel=1,
                           shuffle=true, attrib=atts)
                else
                    defVar(ds, name, Array{nonmissingtype(eltype(F))}(F), vdims; deflatelevel=1, shuffle=true,
                           attrib=atts)
                end
            else
                defVar(ds, name, replace(Float32.(F), NaN32 => FILLVALUE), vdims;
                       fillvalue=FILLVALUE, deflatelevel=1, shuffle=true, attrib=atts)
            end
        end
    end
    return path
end

"""
    read_fields(path) -> (grid, fields)

Read all 2D fields of a file written by `write_fields` (missing = NaN).
"""
function read_fields(path::AbstractString)
    NCDataset(path) do ds
        g = ProjGrid(ds.attrib["grid_name"], ds["xc"][:], ds["yc"][:], ds["crs"].attrib["proj_params"])
        fields = Dict{String,Matrix}()
        for (name, v) in ds
            dimnames(v) == ("xc", "yc") || continue
            A = v[:, :]
            fields[name] = eltype(A) <: Union{Missing,Integer} ? A : nomissing(A, NaN32)
        end
        return g, fields
    end
end

"""
    write_grid_files(dir, g; dataset)

Write the grid description file (grid_<GRID>.txt, cdo format) and the grid file
(<GRID>_grid.nc, with the provenance attributes of `dataset`) of grid `g` to `dir`.
"""
function write_grid_files(dir::AbstractString, g::Union{ProjGrid,LonLatGrid}; dataset::AbstractString)
    mkpath(dir)
    write_griddes(joinpath(dir, "grid_$(g.name).txt"), g)
    path = write_grid_nc(joinpath(dir, "$(g.name)_grid.nc"), g)
    NCDataset(path, "a") do ds
        foreach(((k, v),) -> ds.attrib[k] = v, global_attrib(dataset))
    end
    return dir
end

"Global attributes of a file of `dataset`: its provenance attributes, then `attrib`."
function global_attrib(dataset::AbstractString, attrib=Pair{String,String}[])
    for (k, v) in attrib
        k in PROVENANCE_KEYS && error("global attribute $k is reserved for provenance")
    end
    return vcat(provenance_attrib(dataset), attrib)
end
