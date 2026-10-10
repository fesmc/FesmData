# Model domains and their grids, shared by all pipelines (see domains.toml).

using FesmUtils
using TOML

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

A model domain: its base grid and all output grids derived from it (see domains.toml).
"""
struct Domain
    key::String
    folder::String
    base::ProjGrid
    grids::Vector{OutGrid}        # all output grids, base first
end

read_domains() = TOML.parsefile(joinpath(@__DIR__, "domains.toml"))

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
    return Domain(String(key), d["folder"], base, grids)
end

function _derived(g::ProjGrid, factor::Real, name::String)
    isinteger(factor) || error("resolution of $name is not a multiple of the base resolution")
    return coarsen(g, Int(factor); name=name)
end

"""
    folder_grids(folder) -> (Domain, Vector{OutGrid})

Domain whose grids (the domain or one of its crops) are in output folder `folder`, and
those grids.
"""
function folder_grids(folder::AbstractString)
    doms = Domain.(domain_keys())
    found = [(dom, filter(og -> og.folder == folder, dom.grids)) for dom in doms]
    filter!(x -> !isempty(x[2]), found)
    folders = sort(unique(og.folder for dom in doms for og in dom.grids))
    isempty(found) && error("no domain with folder $folder, available: $(join(folders, ", "))")
    length(found) == 1 || error("folder $folder is shared by domains $(join([d.key for (d, _) in found], ", "))")
    return only(found)
end

"Output folders of all domains and crops, i.e. the names of the domains in published records."
domain_folders() = sort(unique(og.folder for key in domain_keys() for og in Domain(key).grids))

"Output folder of a grid: \$ICE_DATA/v2/<folder>/<grid name>."
outdir(og::OutGrid) = joinpath(_env("ICE_DATA"), "v2", og.folder, og.grid.name)
