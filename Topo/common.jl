# Shared definitions for the topography v2 scripts: domains, grids and paths.

using FesmUtils
using DataManifest
using TOML
using NCDatasets

const TOPO_DIR = @__DIR__
const REPO_DIR = dirname(TOPO_DIR)

"""
    OutGrid

A grid of a domain together with its output folder under \$ICE_DATA/v2.
"""
struct OutGrid
    folder::String
    grid::ProjGrid
end

"""
    Domain

A domain of the pipeline (see domains.toml).
"""
struct Domain
    key::String
    folder::String
    base::ProjGrid
    grids::Vector{OutGrid}        # all output grids, base first
    products::Dict{String,Vector{String}}
    rho_ice::Float64              # densities for flotation (kg m-3)
    rho_sw::Float64
end

read_domains() = TOML.parsefile(joinpath(TOPO_DIR, "domains.toml"))

domain_keys() = collect(keys(read_domains()))

function Domain(key::AbstractString)
    all = read_domains()
    haskey(all, key) || error("unknown domain $key, available: $(join(keys(all), ", "))")
    d = all[key]
    res = Float64.(d["resolutions"])
    dx = res[1]
    base = ProjGrid(grid_name(key, dx), Tuple(d["xlim"]), Tuple(d["ylim"]), dx, d["proj"])

    grids = OutGrid[]
    for r in res
        push!(grids, OutGrid(d["folder"], _derived(base, r / dx, grid_name(key, r))))
    end
    for (ckey, c) in get(d, "crops", Dict())
        cbase = crop(base, Tuple(c["xlim"]), Tuple(c["ylim"]); name=grid_name(ckey, dx))
        for r in res
            push!(grids, OutGrid(c["folder"], _derived(cbase, r / dx, grid_name(ckey, r))))
        end
    end
    products = Dict{String,Vector{String}}(k => Vector{String}(v) for (k, v) in d["products"])
    return Domain(String(key), d["folder"], base, grids, products, d["rho_ice"], d["rho_sw"])
end

function _derived(g::ProjGrid, factor::Real, name::String)
    isinteger(factor) || error("resolution of $name is not a multiple of the base resolution")
    return coarsen(g, Int(factor); name=name)
end

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

function _env(name)
    haskey(ENV, name) || error("environment variable $name is not set (source Topo/machines/<machine>.env)")
    return ENV[name]
end

"Output folder of a grid: \$ICE_DATA/v2/<folder>/<grid name>."
outdir(og::OutGrid) = joinpath(_env("ICE_DATA"), "v2", og.folder, og.grid.name)

"Folder for intermediate files: \$FESMDATA_WORK/topo."
workdir() = joinpath(_env("FESMDATA_WORK"), "topo")

"DataManifest database of the original datasets."
manifest() = read_dataset(joinpath(REPO_DIR, "datamanifest.toml"); persist=false)

# ---------------------------------------------------------------------------
# Field files
# ---------------------------------------------------------------------------

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
    "f_valid"  => ("1", "area fraction covered by source data"),
)

"""
    write_fields(path, g, fields; attrib=[])

Write the 2D fields (NaN = missing) on grid `g` to a new NetCDF file.
"""
function write_fields(path::AbstractString, g::ProjGrid, fields::AbstractDict; attrib=Pair{String,String}[])
    mkpath(dirname(path))
    NCDataset(path, "c") do ds
        init_grid_nc!(ds, g)
        for (k, v) in attrib
            ds.attrib[k] = v
        end
        for name in sort(collect(keys(fields)))
            units, long_name = get(VARINFO, name, ("", name))
            F = replace(Float32.(fields[name]), NaN32 => FILLVALUE)
            defVar(ds, name, F, ("xc", "yc"); fillvalue=FILLVALUE, deflatelevel=1, shuffle=true,
                   attrib=["units" => units, "long_name" => long_name, "grid_mapping" => "crs"])
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
        fields = Dict{String,Matrix{Float32}}()
        for (name, v) in ds
            dimnames(v) == ("xc", "yc") || continue
            fields[name] = nomissing(v[:, :], NaN32)
        end
        return g, fields
    end
end

"Intermediate file of a source remapped onto the base grid of a domain."
source_file(dom::Domain, source::AbstractString) =
    joinpath(workdir(), dom.base.name, "$(dom.base.name)_$(source).nc")
