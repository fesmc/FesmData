# Prepare the surface elevation change rate of the ice sheets from ICESat-2 ATL15 v6
# (quarterly height changes at 1 km, cycles 03-31, 2019 to April 2026; datamanifest key
# atl15_v006) for remapping: the linear trend of the height change `delta_h` over the
# whole record in each cell, as `dzdt` (m yr-1), on the 1 km grids of the product, to
# $FESMDATA_WORK/prepared/ATL15_dzdt/:
#
#   ATL15_ANT.nc   Antarctica, the four quadrants A1-A4 merged (EPSG:3031)
#   ATL15_GRL.nc   Greenland and its peripheral ice caps, GL (EPSG:3413)
#
# The trend is the unweighted least-squares fit of delta_h against time over the valid
# quarters of a cell (delta_h given and ice in the cell, ice_area > 0), and is missing
# where fewer than 75% of the quarters of the record are valid.
#
# Usage (about 2 GB of memory per quadrant; reads 13 GB):
#     julia --project=ATL15_dzdt ATL15_dzdt/prepare.jl
#     julia -t 8 fesmdata.jl remap IceChange ATL15-ANT ATL15-GRL

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "atl15_v006"
const MIN_VALID = 0.75                  # minimum fraction of valid quarters
const EPOCH = DateTime(2018, 1, 1)      # time of ATL15: days since 2018-01-01

# Region => (name, quadrant files, EPSG code, PROJ string, standard parallel, central meridian)
const REGIONS = [
    "ANT" => ("Antarctica", ["ATL15_A$(i)_0331_3mo_1km_006_02.nc" for i in 1:4], "EPSG:3031",
              "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs", -71, 0),
    "GRL" => ("Greenland", ["ATL15_GL_0331_3mo_1km_006_01.nc"], "EPSG:3413",
              "+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs", 70, -45),
]

"Values of a variable as Float64 with NaN for missing and invalid (fill) values."
clean(A) = map(a -> ismissing(a) || !isfinite(a) || abs(a) > 1e30 ? NaN : Float64(a), A)

"Check the grid mapping of delta_h against the expected projection, where the file gives it."
function check_projection(g, file, lat_ts, lon_0)
    haskey(g["delta_h"].attrib, "grid_mapping") || return
    gm = g[g["delta_h"].attrib["grid_mapping"]].attrib
    for (k, v) in (("standard_parallel", lat_ts), ("straight_vertical_longitude_from_pole", lon_0))
        haskey(gm, k) && !isapprox(Float64(first(gm[k])), v) &&
            error("$file: $k = $(gm[k]), expected $v")
    end
end

"""
    tile_trend(path, lat_ts, lon_0) -> (x, y, time, dzdt, nvalid)

Linear trend (m yr-1) of delta_h in each cell of an ATL15 file over its valid quarters,
NaN where fewer than MIN_VALID of them are valid, with the cell centres (m, ascending),
the times of the quarters and the number of valid quarters of each cell.
"""
function tile_trend(path, lat_ts, lon_0)
    NCDataset(path) do ds
        g = ds.group["delta_h"]
        check_projection(g, basename(path), lat_ts, lon_0)
        # Raw values: days since 2018-01-01 (not decoded to dates), coordinates in m
        x, y = Float64.(g["x"].var[:]), Float64.(g["y"].var[:])
        days = Float64.(g["time"].var[:])
        all(isfinite, days) && issorted(days) || error("$path: invalid times")
        dh, ia = g["delta_h"], g["ice_area"]
        dn = dimnames(dh)
        Set(dn) == Set(("x", "y", "time")) || error("$path: delta_h on $dn, expected x, y, time")
        dimnames(ia) == dn || error("$path: ice_area not on the dimensions of delta_h")
        # Time in years, centred for the accuracy of the sums
        t = days ./ 365.25
        t .-= sum(t) / length(t)
        nx, ny, nt = length(x), length(y), length(t)
        n = zeros(Int32, nx, ny)
        St, Stt, Sh, Sth = (zeros(nx, ny) for _ in 1:4)
        idx(k) = Tuple(d == "time" ? k : Colon() for d in dn)
        xyorder = filter(!=("time"), collect(dn)) == ["x", "y"]
        for k in 1:nt
            H = clean(dh[idx(k)...])
            A = clean(ia[idx(k)...])
            xyorder || (H = permutedims(H); A = permutedims(A))
            @inbounds for j in 1:ny, i in 1:nx
                h = H[i, j]
                (isfinite(h) && A[i, j] > 0) || continue
                n[i, j] += 1
                St[i, j] += t[k]
                Stt[i, j] += t[k]^2
                Sh[i, j] += h
                Sth[i, j] += t[k] * h
            end
        end
        nmin = ceil(Int, MIN_VALID * nt)
        dzdt = fill(NaN32, nx, ny)
        @inbounds for j in 1:ny, i in 1:nx
            n[i, j] >= nmin || continue
            dzdt[i, j] = Float32((n[i, j] * Sth[i, j] - St[i, j] * Sh[i, j]) / (n[i, j] * Stt[i, j] - St[i, j]^2))
        end
        ix, iy = sortperm(x), sortperm(y)
        return x[ix], y[iy], days, dzdt[ix, iy], n[ix, iy]
    end
end

"Index of the coordinates `c` (m) on the regular axis `ax` (m), checking that they are on it."
function on_axis(c, ax)
    d = ax[2] - ax[1]
    k = round.(Int, (c .- ax[1]) ./ d) .+ 1
    maximum(abs.(ax[k] .- c)) < 1 || error("tiles are not on a common grid")
    return k
end

"""
    merge_tiles(tiles) -> (x, y, dzdt)

The trends of the tiles on the union of their grids (the same 1 km lattice). Where
tiles overlap and both have a trend, the mean of the two (the differences are
reported).
"""
function merge_tiles(tiles)
    d = tiles[1].x[2] - tiles[1].x[1]
    for tl in tiles
        all(c -> isapprox(c, d; atol=1e-3), diff(tl.x)) && all(c -> isapprox(c, d; atol=1e-3), diff(tl.y)) ||
            error("tiles are not on regular grids of the same spacing ($d m)")
    end
    x0, x1 = minimum(tl.x[1] for tl in tiles), maximum(tl.x[end] for tl in tiles)
    y0, y1 = minimum(tl.y[1] for tl in tiles), maximum(tl.y[end] for tl in tiles)
    x = collect(x0:d:x1 + d / 2)
    y = collect(y0:d:y1 + d / 2)
    S = zeros(length(x), length(y))
    N = zeros(Int32, length(x), length(y))
    noverlap, maxdiff = 0, 0.0
    for tl in tiles
        ix, iy = on_axis(tl.x, x), on_axis(tl.y, y)
        for (jj, j) in enumerate(iy), (ii, i) in enumerate(ix)
            v = tl.dzdt[ii, jj]
            isfinite(v) || continue
            if N[i, j] > 0
                noverlap += 1
                maxdiff = max(maxdiff, abs(v - S[i, j] / N[i, j]))
            end
            S[i, j] += v
            N[i, j] += 1
        end
    end
    noverlap > 0 && println("  $noverlap cells with a trend in two tiles (mean taken), largest difference $(round(maxdiff; sigdigits=3)) m yr-1")
    return x, y, map((s, n) -> n > 0 ? Float32(s / n) : NaN32, S, N)
end

datestr(days) = Dates.format(EPOCH + Millisecond(round(Int64, days * 86_400_000)), dateformat"yyyy-mm-dd")

db = manifest()
dir = get_dataset_path(db, KEY)
out = prepared_dir("ATL15_dzdt")
mkpath(out)

for (region, (name, files, epsg, proj, lat_ts, lon_0)) in REGIONS
    paths = [joinpath(dir, f) for f in files]
    missing_ = filter(!isfile, paths)
    isempty(missing_) || error("missing ATL15 files (download them by hand, see ATL15_dzdt/README.md): $(join(missing_, ", "))")
    tiles = []
    days = nothing
    for p in paths
        println("$(basename(p)): trend of delta_h")
        tx, ty, td, dz, nv = tile_trend(p, lat_ts, lon_0)
        days === nothing && (days = td)
        td == days || error("$(basename(p)): quarters differ from those of $(basename(paths[1]))")
        println("  $(length(td)) quarters $(datestr(td[1])) to $(datestr(td[end])), $(count(isfinite, dz)) cells with a trend")
        push!(tiles, (x=tx, y=ty, dzdt=dz))
        GC.gc()
    end
    x, y, dzdt = length(tiles) == 1 ? (tiles[1].x, tiles[1].y, tiles[1].dzdt) : merge_tiles(tiles)
    nt = length(days)
    nmin = ceil(Int, MIN_VALID * nt)
    period = "$(datestr(days[1])) to $(datestr(days[end]))"

    path = joinpath(out, "ATL15_$region.nc")
    isfile(path) && rm(path)
    NCDataset(path, "c") do ds
        defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
        defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
        defVar(ds, "crs", Int32(0), (); attrib=["proj_params" => proj, "epsg_code" => epsg])
        defVar(ds, "dzdt", dzdt, ("x", "y"); fillvalue=NaN32, deflatelevel=1, shuffle=true,
               attrib=["units" => "m yr-1", "long_name" => "surface elevation change rate, $period",
                       "grid_mapping" => "crs"])
        ds.attrib["title"] = "$name surface elevation change rate $(year(EPOCH + Day(round(Int, days[1]))))-" *
                             "$(year(EPOCH + Day(round(Int, days[end])))), ICESat-2 ATL15 v6"
        ds.attrib["references"] = "Smith, B., Sutterley, T., Dickinson, S., Jelley, B. P., Felikson, D., Neumann, T. A., " *
                                  "Fricker, H., Gardner, A., Padman, L., Markus, T., Kurtz, N., Bhardwaj, S., Hancock, D. " *
                                  "and Lee, J.: ATLAS/ICESat-2 L3B Gridded Antarctic and Arctic Land Ice Height Change " *
                                  "(ATL15, Version 6), NASA NSIDC DAAC, doi:10.5067/ATLAS/ATL15.006, 2026 " *
                                  "($(join(files, ", ")))"
        ds.attrib["doi"] = "10.5067/ATLAS/ATL15.006"
        ds.attrib["license"] = "NASA Earth science data, no restrictions on use or redistribution (cite the data set)"
        ds.attrib["comment"] = "dzdt: linear trend of the quarterly height change delta_h (1 km, group delta_h) over " *
                               "$period, the unweighted least-squares fit against time over the valid quarters of " *
                               "each cell (delta_h given and ice_area > 0); missing where fewer than " *
                               "$(round(Int, 100MIN_VALID))% of the $nt quarters ($nmin) are valid" *
                               (length(files) > 1 ? ". The quadrants are merged on their common 1 km grid " *
                                                    "(the mean where they overlap)" : "")
        ds.attrib["time_coverage_start"] = datestr(days[1])
        ds.attrib["time_coverage_end"] = datestr(days[end])
        ds.attrib["n_quarters"] = Int32(nt)
        ds.attrib["min_valid_quarters"] = Int32(nmin)
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icechange"))
    end
    println("Wrote $path: $(count(isfinite, dzdt)) cells with a trend")
end
