# Model domains and their grids, shared by all pipelines (see domains.toml).

using FesmUtils
using TOML

"""
    OutGrid

A grid of a domain together with its output folder under \$ICE_DATA/v2. A grid
`on_request` (e.g. a Gaussian grid) is not one of the standard grids of the domain: it
is made only for the products that name it.
"""
struct OutGrid
    folder::String
    grid::Union{ProjGrid,LonLatGrid}
    on_request::Bool
end

OutGrid(folder, grid) = OutGrid(folder, grid, false)

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
            all[nkey] = merge(n, Dict("proj" => d["proj"], "parent" => key,
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
    if get(d, "type", "projected") == "lonlat"
        grids = [OutGrid(d["folder"], LonLatGrid(grid_name(key, r; units="deg"), r)) for r in res]
        for (t, nlat) in sort(collect(get(d, "gaussian", Dict())))
            push!(grids, OutGrid(d["folder"], gaussian_grid(nlat; name="$key-$t"), true))
        end
        return Domain(String(key), d["folder"], grids[1].grid, grids)
    end
    dx = res[1]
    base = ProjGrid(grid_name(key, dx), Tuple(d["xlim"]), Tuple(d["ylim"]), dx, d["proj"])

    grids = OutGrid[]
    for r in res
        push!(grids, OutGrid(d["folder"], _derived(base, r / dx, grid_name(key, r))))
    end
    for (ckey, c) in get(d, "crops", Dict())
        cbase = _crop_base(base, dx, ckey, c)
        cres = Float64.(get(c, "resolutions", res))
        issubset(cres, res) || error("resolutions of crop $ckey must be resolutions of $key")
        for r in cres
            push!(grids, OutGrid(c["folder"], _derived(cbase, r / dx, grid_name(ckey, r))))
        end
    end
    haskey(d, "parent") && _check_nest(key, grids, Domain(d["parent"]))
    return Domain(String(key), d["folder"], base, grids)
end

# A nest shares at least one resolution with its parent, and its grids at these
# resolutions lie on the grids of its parent: same cell centres, inside its extent.
function _check_nest(key, grids::Vector{OutGrid}, parent::Domain)
    pgrids = [og.grid for og in parent.grids if og.folder == parent.folder]
    same(g) = findfirst(pg -> isapprox(spacing(pg)[1], spacing(g)[1]; rtol=1e-6), pgrids)
    shared = filter(og -> same(og.grid) !== nothing, grids)
    isempty(shared) && error("nest $key shares no resolution with its parent $(parent.key)")
    for og in shared
        g, pg = og.grid, pgrids[same(og.grid)]
        r = spacing(pg)[1]
        on(c, pc) = isapprox((c - pc[1]) / r, round((c - pc[1]) / r); atol=1e-6) &&
                    pc[1] - 1e-6r <= c && c <= pc[end] + 1e-6r
        (on(g.xc[1], pg.xc) && on(g.yc[1], pg.yc) && on(g.xc[end], pg.xc) && on(g.yc[end], pg.yc)) ||
            error("grid $(g.name) of nest $key is not on grid $(pg.name) of its parent $(parent.key)")
    end
    return nothing
end

"Base grid of crop `ckey` (table `c` of domains.toml): the base grid of its domain, `base` (resolution `dx`), cut to its extent."
_crop_base(base::ProjGrid, dx, ckey, c) = crop(base, Tuple(c["xlim"]), Tuple(c["ylim"]); name=grid_name(ckey, dx))

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

"Output folders of all domains and crops (also inactive), i.e. the names of the domains in published records."
domain_folders() = sort(unique(og.folder for key in domain_keys(; inactive=true) for og in Domain(key).grids))

"Output folder of a grid: \$ICE_DATA/v2/<folder>/<grid name>."
outdir(og::OutGrid) = joinpath(_env("ICE_DATA"), "v2", og.folder, og.grid.name)
