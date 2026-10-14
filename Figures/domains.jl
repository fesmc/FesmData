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
`topo_colors`), the three levels of the regions labelled by path and name, with the
outlines of the nests and crops of the domain family (DOMAINS of Regions), the zones,
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
    # Nests and crops (key => mask) outlined on the maps of the regions
    outlines = Pair{String,Matrix{Float32}}[]
    if isfile(domains_file(og))
        NCDataset(domains_file(og)) do ds
            for v in sort(filter(startswith("domain_"), keys(ds)))
                mask = Float32.(coalesce.(ds[v][:, :], 0))
                0 < sum(mask) < length(mask) && push!(outlines, chopprefix(v, "domain_") => mask)
            end
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
        startswith(title, "region_") && outline!(ax, og, outlines, width)
    end
    for c in 1:min(OVERVIEW_COLUMNS, length(panels))
        colsize!(fig.layout, 2c - 1, Fixed(width))
    end
    foreach(r -> rowsize!(fig.layout, r, Fixed(OVERVIEW_PANEL_HEIGHT)), 1:cld(length(panels), OVERVIEW_COLUMNS))
    resize_to_layout!(fig)
    save_figure(path, fig)
    return path
end

"Font size of the keys of the nests and crops on the maps of an overview figure."
const OUTLINE_FONTSIZE = 9

"""
    outline!(ax, og, outlines, width)

Outline each nest or crop (key => its mask on grid `og`, 1 inside) on map `ax`, of
`width` units of the layout: the contour of its mask, with its key at its centre, or,
if the key would not fit inside it or would cross the outline of another one or another
key, at the nearest edge of the map, with a line to its centre.
"""
function outline!(ax, og::OutGrid, outlines, width)
    x, y = map_coords(og.grid)
    xlim, ylim = extrema(x), extrema(y)
    unit = (xlim[2] - xlim[1]) / width              # map units per unit of the layout
    boxes = map(outlines) do (_, mask)
        cells = findall(==(1), mask)
        (extrema(x[i[1]] for i in cells)..., extrema(y[i[2]] for i in cells)...)
    end
    centre(b) = ((b[1] + b[2]) / 2, (b[3] + b[4]) / 2)
    # Box of a key at the centre of an outline (map units)
    keybox(k) = let (cx, cy) = centre(boxes[k]), w = _key_width(outlines[k][1]) * unit / 2,
                    h = 0.6 * OUTLINE_FONTSIZE * unit
        (cx - w, cx + w, cy - h, cy + h)
    end
    overlaps(a, b) = a[1] <= b[2] && b[1] <= a[2] && a[3] <= b[4] && b[3] <= a[4]
    inside(a, b) = b[1] <= a[1] && a[2] <= b[2] && b[3] <= a[3] && a[4] <= b[4]
    crosses(kb, j) = overlaps(kb, boxes[j]) && !inside(kb, boxes[j])
    clashes(k) = !inside(keybox(k), boxes[k]) || any(j -> j != k && (crosses(keybox(k), j) || overlaps(keybox(k), keybox(j))), eachindex(boxes))
    at_edge = Dict(e => Tuple{Float64,String,NTuple{2,Float64}}[] for e in (:left, :right, :bottom, :top))
    for (k, (key, mask)) in enumerate(outlines)
        contour!(ax, x, y, mask; levels=[0.5], color=:black, linewidth=1.2)
        c = centre(boxes[k])
        if !clashes(k)
            _outline_key!(ax, c, key, (:center, :center))
            continue
        end
        d = (left=c[1] - xlim[1], right=xlim[2] - c[1], bottom=c[2] - ylim[1], top=ylim[2] - c[2])
        e = argmin(d)
        push!(at_edge[e], (e in (:left, :right) ? c[2] : c[1], key, c))
    end
    # Keys along each edge, at least two lines of text apart
    gap = 2.5 * OUTLINE_FONTSIZE * unit
    inset = 0.5 * OUTLINE_FONTSIZE * unit
    for (e, keys) in at_edge
        isempty(keys) && continue
        sort!(keys)
        pos = first.(keys)
        for k in 2:length(pos)
            pos[k] = max(pos[k], pos[k-1] + gap)
        end
        lo, hi = e in (:left, :right) ? ylim : xlim
        pos .-= max(0, pos[end] - (hi - 2gap))      # within the edge
        pos .+= max(0, lo + 2gap - pos[1])
        for ((_, key, c), p) in zip(keys, pos)
            w = _key_width(key) * unit
            h = OUTLINE_FONTSIZE * unit
            anchor, align, start = e == :left ? ((xlim[1] + inset, p), (:left, :center), (xlim[1] + inset + w, p)) :
                                   e == :right ? ((xlim[2] - inset, p), (:right, :center), (xlim[2] - inset - w, p)) :
                                   e == :bottom ? ((p, ylim[1] + inset), (:center, :bottom), (p, ylim[1] + inset + h)) :
                                                  ((p, ylim[2] - inset), (:center, :top), (p, ylim[2] - inset - h))
            lines!(ax, [start[1], c[1]], [start[2], c[2]]; color=:black, linewidth=0.8)
            _outline_key!(ax, anchor, key, align)
        end
    end
    return ax
end

"Width of a key on a map (units of the layout)."
_key_width(key) = (0.6 * length(key) + 0.5) * OUTLINE_FONTSIZE

_outline_key!(ax, pos, key, align) =
    text!(ax, pos...; text=key, fontsize=OUTLINE_FONTSIZE, font=:bold, align=align,
          glowwidth=2, glowcolor=(:white, 0.8))
