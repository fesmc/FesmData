#
# Check plots of the products of a domain, written to $FESMDATA_WORK/topo/plots/:
#
#   <BASE>_TOPO-<product>.png         fields of the product on the base grid
#   <DOMAIN>_TOPO-<product>_grids.png ice thickness on every grid of the domain
#   <GRID>_TOPO-<product>_v1.png      difference with the v1 product, if any
#
# and a table of ice area and volume on every grid (conservation check).
#
# Usage:
#     julia --project=Topo -t N Topo/scripts/05_plots.jl DOMAIN [PRODUCT]
#
include(joinpath(@__DIR__, "..", "common.jl"))
include(joinpath(TOPO_DIR, "sources.jl"))
using CairoMakie
using Printf

# v1 product to compare with: (domain, product) => (grid, file under $ICE_DATA)
const V1 = Dict(
    ("ANT", "BedMachine-v4")     => ("ANT-16KM", "Antarctica/ANT-16KM/ANT-16KM_TOPO-BedMachine.nc"),
    ("ANT", "Bedmap3")           => ("ANT-16KM", "Antarctica/ANT-16KM/ANT-16KM_TOPO-Bedmap3.nc"),
    ("GRL-PAL", "BedMachine-v6") => ("GRL-16KM", "Greenland/GRL-16KM/GRL-16KM_TOPO-M17-v5.nc"),
    ("NH", "GEBCO2025")          => ("NH-32KM", "North/NH-32KM/NH-32KM_TOPO-RTOPO-2.0.1.nc"),
)

const MAXPIX = 1200
const MASK_COLORS = [:steelblue, :tan, :white, :lightblue]

1 <= length(ARGS) <= 2 || error("usage: 05_plots.jl DOMAIN [PRODUCT]")
dom = Domain(ARGS[1])
sources_of = product_sources(dom)
products = length(ARGS) == 2 ? [ARGS[2]] : sort(collect(keys(sources_of)))
plotdir = mkpath(joinpath(workdir(), "plots"))

# Subsample a field to at most MAXPIX cells per axis
function thin(g::ProjGrid, F)
    s = max(1, cld(maximum(size(g)), MAXPIX))
    return g.xc[1:s:end], g.yc[1:s:end], Float32.(F[1:s:end, 1:s:end])
end

function panel!(pos, g, F, title; colormap=:viridis, colorrange=nothing, categorical=0)
    ax = Axis(pos; title=title, aspect=DataAspect())
    hidedecorations!(ax)
    x, y, Z = thin(g, F)
    if categorical > 0
        hm = heatmap!(ax, x, y, Z; colormap=cgrad(colormap, categorical; categorical=true),
                      colorrange=(-0.5, categorical - 0.5))
    else
        hm = heatmap!(ax, x, y, Z; colormap=colormap, colorrange=something(colorrange, extrema(filter(!isnan, Z))))
    end
    Colorbar(pos[1, 2], hm; height=Relative(0.8))
    return ax
end

for product in products
    # Base product
    g, f = read_fields(product_file(dom.grids[1], product))
    nsrc = length(sources_of[product])
    fig = Figure(size=(1500, 950))
    panel!(fig[1, 1], g, f["z_bed"], "z_bed (m)"; colormap=:oleron, colorrange=(-4000, 4000))
    panel!(fig[1, 2], g, f["z_srf"], "z_srf (m)"; colormap=:oleron, colorrange=(-4000, 4000))
    panel!(fig[1, 3], g, f["H_ice"], "H_ice (m)"; colormap=:Blues, colorrange=(0, 4000))
    panel!(fig[2, 1], g, f["z_bed_sd"], "z_bed_sd (m)"; colormap=:viridis, colorrange=(0, 300))
    panel!(fig[2, 2], g, f["mask"], "mask: ocean, land, grounded, floating"; colormap=MASK_COLORS, categorical=4)
    panel!(fig[2, 3], g, f["src_id"], "src_id: " * join(reverse(sources_of[product]), ", ");
           colormap=nsrc > 1 ? :Set2_8 : [:gray], categorical=nsrc)
    Label(fig[0, :], "$(g.name)_TOPO-$(product)"; fontsize=20)
    save(joinpath(plotdir, "$(g.name)_TOPO-$(product).png"), fig)

    # All grids: ice thickness, and conservation table
    grids = dom.grids
    ncol = min(4, length(grids))
    fig = Figure(size=(380 * ncol, 360 * cld(length(grids), ncol)))
    println(@sprintf("%-16s %12s %12s %14s", "grid", "grnd km2", "flt km2", "volume km3"))
    for (k, og) in enumerate(grids)
        gk, fk = read_fields(product_file(og, product))
        lon, lat = lonlat(gk)
        area = cell_area(gk, lon, lat) ./ 1e6         # km2
        println(@sprintf("%-16s %12.0f %12.0f %14.0f", gk.name,
                         sum(fk["f_grnd"] .* area), sum(fk["f_flt"] .* area), sum(fk["H_ice"] .* area) / 1000))
        panel!(fig[cld(k, ncol), mod1(k, ncol)], gk, fk["H_ice"], gk.name; colormap=:Blues, colorrange=(0, 4000))
    end
    save(joinpath(plotdir, "$(dom.key)_TOPO-$(product)_grids.png"), fig)

    # Comparison with v1
    haskey(V1, (dom.key, product)) || continue
    gname, v1file = V1[(dom.key, product)]
    v1path = joinpath(ENV["ICE_DATA"], v1file)
    isfile(v1path) || (println("No v1 file $v1path"); continue)
    og = only(filter(o -> o.grid.name == gname, grids))
    g2, f2 = read_fields(product_file(og, product))
    f1 = NCDataset(v1path) do ds
        Dict(k => Float32.(coalesce.(ds[k][:, :], NaN32)) for k in ("z_bed", "H_ice", "z_srf") if haskey(ds, k))
    end
    if size(f1["z_bed"]) != size(g2)
        println("v1 $gname has size $(size(f1["z_bed"])), v2 has $(size(g2)): comparing common cells")
    end
    nx, ny = min.(size(f1["z_bed"]), size(g2))
    fig = Figure(size=(1500, 950))
    for (r, name) in enumerate(("z_bed", "H_ice"))
        a, b = f2[name][1:nx, 1:ny], f1[name][1:nx, 1:ny]
        gc = ProjGrid(gname, g2.xc[1:nx], g2.yc[1:ny], g2.proj)
        cmap, crange = name == "z_bed" ? (:oleron, (-4000, 4000)) : (:Blues, (0, 4000))
        panel!(fig[r, 1], gc, a, "$name v2 $product"; colormap=cmap, colorrange=crange)
        panel!(fig[r, 2], gc, b, "$name v1 $(basename(v1file))"; colormap=cmap, colorrange=crange)
        panel!(fig[r, 3], gc, a .- b, "$name v2 - v1 (m)"; colormap=:RdBu, colorrange=(-300, 300))
        d = filter(!isnan, a .- b)
        println(@sprintf("v2 - v1 %-6s on %s: mean %.1f m, rms %.1f m", name, gname, sum(d) / length(d), sqrt(sum(d .^ 2) / length(d))))
    end
    save(joinpath(plotdir, "$(gname)_TOPO-$(product)_v1.png"), fig)
end
println("Plots in $plotdir")
