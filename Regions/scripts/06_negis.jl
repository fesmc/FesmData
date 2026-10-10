#
# Checks of the NEGIS basin sets (basins.toml) on GRL-16KM, against the v1 parts: the
# cells and IoU of each part of NEGIS and of the rejected split by surface elevation,
# and a map. Needs step 4 for NEGIS and NEGIS-v1.
#
# Usage:
#     julia --project=Regions -t 8 Regions/scripts/06_negis.jl [V1_FILE]
#
# With V1_FILE (GRL-16KM_BASINS-nasa-negis-three.nc of the v1 ice_data), also checks that
# NEGIS-v1 on GRL-16KM equals its basin_sub 9.1, 9.2, 9.3. Writes
# $FESMDATA_WORK/regions/plots/GRL-16KM_negis.png.
#
include(joinpath(@__DIR__, "..", "common.jl"))
using CairoMakie

length(ARGS) <= 1 || error("usage: 06_negis.jl [V1_FILE]")
const Z_CUT = 1450.0      # m, surface elevation between centre and south (rejected split)

dom = Domain("GRL-PAL")
grid(name) = only(filter(o -> o.grid.name == name, dom.grids))
og16, og4 = grid("GRL-16KM"), grid("GRL-4KM")
sets = Dict(s.name => s for s in basin_sets(dom))
basin(og, name) = read_fields(basins_file(og, sets[name]))[2]["basin"]
V1, N16, N4 = basin(og16, "NEGIS-v1"), basin(og16, "NEGIS"), basin(og4, "NEGIS")
g16 = og16.grid

if length(ARGS) == 1
    ref = NCDataset(ARGS[1]) do ds
        @assert ds["xc"][:] ≈ g16.xc && ds["yc"][:] ≈ g16.yc
        bs = ds["basin_sub"][:, :]
        [something(findfirst(c -> !ismissing(v) && abs(v - c) < 1e-3, (9.1, 9.2, 9.3)), 0) for v in bs]
    end
    n = count(ref .!= V1)
    println("NEGIS-v1 on GRL-16KM vs $(basename(ARGS[1])): $n cells differ ($(count(ref .!= 0)) cells in parts)")
    n == 0 || error("NEGIS-v1 does not reproduce v1")
end

iou(a, b) = count(a .& b) / count(a .| b)
function scores(L, label)
    println(label)
    for (k, part) in enumerate(NEGIS_PARTS)
        a, b = L .== k, V1 .== k
        println("  $(rpad(part, 7)) $(lpad(count(a), 4)) cells (v1 $(lpad(count(b), 3))), IoU $(round(iou(a, b); digits=3))")
    end
    println("  all     $(lpad(count(L .!= 0), 4)) cells (v1 $(lpad(count(V1 .!= 0), 3))), IoU $(round(iou(L .!= 0, V1 .!= 0); digits=3))")
end
scores(N16, "NEGIS vs v1 on GRL-16KM")

# Rejected split: the same stream cut at the surface elevation Z_CUT, on the base grid
_, B = read_fields(regions_work_file(dom, "basins-NEGIS"))
topography = NCDataset(ds -> ds.attrib["topography"], regions_work_file(dom, "zone"))
zs = NCDataset(ds -> ds["z_srf"][:, :], product_file(dom.grids[1], topography))
Bz = copy(B["basin"])
stream = (Bz .== 1) .| (Bz .== 2)
Bz[stream] .= ifelse.(coalesce.(zs[stream], 0f0) .< Z_CUT, Int32(1), Int32(2))
Z16 = remap_dominant(AlignedMap(g16, dom.base), Bz)
scores(Z16, "Rejected: centre/south cut at z_srf = $(Z_CUT) m, vs v1 on GRL-16KM")

# Map: v1, NEGIS and the rejected split on GRL-16KM, NEGIS on GRL-4KM
xlim, ylim = (0.0, 720.0), (-1760.0, -900.0)
gw = crop(dom.base, xlim, ylim; name="window")
iw = findall(x -> xlim[1] - 1e-6 <= x <= xlim[2] + 1e-6, dom.base.xc)
jw = findall(y -> ylim[1] - 1e-6 <= y <= ylim[2] + 1e-6, dom.base.yc)
streamw = Float64.(stream[iw, jw])
uw = replace(read_speed(gw), NaN32 => 0f0)
colors = cgrad([:orange, :firebrick, :seagreen], 3; categorical=true)
fig = Figure(size=(1900, 620))
function panel!(k, og, L, title)
    g = og.grid
    ax = Axis(fig[1, k]; aspect=DataAspect(), title=title, titlesize=13, xlabel="x (km)", ylabel=k == 1 ? "y (km)" : "")
    heatmap!(ax, g.xc, g.yc, map(v -> v == 0 ? NaN : Float64(v), L); colormap=colors, colorrange=(1, 3))
    contour!(ax, gw.xc, gw.yc, uw; levels=[50], color=:royalblue, linewidth=1, linestyle=:dash)
    contour!(ax, gw.xc, gw.yc, streamw; levels=[0.5], color=:black, linewidth=1)
    k > 1 && contour!(ax, g16.xc, g16.yc, Float64.(V1 .!= 0); levels=[0.5], color=:grey40, linewidth=1.5)
    limits!(ax, xlim..., ylim...)
end
lab(L) = join(["$(round(iou(L .== k, V1 .== k); digits=2))" for k in 1:3], ", ")
panel!(1, og16, V1, "v1 (NEGIS-v1), GRL-16KM: $(join([count(V1 .== k) for k in 1:3], ", ")) cells")
panel!(2, og16, N16, "NEGIS, GRL-16KM: IoU vs v1 $(lab(N16))")
panel!(3, og16, Z16, "rejected: cut at z_srf = $(round(Int, Z_CUT)) m: IoU $(lab(Z16))")
panel!(4, og4, N4, "NEGIS, GRL-4KM")
Legend(fig[2, 1:4], vcat([PolyElement(color=c) for c in (:orange, :firebrick, :seagreen)],
                         [LineElement(color=:black), LineElement(color=:royalblue, linestyle=:dash), LineElement(color=:grey40, linewidth=1.5)]),
       ["centre", "south", "north", "stream (500 m)", "u = 50 m/yr (500 m)", "v1 outline"];
       orientation=:horizontal, framevisible=false)
path = joinpath(mkpath(joinpath(regions_workdir(), "plots")), "GRL-16KM_negis.png")
save(path, fig; px_per_unit=1.5)
@info "wrote $path"
