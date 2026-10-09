# Shared definitions for the topography v2 scripts: domains, grids and paths.

using FesmUtils
using DataManifest
using TOML

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
    return Domain(String(key), d["folder"], base, grids, products)
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
