# Prepare GLAC-1D extended back to 80 ka for remapping: the regional reconstructions of
# North America + Greenland (nn9894 or nn9927) and Antarctica (nn4041) of GLAC-1D, and
# elsewhere the global GLAC-1D of PMIP4 from 26 ka (its oldest step) and PaleoMIST 1.0
# (Gowan et al., 2021) before, on the 0.5° x 0.25° grid of the PMIP4 ice thickness, at the
# time steps of the regional reconstructions from 80 ka, where PaleoMIST starts. One
# prepared file per North American variant, in $FESMDATA_PREPARED/Tarasov2012_glac1d_80k/:
# Tarasov2012_GLAC1D_80k.nc (nn9894, as in PMIP4) and Tarasov2012_GLAC1D_nn9927_80k.nc,
# with H_ice and f_ice on (lon, lat, time).
#
# In each cell, with w the fraction of the cell covered by the regional grids:
#     H_ice = w * H_regional + (1 - w) * H_rest
#     f_ice = w * f_regional + (1 - w) * f_rest
# f_regional is the fraction with ice (H_ice > 0) of the regional grids; H_rest and f_rest
# are H_ice (HGLOBH) and f_ice (ICEM) of PMIP4 at and after 26 ka, and H_ice and f_ice of
# PaleoMIST (minimal MIS 3 scenario) before, linearly interpolated in time.
#
# Made from the prepared files of Tarasov2012_glac1d and Gowan2021_PaleoMIST1.0, which are
# prepared first if they are missing.
#
# Usage:
#     julia -t 8 --project=Tarasov2012_glac1d_80k Tarasov2012_glac1d_80k/prepare.jl
#     julia fesmdata.jl remap IceHistory GLAC1D_80k GLAC1D_nn9927_80k

using FesmUtils
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))

const SOURCE = "Tarasov2012_glac1d_80k"
const GLAC1D = "Tarasov2012_glac1d"
const PALEOMIST = ("Gowan2021_PaleoMIST1.0", "Gowan2021_PaleoMIST.nc")
const ANT = "Tarasov2012_GLAC1D_ANT_nn4041.nc"
const PMIP4_ICE = "Tarasov2012_GLAC1D_PMIP4_ice.nc"      # H_ice, 0.5° x 0.25°: the grid of the products
const PMIP4_TOPO = "Tarasov2012_GLAC1D_PMIP4_topo.nc"    # f_ice, 1° x 0.5°
const T_START = 80_000.0                                 # oldest step of PaleoMIST

# Products: prepared file, regional file of North America + Greenland, its variant
const VARIANTS = [("Tarasov2012_GLAC1D_80k.nc", "Tarasov2012_GLAC1D_NA_nn9894.nc", "nn9894"),
                  ("Tarasov2012_GLAC1D_nn9927_80k.nc", "Tarasov2012_GLAC1D_NA_nn9927.nc", "nn9927")]

# Ice volume as sea-level equivalent, as Gowan2021_PaleoMIST_esl: ice and water densities
# 910 and 1000 kg m-3, present ocean area 361e6 km2, sphere of radius 6371 km
const R_EARTH = 6.371e6
const SLE_PER_M3 = 910 / 1000 / 361e12

"Prepared file of a source, prepared first if it is missing."
function prepared(source, file)
    path = joinpath(prepared_dir(source), file)
    isfile(path) || run_prepare(source)
    return path
end

lonlat_grid(ds) = LonLatGrid(ds["lon"].var[:], ds["lat"].var[:])
read_ages(ds) = Float64.(ds["time"].var[:])

"Index of age `t` in `ages` (an error if it is not there)."
function age_index(ages, t, what)
    n = findfirst(==(t), ages)
    n === nothing && error("$what: no step at $t years ago")
    return n
end

"Cell areas (m2) of a lon-lat grid."
cell_area(g::LonLatGrid) =
    [R_EARTH^2 * deg2rad(g.dlon) * (sind(g.latedges[j+1]) - sind(g.latedges[j])) for _ in g.lon, j in eachindex(g.lat)]

"Ice volume (m sea-level equivalent) of the thickness `H` (m) on cells of area `A`."
sle(H, A) = SLE_PER_M3 * sum(Float64(H[i]) * A[i] for i in eachindex(H, A))

"""
    regional(g, files, ages) -> (w, wH, wf)

The regional reconstructions (prepared files `files` of GLAC-1D, on grids that do not
overlap) on the grid `g` at `ages`: the fraction `w` of each cell covered by their grids,
and `w` times their ice thickness (`wH`) and their fraction with ice, `H_ice > 0` (`wf`),
remapped conservatively (exact).
"""
function regional(g, files, ages)
    w = zeros(Float32, size(g))
    wH = zeros(Float32, size(g)..., length(ages))
    wf = zeros(Float32, size(g)..., length(ages))
    for file in files
        NCDataset(prepared(GLAC1D, file)) do ds
            m = AlignedMap(g, lonlat_grid(ds))
            _, wr = remap(m, ones(Float32, size(m.src)))
            w .+= wr
            t = read_ages(ds)
            for (k, a) in enumerate(ages)
                H = ds["H_ice"].var[:, :, age_index(t, a, file)]
                Hm, _ = remap(m, H)
                fm, _ = remap(m, Float32.(H .> 0))
                @views wH[:, :, k] .+= ifelse.(wr .> 0, wr .* Hm, 0f0)
                @views wf[:, :, k] .+= ifelse.(wr .> 0, wr .* fm, 0f0)
            end
        end
    end
    maximum(w) <= 1 + 1f-5 || error("the regional grids overlap")
    return min.(w, 1f0), wH, wf
end

"""
    rest(g, ages) -> (H, f, t_splice, H_paleomist_splice)

The ice thickness `H` and fraction `f` of the global sources on the grid `g` (that of the
PMIP4 ice thickness) at `ages`: at and after `t_splice`, the oldest step of the PMIP4
GLAC-1D, its `H_ice` (HGLOBH) and its `f_ice` (ICEM, 1° x 0.5°, remapped conservatively);
before, `H_ice` and `f_ice` of PaleoMIST (0.25°, remapped conservatively), interpolated
linearly in time between its steps. `H_paleomist_splice` is PaleoMIST at `t_splice`,
for the size of the step there.
"""
function rest(g, ages)
    H = zeros(Float32, size(g)..., length(ages))
    f = zeros(Float32, size(g)..., length(ages))
    t_splice = NCDataset(prepared(GLAC1D, PMIP4_ICE)) do ds
        t = read_ages(ds)
        for (k, a) in enumerate(ages)
            a <= maximum(t) && (H[:, :, k] = ds["H_ice"].var[:, :, age_index(t, a, PMIP4_ICE)])
        end
        maximum(t)
    end
    NCDataset(prepared(GLAC1D, PMIP4_TOPO)) do ds
        m = AlignedMap(g, lonlat_grid(ds))
        t = read_ages(ds)
        maximum(t) == t_splice || error("$PMIP4_TOPO and $PMIP4_ICE start at different times")
        for (k, a) in enumerate(ages)
            a <= t_splice && (f[:, :, k] = remap(m, ds["f_ice"].var[:, :, age_index(t, a, PMIP4_TOPO)])[1])
        end
    end
    H_splice = NCDataset(prepared(PALEOMIST...)) do ds
        m = AlignedMap(g, lonlat_grid(ds))
        t = read_ages(ds)                                      # oldest first
        slices = Dict{Int,NTuple{2,Matrix{Float32}}}()
        slice(n) = get!(() -> (remap(m, ds["H_ice"].var[:, :, n])[1], remap(m, ds["f_ice"].var[:, :, n])[1]),
                        slices, n)
        function at(a)
            n = findlast(>=(a), t)
            n === nothing && error("PaleoMIST: no step at or before $a years ago")
            t[n] == a && return slice(n)
            c = Float32((a - t[n+1]) / (t[n] - t[n+1]))        # weight of the older step
            (H0, f0), (H1, f1) = slice(n), slice(n + 1)
            return (c .* H0 .+ (1 - c) .* H1, c .* f0 .+ (1 - c) .* f1)
        end
        for (k, a) in enumerate(ages)
            a > t_splice || continue
            H[:, :, k], f[:, :, k] = at(a)
        end
        at(t_splice)[1]
    end
    return H, f, t_splice, H_splice
end

"Write a prepared file of H_ice and f_ice on the grid `g` at `ages`."
function write_prepared(file, g, ages, H, f; variant, regional_file, t_splice)
    path = joinpath(prepared_dir(SOURCE), file)
    mkpath(dirname(path))
    rm(path; force=true)
    ts = round(Int, t_splice)
    NCDataset(path, "c") do ds
        defVar(ds, "lon", g.lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
        defVar(ds, "lat", g.lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
        defVar(ds, "time", ages, ("time",); attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)"])
        defVar(ds, "H_ice", H, ("lon", "lat", "time"); deflatelevel=1, shuffle=true,
               attrib=["units" => "m", "long_name" => "ice thickness",
                       "comment" => "w * H_regional + (1 - w) * H_rest, with w the coverage of the regional " *
                                    "GLAC-1D grids (North America + Greenland $variant, Antarctica nn4041; " *
                                    "grounded and floating ice) and H_rest the PMIP4 GLAC-1D (HGLOBH) at and " *
                                    "after $ts years ago, PaleoMIST 1.0 (grounded ice, linearly interpolated " *
                                    "in time) before"])
        defVar(ds, "f_ice", f, ("lon", "lat", "time"); deflatelevel=1, shuffle=true,
               attrib=["units" => "1", "long_name" => "ice area fraction",
                       "comment" => "w * f_regional + (1 - w) * f_rest, with f_regional the fraction with ice " *
                                    "(H_ice > 0) of the regional GLAC-1D grids and f_rest the PMIP4 GLAC-1D " *
                                    "ice mask (ICEM) at and after $ts years ago, the PaleoMIST 1.0 f_ice " *
                                    "(linearly interpolated in time) before"])
        ds.attrib["title"] = "GLAC-1D ice thickness, 80-0 ka: North America + Greenland ($variant) and " *
                             "Antarctica (nn4041) of GLAC-1D, elsewhere the PMIP4 GLAC-1D from $(ts ÷ 1000) ka " *
                             "and PaleoMIST 1.0 before"
        ds.attrib["references"] = "Tarasov, L., Dyke, A. S., Neal, R. M. and Peltier, W. R.: Earth Planet. Sci. Lett., " *
                                  "315-316, 30-40, 2012, doi:10.1016/j.epsl.2011.09.010; Tarasov, L. and Peltier, W. " *
                                  "R.: Geophys. J. Int., 150, 198-229, 2002, doi:10.1046/j.1365-246X.2002.01702.x; " *
                                  "Briggs, R. D., Pollard, D. and Tarasov, L.: Quat. Sci. Rev., 103, 91-115, 2014, " *
                                  "doi:10.1016/j.quascirev.2014.09.003; Tarasov, L. et al.: The global GLAC-1c " *
                                  "deglaciation chronology, IGS Symposium, 2014; Abe-Ouchi, A. et al.: Nature, 500, " *
                                  "190-193, 2013, doi:10.1038/nature12374; Gowan, E. J. et al.: Nat. Commun., 12, " *
                                  "1199, 2021, doi:10.1038/s41467-021-21469-w (data: doi:10.1594/PANGAEA.905800)"
        ds.attrib["doi"] = "10.1016/j.epsl.2011.09.010"
        ds.attrib["license"] = "GLAC-1D: no licence stated by the providers, users are asked to cite the " *
                               "references; PaleoMIST 1.0: CC BY 4.0 (PANGAEA)"
        ds.attrib["comment"] = "Regional: $regional_file and " *
                               "$ANT of $GLAC1D (1° x 0.5°), remapped conservatively (exact), with their " *
                               "coverage w; rest: $PMIP4_ICE (the grid of this file) and f_ice of $PMIP4_TOPO " *
                               "(remapped) at and after $ts years ago, $(PALEOMIST[2]) (0.25°, remapped) before, " *
                               "interpolated linearly in time; the rest changes source at $ts years ago " *
                               "(not smoothed)"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
    end
    println("Wrote $path")
end

g = NCDataset(lonlat_grid, prepared(GLAC1D, PMIP4_ICE))
ages = NCDataset(ds -> filter(<=(T_START), read_ages(ds)), prepared(GLAC1D, VARIANTS[1][2]))
A = cell_area(g)
println("Grid $(join(size(g), " x ")), $(length(ages)) steps from $(ages[1]) to $(ages[end]) years ago")

Hr, fr, t_splice, Hpm = rest(g, ages)
ks = age_index(ages, t_splice, "regional")
for (file, nafile, variant) in VARIANTS
    w, H, f = regional(g, [nafile, ANT], ages)
    rest_volume(Hs) = sle((1 .- w) .* Hs, A)
    println("$variant: volume outside the regional grids at $(round(Int, t_splice)) years ago, " *
            "PMIP4 GLAC-1D $(round(rest_volume(Hr[:, :, ks]); digits=2)) m SLE, " *
            "PaleoMIST $(round(rest_volume(Hpm); digits=2)) m SLE")
    H .+= (1 .- w) .* Hr
    f .+= (1 .- w) .* fr
    println("$variant: ice volume (m SLE) ",
            join(["$(round(Int, a / 1000)) ka $(round(sle(H[:, :, age_index(ages, a, "")], A); digits=2))"
                  for a in (80_000.0, 26_000.0, 21_000.0, 0.0)], ", "))
    write_prepared(file, g, ages, H, f; variant, regional_file=nafile, t_splice)
end
