# Domains at a point, for `fesmdata.jl where`: the domains, crops and nests whose grids
# contain a longitude and latitude, with the datasets on them. In the Publish
# environment (projections with Proj).

import Proj

include(joinpath(@__DIR__, "discover.jl"))
include(joinpath(REPO_DIR, "shared", "domains.jl"))

"""
    folder_extents() -> Dict{String,Any}

Extent of the grids of each output folder (domain, crop or nest), as the cell edges of
its finest grid on the projection of its domain, (x0, x1, y0, y1) in km, or `nothing`
for a lon-lat domain (global).
"""
function folder_extents()
    finest = Dict{String,Any}()
    for key in domain_keys(; inactive=true), og in Domain(key).grids
        g = og.grid
        g isa ProjGrid || (finest[og.folder] = nothing; continue)
        dx, dy = spacing(g)
        old = get(finest, og.folder, (dx=Inf,))
        dx < old.dx && (finest[og.folder] = (dx=dx, extent=(g.xc[1] - dx / 2, g.xc[end] + dx / 2,
                                                            g.yc[1] - dy / 2, g.yc[end] + dy / 2)))
    end
    return Dict(f => e === nothing ? nothing : e.extent for (f, e) in finest)
end

"""
    domains_at(lon, lat; sandbox=false)

`fesmdata.jl where <lon> <lat>`: the domains, crops and nests whose grids contain the
point (degrees east and north), in the order of ../shared/domains.toml, with their
kind, grids, the position of the point on their projection (km), and the datasets
released on them or that they get by cropping.
"""
function domains_at(lon::Real, lat::Real; sandbox::Bool=false)
    -180 <= lon <= 360 && -90 <= lat <= 90 || error("where: give a longitude (-180 to 360) and a latitude (-90 to 90)")
    extents = folder_extents()
    cat = RegistryCatalog(; sandbox=sandbox)
    datasets(folder) = join(sort(unique([[s for (d, s) in cat.records if d == folder];
                                         [c.dataset for c in cat.crops if c.folder == folder]])), " ")
    rows = []
    for r in domain_rows()
        e = extents[r.folder]
        if e === nothing
            push!(rows, (r, ""))
            continue
        end
        x, y = Proj.Transformation("EPSG:4326", r.proj; always_xy=true)(lon, lat)
        e[1] <= x <= e[2] && e[3] <= y <= e[4] && push!(rows, (r, "$(round(x; digits=1)), $(round(y; digits=1))"))
    end
    kind(r) = (r.kind == "domain" ? "domain" : "$(r.kind) of $(r.parent)") * (r.active ? "" : " (inactive)")
    cols = [("Folder", (r, _) -> r.folder), ("Kind", (r, _) -> kind(r)), ("Grids", (r, _) -> resolutions_text(r)),
            ("x, y (km)", (_, xy) -> xy), ("Datasets", (r, _) -> datasets(r.folder))]
    widths = [maximum(length(f(r...)) for r in rows; init=length(h)) + 2 for (h, f) in cols]
    println(join(rpad(h, w) for ((h, _), w) in zip(cols, widths)) |> rstrip)
    for r in rows
        println(join(rpad(f(r...), w) for ((_, f), w) in zip(cols, widths)) |> rstrip)
    end
end
