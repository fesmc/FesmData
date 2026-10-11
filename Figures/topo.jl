# Figures of the topography (Topo): the products of each domain side by side, and the
# resolutions of the grids around an outlet glacier.

"Options of the figures of the topography (see `plot_gridded`)."
const TOPO_FIGURE = Dict{String,Any}("variables" => ["z_bed", "H_ice"], "hide" => Dict("H_ice" => 0),
                                     "colormap" => Dict("z_bed" => "oleron", "H_ice" => "ice"),
                                     "colorrange" => Dict("z_bed" => [-4000, 4000], "H_ice" => [0, 4000]))

"Outlet glacier of the figure of the resolutions: Jakobshavn Isbræ, a window of 150 km on GRL-PAL."
const TOPO_ZOOM = (key="GRL-PAL", product="BedMachine-v6", lon=-49.8, lat=69.17, half_km=75.0,
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
        p = read_products()[key]
        products = [sort(collect(keys(p["products"]))); sort(collect(keys(get(p, "variants", Dict()))))]
        file = "Topo-$(dom.folder).png"
        caption = plot_gridded(joinpath(figures_dir("Topo"), file), "Topo of $(dom.folder)",
                               [Panel(og, product_file(og, pr), pr, nothing) for pr in products], String[], TOPO_FIGURE)
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
                 merge(TOPO_FIGURE, Dict("variables" => ["z_bed"])))
    println("wrote $file")
    push!(items, GalleryItem("Resolutions", file,
                             "Bed elevation of $(z.product) around Jakobshavn Isbræ (150 km × 150 km) on $(join(z.resolutions, ", "))."))
    return items
end
