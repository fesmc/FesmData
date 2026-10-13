# Figures of the topography (Topo): the products of each domain side by side, and the
# resolutions of the grids around an outlet glacier.

"Options of the figures of the topography (see `plot_gridded`); colours by domain, see `topo_figure`."
const TOPO_FIGURE = Dict{String,Any}("variables" => ["z_bed", "H_ice"], "hide" => Dict("H_ice" => 0))

"""
    topo_figure(panels) -> Dict

Options of a figure of the topography (`TOPO_FIGURE`) with colours from the data of its
panels (0.5-99.5%): the bed centred on sea level and symmetric (oleron) where it reaches
below sea level, as on the ice sheets, up to the land elevations (deeper ocean
saturates), otherwise over the range of the land elevations (batlow), as on the
mountain-glacier domains; the ice thickness from 0 (ice).
"""
function topo_figure(panels::Vector{Panel})
    z, h = Float64[], Float64[]
    for p in panels
        NCDataset(p.path) do ds
            append!(z, ds["z_bed"][:, :])
            append!(h, ds["H_ice"][:, :])
        end
    end
    zmap, zrange, hrange = topo_colors(z, h)
    return merge(TOPO_FIGURE, Dict{String,Any}("colormap" => Dict("z_bed" => zmap, "H_ice" => "ice"),
                                               "colorrange" => Dict("z_bed" => zrange, "H_ice" => hrange)))
end

"""
    topo_colors(z, h) -> (colormap, range of z, range of h)

Colours of the elevations `z` and ice thicknesses `h` of a figure of the topography
(0.5-99.5% of their values, see `topo_figure`).
"""
function topo_colors(z, h)
    z = filter(isfinite, Float64.(coalesce.(z, NaN)))
    h = filter(x -> isfinite(x) && x > 0, Float64.(coalesce.(h, NaN)))
    lo, hi = quantile(z, (0.005, 0.995))
    if lo < 0
        r = round_up(max(hi, 1.0))
        zmap, zrange = "oleron", [-r, r]
    else
        step = round_up((hi - lo) / 10)
        zmap, zrange = "batlow", [floor(lo / step) * step, max(ceil(hi / step), floor(lo / step) + 1) * step]
    end
    return zmap, zrange, [0, isempty(h) ? 1.0 : round_up(quantile(h, 0.995))]
end

"Topo products of a domain: its default products, then its variants (../Topo/products.toml)."
function topo_products(key::AbstractString)
    p = read_products()[key]
    return [sort(collect(keys(p["products"]))); sort(collect(keys(get(p, "variants", Dict()))))]
end

"`v` rounded up to a multiple of half its power of 10 (e.g. 3800 to 4000, 420 to 450)."
function round_up(v::Real)
    s = 10.0^floor(log10(v)) / 2
    return ceil(v / s - 1e-9) * s
end

"Outlet glacier of the figure of the resolutions: Jakobshavn Isbræ, a window of 300 km on GRL-PAL."
const TOPO_ZOOM = (key="GRL-PAL", product="BedMachine-v6", lon=-49.0, lat=69.17, half_km=150.0,
                   resolutions=["GRL-PAL-1KM", "GRL-PAL-4KM", "GRL-PAL-16KM"])

"""
    topo_figures() -> Vector{GalleryItem}

The figures of the topography: for each domain, its products (default products, then
variants) on one grid; and the bed of an outlet glacier on grids of three resolutions.
"""
function topo_figures()
    items = GalleryItem[]
    for key in sort(topo_domains(); by=k -> something(findfirst(==(Domain(k).folder), FOLDER_ORDER), 99))
        dom = Domain(key)
        og = only(figure_grids(filter(og -> og.folder == dom.folder, dom.grids)))
        products = topo_products(key)
        file = "Topo-$(dom.folder).png"
        panels = [Panel(og, product_file(og, pr), pr, nothing) for pr in products]
        caption = plot_gridded(joinpath(figures_dir("Topo"), file), "Topo of $(dom.folder)", panels, String[],
                               topo_figure(panels))
        println("wrote $file")
        push!(items, GalleryItem(dom.folder, file, caption))
    end
    z = TOPO_ZOOM
    grids = Dict(og.grid.name => og for og in Domain(z.key).grids)
    x, y = project(grids[z.resolutions[1]], [z.lon], [z.lat])
    window = (x[1] - z.half_km, x[1] + z.half_km, y[1] - z.half_km, y[1] + z.half_km)
    file = "Topo-resolutions.png"
    plot_gridded(joinpath(figures_dir("Topo"), file), "Topo resolutions",
                 [Panel(grids[g], product_file(grids[g], z.product), g, window) for g in z.resolutions], String[],
                 merge(TOPO_FIGURE, Dict("variables" => ["z_bed"], "colormap" => "oleron", "colorrange" => [-1500, 1500])))
    println("wrote $file")
    push!(items, GalleryItem("Resolutions", file,
                             "Bed elevation of $(z.product) around Jakobshavn Isbræ (300 km × 300 km) on $(join(z.resolutions, ", "))."))
    return items
end
