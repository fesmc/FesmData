# Model domains and their grids, shared by all pipelines (see domains.toml).

using FesmUtils
using TOML

"""
    OutGrid

A grid of a domain together with its output folder under the products folder. A grid
`on_request` (e.g. a Gaussian grid) is not one of the standard grids of the domain: it
is made only for the products that name it. `elevation` is the absolute tolerance (m)
of the elevations and thicknesses written on it (`elevation_precision` of its domain),
or `nothing` for the default (see ../shared/precision.jl).
"""
struct OutGrid
    folder::String
    grid::Union{ProjGrid,LonLatGrid}
    on_request::Bool
    elevation::Union{Nothing,Float64}
end

OutGrid(folder, grid; on_request::Bool=false, elevation=nothing) =
    OutGrid(folder, grid, on_request, elevation === nothing ? nothing : Float64(elevation))

"""
    Domain

A model domain: its base grid and all output grids derived from it (see domains.toml).
For a lon-lat domain (GLOBAL), the grids are global lon-lat grids and the base grid is
the finest.
"""
struct Domain
    key::String
    folder::String
    base::Union{ProjGrid,LonLatGrid}
    grids::Vector{OutGrid}        # all output grids, base first
end

"""
    read_domains() -> Dict

The domains of domains.toml by key, with the nests of each domain
(`[<KEY>.nests.<NEST>]`) as domains of their own, on the projection of their parent
(recorded as `parent`), and active if their parent is, unless set.
"""
function read_domains()
    all = TOML.parsefile(joinpath(@__DIR__, "domains.toml"))
    for (key, d) in collect(all)
        for (nkey, n) in get(d, "nests", Dict())
            haskey(all, nkey) && error("nest $nkey of $key has the key of another domain")
            inherited = Dict(k => d[k] for k in ("elevation_precision",) if haskey(d, k))
            all[nkey] = merge(inherited, n, Dict("proj" => d["proj"], "parent" => key,
                                                 "active" => get(n, "active", get(d, "active", true))))
        end
    end
    return all
end

"""
    domain_keys(; inactive=false)

Keys of the active domains, nests included, or of all domains with `inactive=true`.
An inactive domain (`active = false`) is left out of the releases, figures and the
products made for all domains, but its grids and products are made when it is named.
"""
domain_keys(; inactive::Bool=false) =
    sort([k for (k, d) in read_domains() if inactive || get(d, "active", true)])

function Domain(key::AbstractString)
    all = read_domains()
    haskey(all, key) || error("unknown domain $key, available: $(join(keys(all), ", "))")
    d = all[key]
    res = Float64.(d["resolutions"])
    elevation = get(d, "elevation_precision", nothing)
    if get(d, "type", "projected") == "lonlat"
        grids = [OutGrid(d["folder"], LonLatGrid(grid_name(key, r; units="deg"), r); elevation) for r in res]
        for (t, nlat) in sort(collect(get(d, "gaussian", Dict())))
            push!(grids, OutGrid(d["folder"], gaussian_grid(nlat; name="$key-$t"); on_request=true, elevation))
        end
        return Domain(String(key), d["folder"], grids[1].grid, grids)
    end
    dx = res[1]
    base = ProjGrid(grid_name(key, dx), Tuple(d["xlim"]), Tuple(d["ylim"]), dx, d["proj"])

    # A nest: its grids at the resolutions of its parent are the cells of the parent grids
    # over its extent, the others are derived from its base grid
    pgrids = Dict{Float64,ProjGrid}()           # by resolution, rounded (spacing of the axes)
    if haskey(d, "parent")
        parent = Domain(d["parent"])
        pgrids = Dict(round(spacing(og.grid)[1]; digits=6) => og.grid for og in parent.grids if og.folder == parent.folder)
        any(r -> haskey(pgrids, round(r; digits=6)), res) || error("nest $key shares no resolution with its parent $(parent.key)")
    end
    own = map(res) do r
        pg = get(pgrids, round(r; digits=6), nothing)
        pg === nothing ? _derived(base, r / dx, grid_name(key, r)) : cells_over(pg, base, grid_name(key, r))
    end
    grids = OutGrid[OutGrid(d["folder"], g; elevation) for g in own]
    # Crops: the cells of the grids of the domain over their extent
    for (ckey, c) in get(d, "crops", Dict())
        cbase = _crop_base(base, dx, ckey, c)
        cres = Float64.(get(c, "resolutions", res))
        issubset(cres, res) || error("resolutions of crop $ckey must be resolutions of $key")
        append!(grids, [OutGrid(c["folder"], cells_over(own[findfirst(==(r), res)], cbase, grid_name(ckey, r)); elevation)
                        for r in cres])
    end
    return Domain(String(key), d["folder"], base, grids)
end

"Indices on the lattice of axis `axis` (cell centres, also beyond it) of the cells that overlap the interval `edges`."
function overlapping(axis::AbstractVector, edges)
    r = axis[2] - axis[1]
    return floor(Int, (edges[1] - axis[1]) / r - 0.5 + 1e-6) + 2 : ceil(Int, (edges[2] - axis[1]) / r + 0.5 - 1e-6)
end

"""
    overlap_cells(pg, g) -> (ix, iy)

Indices on the lattice of grid `pg` (also beyond it) of its cells that overlap the
extent of grid `g` (cell edges).
"""
function overlap_cells(pg::ProjGrid, g::ProjGrid)
    hx, hy = spacing(g) ./ 2
    return overlapping(pg.xc, (g.xc[1] - hx, g.xc[end] + hx)), overlapping(pg.yc, (g.yc[1] - hy, g.yc[end] + hy))
end

"""
    cells_over(pg, g, name) -> ProjGrid

The grid `name` of the cells of grid `pg` that overlap the extent of grid `g`: the grid
of a nest or crop (extent of `g`, its base grid) at the resolution of `pg`, a grid of its
parent domain. Its cells are those of `pg` (within it: a coarse grid of the parent may
end short of its base grid at an edge shared with the nest or crop), and do not depend
on the other resolutions.
"""
function cells_over(pg::ProjGrid, g::ProjGrid, name::AbstractString)
    ix, iy = overlap_cells(pg, g)
    ix, iy = intersect(ix, eachindex(pg.xc)), intersect(iy, eachindex(pg.yc))
    length(ix) >= 2 && length(iy) >= 2 ||
        error("grid $name has fewer than 2 cells along x or y in grid $(pg.name) (extent of $(g.name))")
    return ProjGrid(name, pg.xc[ix], pg.yc[iy], pg.proj)
end

function _derived(g::ProjGrid, factor::Real, name::String)
    isinteger(factor) || error("resolution of $name is not a multiple of the base resolution")
    return coarsen(g, Int(factor); name=name)
end

"Base grid of crop `ckey` (table `c` of domains.toml): the base grid of its domain, `base` (resolution `dx`), cut to its extent."
_crop_base(base::ProjGrid, dx, ckey, c) = crop(base, Tuple(c["xlim"]), Tuple(c["ylim"]); name=grid_name(ckey, dx))

"""
    folder_grids(folder) -> (Domain, Vector{OutGrid})

Domain whose grids (the domain or one of its crops) are in output folder `folder`, and
those grids.
"""
function folder_grids(folder::AbstractString)
    doms = Domain.(domain_keys(; inactive=true))
    found = [(dom, filter(og -> og.folder == folder, dom.grids)) for dom in doms]
    filter!(x -> !isempty(x[2]), found)
    folders = sort(unique(og.folder for dom in doms for og in dom.grids))
    isempty(found) && error("no domain with folder $folder, available: $(join(folders, ", "))")
    length(found) == 1 || error("folder $folder is shared by domains $(join([d.key for (d, _) in found], ", "))")
    return only(found)
end

"""
    folder_base(folder) -> ProjGrid

Base grid of the domain, nest or crop with output folder `folder`; for a crop, the base
grid of its domain cut to the crop (at the base resolution, also if the crop has only
coarser grids).
"""
function folder_base(folder::AbstractString)
    dom, _ = folder_grids(folder)
    dom.folder == folder && return dom.base
    d = read_domains()[dom.key]
    ckey, c = only((k, c) for (k, c) in get(d, "crops", Dict()) if c["folder"] == folder)
    return _crop_base(dom.base, Float64(d["resolutions"][1]), ckey, c)
end

"""
    folder_option(args) -> (args, folder)

The arguments of a pipeline step without the option `--folder=<FOLDER>`, and FOLDER, or
`nothing` without it: the step then makes only the grids in output folder FOLDER (e.g.
the grids added to a crop), see `in_folder`.
"""
function folder_option(args)
    opts = filter(startswith("--folder="), args)
    length(opts) <= 1 || error("--folder given more than once")
    folder = isempty(opts) ? nothing : String(split(only(opts), "="; limit=2)[2])
    return filter(!startswith("--folder="), args), folder
end

"The grids `grids` (of domain `dom`) in output folder `folder`, or all of them if `nothing`."
function in_folder(grids::AbstractVector{OutGrid}, folder, dom::Domain)
    folder === nothing && return grids
    sel = filter(og -> og.folder == folder, grids)
    isempty(sel) && error("no grids of $(dom.key) in folder $folder")
    return sel
end

"Output folders of all domains and crops (also inactive), i.e. the names of the domains in published records."
domain_folders() = sort(unique(og.folder for key in domain_keys(; inactive=true) for og in Domain(key).grids))

"Output folder of a grid: <products>/<folder>/<grid name> (see `fesmdata_dir`)."
outdir(og::OutGrid) = joinpath(fesmdata_dir("products"), og.folder, og.grid.name)
