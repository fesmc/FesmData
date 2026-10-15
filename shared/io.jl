# NetCDF output shared by all pipelines: fields on a grid, grid files, and the
# provenance attributes and precision of every file.

using FesmUtils
using NCDatasets

include(joinpath(@__DIR__, "provenance.jl"))
include(joinpath(@__DIR__, "precision.jl"))

const FILLVALUE = -9999f0

"Deflate level of all fields (with shuffle): smaller files than level 1, as fast to write and read."
const DEFLATE_LEVEL = 4

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
    "lon2D"    => ("degrees_east", "longitude of the cell centre"),
    "lat2D"    => ("degrees_north", "latitude of the cell centre"),
    "area"     => ("m^2", "area of the cell"),
)

"""
    Dim(name, values, attrib, bounds=nothing)

A dimension of fields besides the grid (e.g. month, time, depth), with the values and
attributes of its coordinate variable, and the cell bounds (2 x n) of its CF `bounds`
attribute, if it has one.
"""
struct Dim
    name::String
    values::Vector
    attrib::Vector{Pair{String,Any}}
    bounds::Union{Nothing,Matrix}
end

Dim(name, values, attrib) = Dim(name, values, attrib, nothing)

"""
    AuxVar(name, data, dims, attrib)

A variable off the grid, written as it is next to the fields, with its raw data, its
dimensions (`Dim`) and attributes: on extra dimensions of the fields (e.g. the labels of
time slices, `label(time)`), or on dimensions of its own (e.g. an annual time series
next to fields every 10 years, a section of the overturning streamfunction).
"""
struct AuxVar
    name::String
    data::Array
    dims::Vector{Dim}
    attrib::Vector{Pair{String,Any}}
end

"""
    write_fields(path, g, fields; dataset, attrib=[], varattrib=Dict(), dims=Dict(), aux=[],
                 precision=Dict(), elevation=nothing, lossless=false)

Write the fields on grid `g` (projected or lon-lat) to a new NetCDF file of `dataset` (e.g. "topo"), with
the provenance attributes of the dataset and the global attributes `attrib`. A field
is 2D, or has the extra dimensions `dims[name]` (a vector of `Dim`) after the grid
dimensions. Float fields are written as Float32 with NaN as missing, rounded to the
default precision of their kind (`default_precision`, by name and units; elevations and
thicknesses to `elevation` m if given, the `elevation_precision` of the domain of the
grid, see `OutGrid`) or to `precision[name]` (a `Precision`), recorded in their
attributes (see `round_field!`);
with `lossless`, they are not rounded (intermediate files read again by a pipeline).
Integer fields (e.g. masks) are written as they are, with a fill value if they have
missing values. `varattrib[name]` gives extra attributes of a variable (e.g. flag
values), and replaces its default units or long name. `aux` are variables off the grid
(`AuxVar`, e.g. labels of time slices), written as they are, with their dimensions
(those also of the fields must be the same). The file
is written as `<path>.part` and renamed when complete, so that an interrupted job
leaves no partial file at `path`.
"""
function write_fields(path::AbstractString, g::Union{ProjGrid,LonLatGrid}, fields::AbstractDict; dataset::AbstractString,
                      attrib=Pair{String,String}[], varattrib=Dict{String,Vector{Pair{String,Any}}}(),
                      dims=Dict{String,Vector{Dim}}(), aux=AuxVar[], precision=Dict{String,Precision}(),
                      elevation=nothing,
                      lossless::Bool=false)
    floats = [name for (name, F) in fields if !(nonmissingtype(eltype(F)) <: Integer)]
    unknown = setdiff(keys(precision), floats)
    isempty(unknown) || error("precision of $(join(unknown, ", ")): not float fields of $(basename(path))")
    gatts = global_attrib(dataset, attrib)
    mapping = g isa ProjGrid ? ["grid_mapping" => "crs"] : Pair{String,String}[]
    extra = Dict{String,Dim}()
    for d in Iterators.flatten((Iterators.flatten(values(dims)), (d for a in aux for d in a.dims)))
        haskey(extra, d.name) && extra[d.name].values != d.values &&
            error("dimension $(d.name) differs between fields or variables off the grid")
        extra[d.name] = d
    end
    mkpath(dirname(path))
    part = path * ".part"
    NCDataset(part, "c") do ds
        init_grid_nc!(ds, g)
        foreach(((k, v),) -> ds.attrib[k] = v, gatts)
        for d in sort(collect(values(extra)); by=d -> d.name)
            defVar(ds, d.name, d.values, (d.name,); attrib=d.attrib)
            if d.bounds !== nothing
                haskey(ds.dim, "bnds") || defDim(ds, "bnds", 2)
                defVar(ds, Dict(d.attrib)["bounds"], d.bounds, ("bnds", d.name))
            end
        end
        for a in aux
            fill = [k => v for (k, v) in a.attrib if k == "_FillValue"]
            atts = filter(p -> first(p) != "_FillValue", a.attrib)
            defVar(ds, a.name, a.data, Tuple(d.name for d in a.dims); attrib=atts, (isempty(fill) ? () : (fillvalue=last(only(fill)),))...)
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
                # Type written: that of the field, widened to Int32 if the fill value -9999
                # does not fit; flag_values must have the same type (CF)
                T = nonmissingtype(eltype(F))
                fill = any(ismissing, F)
                fill && typemin(T) > -9999 && (T = Int32)
                atts = [k == "flag_values" ? k => T.(v) : k => v for (k, v) in atts]
                if fill
                    defVar(ds, name, Array{Union{Missing,T}}(F), vdims; fillvalue=T(-9999),
                           deflatelevel=DEFLATE_LEVEL, shuffle=true, attrib=atts)
                else
                    defVar(ds, name, Array{T}(F), vdims; deflatelevel=DEFLATE_LEVEL, shuffle=true, attrib=atts)
                end
            else
                A = Float32.(F)
                if !lossless
                    units = string(Dict(atts)["units"])
                    p = get(() -> default_precision(name, units; elevation), precision, name)
                    atts = vcat(atts, round_field!(A, p, units))
                end
                defVar(ds, name, replace!(A, NaN32 => FILLVALUE), vdims;
                       fillvalue=FILLVALUE, deflatelevel=DEFLATE_LEVEL, shuffle=true, attrib=atts)
            end
        end
    end
    mv(part, path; force=true)
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
(<GRID>_grid.nc, the fields of `grid_fields`, with the provenance attributes of
`dataset`) of grid `g` to `dir`.
"""
function write_grid_files(dir::AbstractString, g::Union{ProjGrid,LonLatGrid}; dataset::AbstractString)
    mkpath(dir)
    write_griddes(joinpath(dir, "grid_$(g.name).txt"), g)
    write_fields(joinpath(dir, "$(g.name)_grid.nc"), g, grid_fields(g); dataset)
    return dir
end

"""
    grid_fields(g) -> Dict

Fields of the grid file of `g`: the longitude `lon2D` and latitude `lat2D` of the cell
centres of a projected grid (those of a lon-lat grid are its axes), and the area of the
cells `area` (m²), as FesmUtils `write_grid_nc`.
"""
function grid_fields(g::ProjGrid)
    lon, lat = lonlat(g)
    return Dict{String,Matrix}("lon2D" => lon, "lat2D" => lat, "area" => cell_area(g, lon, lat))
end

grid_fields(g::LonLatGrid) = Dict{String,Matrix}("area" => cell_area(g))

"Global attributes of a file of `dataset`: its provenance attributes, then `attrib`."
function global_attrib(dataset::AbstractString, attrib=Pair{String,String}[])
    for (k, v) in attrib
        k in PROVENANCE_KEYS && error("global attribute $k is reserved for provenance")
    end
    return vcat(provenance_attrib(dataset), attrib)
end
