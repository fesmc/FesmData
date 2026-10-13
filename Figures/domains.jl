# Overview figures of the domains, linked from the table of the domains of the website
# (docs/domains.qmd): for each Topo product of a domain, its topography together with the
# regions, zones and basins of the domain, on one fine grid.

"Most cells along the longer side of the grid of an overview figure."
const MAX_OVERVIEW_CELLS = 1600

"Height of a map of an overview figure (units of the layout)."
const OVERVIEW_PANEL_HEIGHT = 420

"Maps per row of an overview figure."
const OVERVIEW_COLUMNS = 3

"Most classes of a map of an overview figure with a colour bar (more, e.g. the basins of a fine basin set: none)."
const MAX_LEGEND_CLASSES = 30

"Overview figure of a Topo product of a domain: Domains/<folder>_TOPO-<product>.png."
overview_file(dom::Domain, product::AbstractString) = "$(dom.folder)_TOPO-$product.png"

"""
    domain_overviews() -> Vector{String}

The overview figures of all domains with Topo products, one per product (default
products and variants), in docs/figures/Domains/; returns their paths.
"""
function domain_overviews()
    dir = figures_dir("Domains")
    mkpath(dir)
    paths = String[]
    for key in topo_domains()
        dom = Domain(key)
        og = shown_grid(filter(og -> og.folder == dom.folder, dom.grids), MAX_OVERVIEW_CELLS)
        for product in topo_products(key)
            path = joinpath(dir, overview_file(dom, product))
            domain_overview(path, dom, og, product)
            println("wrote $(basename(path)) ($(round(Int, filesize(path) / 1e3)) kB)")
            push!(paths, path)
        end
    end
    return paths
end

"""
    domain_overview(path, dom, og, product)

The overview figure of Topo `product` of domain `dom` on grid `og`: bed and surface
elevation (above sea level) and ice thickness (colours as the figures of Topo,
`topo_colors`), the three levels of the regions labelled by path and name, the zones,
and the basins of each basin set of the domain (those made on the grid; blank outside
the basins).
"""
function domain_overview(path::AbstractString, dom::Domain, og::OutGrid, product::AbstractString)
    panels = Tuple{String,Matrix{Float32},ColorScale,Dict{Int,String}}[]
    nolabels = Dict{Int,String}()
    NCDataset(product_file(og, product)) do ds
        z_bed, z_srf, H_ice = (Float32.(coalesce.(ds[v][:, :], NaN)) for v in ("z_bed", "z_srf", "H_ice"))
        zmap, zrange, hrange = topo_colors(z_bed, H_ice)
        zscale = continuous_scale(Float32[]; colormap=Symbol(zmap), colorrange=zrange)
        push!(panels, ("z_bed (m)", z_bed, zscale, nolabels),
              ("z_srf (m)", map(x -> x > 0 ? x : NaN32, z_srf), zscale, nolabels),
              ("H_ice (m)", replace(H_ice, 0.0f0 => NaN32),
               continuous_scale(Float32[]; colormap=:ice, colorrange=hrange), nolabels))
    end
    if isfile(regions_file(og))
        NCDataset(regions_file(og)) do ds
            for v in ("region_1", "region_2", "region_3")
                data = Float32.(coalesce.(ds[v][:, :], NaN))
                push!(panels, (v, data, class_scale(data, Dict{Int,String}()), region_labels(ds, v)))
            end
            zone = Float32.(coalesce.(ds["zone"][:, :], NaN))
            push!(panels, ("zone", zone, class_scale(zone, flag_names(ds["zone"].attrib)), nolabels))
        end
    end
    for set in basin_sets(dom)
        isfile(basins_file(og, set)) || continue
        NCDataset(basins_file(og, set)) do ds
            basin = map(x -> x > 0 ? x : NaN32, Float32.(coalesce.(ds["basin"][:, :], NaN)))
            push!(panels, ("basins $(set.name)", basin, class_scale(basin, flag_names(ds["basin"].attrib)), nolabels))
        end
    end

    fig = Figure(; fontsize=12, figure_padding=10)
    Label(fig[0, 1:2OVERVIEW_COLUMNS], "$(dom.folder): Topo $product, regions, zones and basins on $(og.grid.name)";
          fontsize=16, font=:bold)
    width = round(Int, OVERVIEW_PANEL_HEIGHT * map_aspect(og.grid))
    for (k, (title, data, scale, labels)) in enumerate(panels)
        r, c = fldmod1(k, OVERVIEW_COLUMNS)
        ax = map_axis(fig[r, 2c-1], og; title=title)
        hm = field!(ax, og, data, scale)
        length(scale.classes) <= MAX_LEGEND_CLASSES && scale_bar(fig[r, 2c], hm, scale)
        x, y = map_coords(og.grid)
        for (code, label) in labels
            cells = findall(==(code), data)
            isempty(cells) && continue
            text!(ax, median(x[i[1]] for i in cells), median(y[i[2]] for i in cells); text=label, fontsize=9,
                  align=(:center, :center))
        end
    end
    for c in 1:min(OVERVIEW_COLUMNS, length(panels))
        colsize!(fig.layout, 2c - 1, Fixed(width))
    end
    foreach(r -> rowsize!(fig.layout, r, Fixed(OVERVIEW_PANEL_HEIGHT)), 1:cld(length(panels), OVERVIEW_COLUMNS))
    resize_to_layout!(fig)
    save_figure(path, fig)
    return path
end
