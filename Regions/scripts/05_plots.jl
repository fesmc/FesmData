#
# Check plots of the regions, zones and basins of a domain, on its first grid with a
# resolution of at least 8 km (default) or on GRID. Needs step 4.
#
# Usage:
#     julia --project=Regions -t 8 Regions/scripts/05_plots.jl DOMAIN [GRID]
#
# Writes $FESMDATA_WORK/regions/plots/<GRID>_regions.png and <GRID>_basins-<SET>.png.
#
include(joinpath(@__DIR__, "..", "common.jl"))
using CairoMakie
using Random

1 <= length(ARGS) <= 2 || error("usage: 05_plots.jl DOMAIN [GRID]")
dom = Domain(ARGS[1])
og = length(ARGS) == 2 ? only(filter(o -> o.grid.name == ARGS[2], dom.grids)) :
     first(filter(o -> spacing(o.grid)[1] >= 8, dom.grids))
g = og.grid
plotdir = mkpath(joinpath(regions_workdir(), "plots"))

# Categorical map with class boundaries and labels
function classmap!(ax, g, L, labels; seed=1)
    rng = MersenneTwister(seed)
    cols = Dict(c => RGBf(0.25 + 0.75rand(rng), 0.25 + 0.75rand(rng), 0.25 + 0.75rand(rng)) for c in unique(L))
    haskey(cols, 0) && (cols[0] = RGBf(1, 1, 1))
    image!(ax, (g.xc[1], g.xc[end]), (g.yc[1], g.yc[end]), [cols[c] for c in L])
    E = [(i < size(L, 1) && L[i, j] != L[i+1, j]) || (j < size(L, 2) && L[i, j] != L[i, j+1])
         for i in axes(L, 1), j in axes(L, 2)]
    heatmap!(ax, g.xc, g.yc, map(e -> e ? 1.0 : NaN, E); colormap=[:black, :black])
    for c in unique(L)
        (c == 0 || !haskey(labels, c)) && continue
        idx = findall(==(c), L)
        length(idx) < 30 && continue
        text!(ax, sum(g.xc[I[1]] for I in idx) / length(idx), sum(g.yc[I[2]] for I in idx) / length(idx);
              text=labels[c], fontsize=11, align=(:center, :center))
    end
    hidedecorations!(ax)
end

path = regions_file(og)
_, F = read_fields(path)
fig = Figure(size=(2400, 900))
for (k, var) in enumerate(("region_2", "region_3"))
    flags = read_flags(path, var)
    labels = Dict(c => region_path(c) * " " * replace(n, "_" => " ") for (c, n) in flags)
    classmap!(Axis(fig[1, k]; aspect=DataAspect(), title="$(g.name) $var"), g, F[var], labels)
end
ax = Axis(fig[1, 3]; aspect=DataAspect(), title="$(g.name) zone (open ocean, buffer, shelf, land)")
heatmap!(ax, g.xc, g.yc, F["zone"]; colormap=cgrad([:navy, :royalblue, :lightskyblue, :tan], 4, categorical=true))
hidedecorations!(ax)
save(joinpath(plotdir, "$(g.name)_regions.png"), fig)

for set in basin_sets(dom)
    bpath = basins_file(og, set)
    _, B = read_fields(bpath)
    vars = filter(v -> haskey(B, v), ["basin", "basin_group"])
    fig = Figure(size=(1100 * length(vars), 1000))
    for (k, var) in enumerate(vars)
        flags = read_flags(bpath, var)
        ax = Axis(fig[1, k]; aspect=DataAspect(), title="$(g.name) $(set.name) $var (black line: original extent)")
        classmap!(ax, g, B[var], Dict(c => replace(n, "_" => " ") for (c, n) in flags))
        contour!(ax, g.xc, g.yc, Float64.(B["basin_mask"]); levels=[0.5], color=:black, linewidth=1.5)
        ix = findall(vec(any(B[var] .!= 0; dims=2)))
        iy = findall(vec(any(B[var] .!= 0; dims=1)))
        isempty(ix) || limits!(ax, g.xc[ix[1]], g.xc[ix[end]], g.yc[iy[1]], g.yc[iy[end]])
    end
    save(joinpath(plotdir, "$(g.name)_basins-$(set.name).png"), fig)
end
@info "plots in $plotdir"
