#
# Check plots of the products of a domain, written to $FESMDATA_WORK/topo/plots/:
#
#   <BASE>_TOPO-<product>.png         fields of the product on the base grid
#   <DOMAIN>_TOPO-<product>_grids.png ice thickness on every grid of the domain
#   <GRID>_TOPO-<product>_v1.png      difference with the v1 product, if any
#   <GRID>_TOPO-<product>_<ref>.png   difference of a variant with a default product
#
# and a table of ice area and volume on every grid (conservation check).
#
# Usage:
#     julia --project=Topo -t N Topo/scripts/05_plots.jl DOMAIN [PRODUCTS]
#
# PRODUCTS is "default" (the default products, if omitted), "variants", "all",
# or the name of one product (see domains.toml).
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

# Default product to compare a variant with: (domain, variant) => (grid, product)
const REF = Dict(
    ("ANT", "BedMachine-v3")     => ("ANT-4KM", "BedMachine-v4"),
    ("ANT", "BedMachine-v2")     => ("ANT-4KM", "BedMachine-v4"),
    ("ANT", "Bedmap2")           => ("ANT-4KM", "Bedmap3"),
    ("GRL-PAL", "BedMachine-v5") => ("GRL-4KM", "BedMachine-v6"),
    ("GRL-PAL", "BedMachine-v4") => ("GRL-4KM", "BedMachine-v6"),
)

const MAXPIX = 1200
const MASK_COLORS = [:steelblue, :tan, :white, :lightblue]

1 <= length(ARGS) <= 2 || error("usage: 05_plots.jl DOMAIN [PRODUCTS]")
dom = Domain(ARGS[1])
products = select_products(dom, get(ARGS, 2, "default"))
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

outgrid(name) = only(filter(o -> o.grid.name == name, dom.grids))

"""
Plot z_bed and H_ice of `product` on grid `gname`, of the reference fields `f1`, and
their difference, to <GRID>_TOPO-<product>_<suffix>.png.
"""
function compare(product, gname, f1, label, suffix)
    g2, f2 = read_fields(product_file(outgrid(gname), product))
    if size(f1["z_bed"]) != size(g2)
        println("$label on $gname has size $(size(f1["z_bed"])), $product has $(size(g2)): comparing common cells")
    end
    nx, ny = min.(size(f1["z_bed"]), size(g2))
    gc = ProjGrid(gname, g2.xc[1:nx], g2.yc[1:ny], g2.proj)
    fig = Figure(size=(1500, 950))
    for (r, name) in enumerate(("z_bed", "H_ice"))
        a, b = f2[name][1:nx, 1:ny], f1[name][1:nx, 1:ny]
        cmap, crange = name == "z_bed" ? (:oleron, (-4000, 4000)) : (:Blues, (0, 4000))
        panel!(fig[r, 1], gc, a, "$name $product"; colormap=cmap, colorrange=crange)
        panel!(fig[r, 2], gc, b, "$name $label"; colormap=cmap, colorrange=crange)
        panel!(fig[r, 3], gc, a .- b, "$name difference (m)"; colormap=:RdBu, colorrange=(-300, 300))
        d = filter(!isnan, a .- b)
        println(@sprintf("%s - %s %-6s on %s: mean %.1f m, rms %.1f m", product, label, name, gname,
                         sum(d) / length(d), sqrt(sum(d .^ 2) / length(d))))
    end
    save(joinpath(plotdir, "$(gname)_TOPO-$(product)_$(suffix).png"), fig)
end

for product in products
    # Base product
    g, f = read_fields(product_file(dom.grids[1], product))
    nsrc = length(dom.products[product])
    fig = Figure(size=(1500, 950))
    panel!(fig[1, 1], g, f["z_bed"], "z_bed (m)"; colormap=:oleron, colorrange=(-4000, 4000))
    panel!(fig[1, 2], g, f["z_srf"], "z_srf (m)"; colormap=:oleron, colorrange=(-4000, 4000))
    panel!(fig[1, 3], g, f["H_ice"], "H_ice (m)"; colormap=:Blues, colorrange=(0, 4000))
    panel!(fig[2, 1], g, f["z_bed_sd"], "z_bed_sd (m)"; colormap=:viridis, colorrange=(0, 300))
    panel!(fig[2, 2], g, f["mask"], "mask: ocean, land, grounded, floating"; colormap=MASK_COLORS, categorical=4)
    panel!(fig[2, 3], g, f["src_id"], "src_id: " * join(reverse(dom.products[product]), ", ");
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

    # Comparison with v1, and of a variant with its default product
    if haskey(V1, (dom.key, product))
        gname, v1file = V1[(dom.key, product)]
        v1path = joinpath(ENV["ICE_DATA"], v1file)
        if isfile(v1path)
            f1 = NCDataset(v1path) do ds
                Dict(k => Float32.(coalesce.(ds[k][:, :], NaN32)) for k in ("z_bed", "H_ice") if haskey(ds, k))
            end
            compare(product, gname, f1, "v1 $(basename(v1file))", "v1")
        else
            println("No v1 file $v1path")
        end
    end
    if haskey(REF, (dom.key, product))
        gname, ref = REF[(dom.key, product)]
        _, f1 = read_fields(product_file(outgrid(gname), ref))
        compare(product, gname, f1, ref, ref)
    end
end
println("Plots in $plotdir")
