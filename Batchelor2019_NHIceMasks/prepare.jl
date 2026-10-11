# Prepare the Northern Hemisphere ice-sheet extents of Batchelor et al. (2019) for remapping:
# the best-estimate, minimum and maximum extents of the 18 time slices, rasterized as ice
# area fractions on a 2 km polar stereographic grid (the projection of the North domain)
# that covers all outlines, in one prepared NetCDF file,
# $FESMDATA_WORK/prepared/Batchelor2019_NHIceMasks/Batchelor2019_NH_ICE.nc, with f_ice_best,
# f_ice_min and f_ice_max on (x, y, time).
#
# Usage:
#     julia -t 16 --project=Batchelor2019_NHIceMasks Batchelor2019_NHIceMasks/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Batchelor2019_NHIceMasks/Batchelor2019_NH_ICE.nc North

using FesmUtils
using NCDatasets
import ArchGDAL as AG
import GeoInterface as GI
import Proj

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "batchelor2019_nh_ice"

# Grid: the projection of the North domain (shared/domains.toml), 2 km cells (as the
# finest North grid) whose edges are on the edges of the North grids, covering all outlines (x -5120 to 4649 km,
# y -5396 to 4170 km) and the grids of the North domain (whose first coarse cells reach
# up to 15 km beyond the base grid).
const PROJ = "+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +x_0=0 +y_0=0 +a=6378137 +rf=298.25722356 +units=km"
const XEDGES = (-5131.0, 4661.0)
const YEDGES = (-5421.0, 4181.0)
const DX = 2.0
const NSUB = 8                         # samples per cell side (250 m)
const BAND = 250                       # rows of cells rasterized at once

# Time slices: folder of the OSF project, label, age (years before 1950) assigned in
# time_slices.md. Oldest first; the order of the paper's first two slices (the Early
# Matuyama Chron is younger than the Late Gauss Chron) is reversed.
const SLICES = [
    ("Late Gauss Chron", "Late Gauss Chron", 3_100_000),
    ("Early Matuyama Chron", "Early Matuyama Chron", 2_200_000),
    ("MIS 20-24", "MIS 20-24", 860_000),
    ("MIS 16", "MIS 16", 650_000),
    ("MIS 12", "MIS 12", 440_000),
    ("MIS 10", "MIS 10", 350_000),
    ("MIS 8", "MIS 8", 260_000),
    ("MIS 6", "MIS 6", 140_000),
    ("MIS 5d", "MIS 5d", 112_000),
    ("MIS 5c", "MIS 5c", 100_000),
    ("MIS 5b", "MIS 5b", 88_000),
    ("MIS 5a", "MIS 5a", 80_000),
    ("MIS 4", "MIS 4", 65_000),
    ("45 ka", "45 ka", 45_000),
    ("40 ka", "40 ka", 40_000),
    ("35 ka", "35 ka", 35_000),
    ("30 ka", "30 ka", 30_000),
    ("LGM", "LGM", 26_500),
]

# Fields and the suffix of their shapefiles. The LGM has only a best estimate, which is
# also used as its minimum and maximum.
const ESTIMATES = [("f_ice_best", "_best_estimate", "best-estimate"),
                   ("f_ice_min", "_min", "minimum"),
                   ("f_ice_max", "_max", "maximum")]

"Shapefile of a time slice and estimate (in the folder hypothesised ice-sheet reconstruction(s))."
function shapefile(dir, folder, suffix)
    sub = filter(d -> startswith(d, "hypothesised ice-sheet reconstruction"), readdir(joinpath(dir, folder)))
    length(sub) == 1 || error("$folder: no single reconstruction folder")
    files = filter(f -> endswith(f, suffix * ".shp"), readdir(joinpath(dir, folder, sub[1])))
    isempty(files) && return nothing
    length(files) == 1 || error("$folder: several shapefiles $suffix")
    return joinpath(dir, folder, sub[1], files[1])
end

# Ring edges densified to at most `maxseg` (in the coordinates of the ring)
function densify(ring, maxseg)
    out = NTuple{2,Float64}[]
    n = length(ring)
    for k in 1:n
        a, b = ring[k], ring[k == n ? 1 : k + 1]
        m = max(1, ceil(Int, hypot(b[1] - a[1], b[2] - a[2]) / maxseg))
        for s in 0:m-1
            push!(out, (a[1] + s / m * (b[1] - a[1]), a[2] + s / m * (b[2] - a[2])))
        end
    end
    return out
end

ingrid((x, y)) = XEDGES[1] <= x <= XEDGES[2] && YEDGES[1] <= y <= YEDGES[2]

"""
    read_polygons(path) -> (polygons, ndropped)

The polygons of a shapefile, each a vector of rings (outer rings and holes) in the
coordinates of the grid (km). Some files include present-day glaciers of the whole globe
(Natural Earth glaciated areas): rings with points south of the equator (or that do not
project) and rings entirely outside the grid (low-latitude glaciers) are dropped. A ring
partly outside the grid is an error.
"""
function read_polygons(path)
    polys = Vector{Vector{NTuple{2,Float64}}}[]
    ndropped = 0
    AG.read(path) do ds
        layer = AG.getlayer(ds, 0)
        wkt = AG.toWKT(AG.getspatialref(layer))
        geographic = occursin("+proj=longlat", AG.toPROJ4(AG.getspatialref(layer)))
        maxseg = geographic ? 0.01 : 1000.0                   # degrees or m
        to_lonlat = Proj.Transformation(wkt, "EPSG:4326"; always_xy=true)
        to_grid = Proj.Transformation(wkt, PROJ; always_xy=true)
        for f in layer
            g = AG.getgeom(f)
            parts = GI.geomtrait(g) isa GI.MultiPolygonTrait ? collect(GI.getgeom(g)) : [g]
            rings = Vector{NTuple{2,Float64}}[]
            for p in parts, r in GI.getgeom(p)
                pts = [(Float64(GI.x(q)), Float64(GI.y(q))) for q in GI.getpoint(r)]
                lats = [to_lonlat(q)[2] for q in pts]
                if !all(isfinite, lats) || minimum(lats) < 0
                    ndropped += 1
                    continue
                end
                ring = [NTuple{2,Float64}(to_grid(q)) for q in densify(pts, maxseg)]
                inside = count(ingrid, ring)
                if inside == 0
                    ndropped += 1
                    continue
                end
                inside == length(ring) || error("$(basename(path)): outline partly outside the grid, at latitudes $(extrema(lats))")
                push!(rings, ring)
            end
            isempty(rings) || push!(polys, rings)
        end
    end
    return polys, ndropped
end

"""
    ice_fraction(g, polys) -> Matrix{Float32}

Fraction of each cell of `g` inside any of the polygons, from NSUB x NSUB samples per
cell (each polygon by the even-odd rule over its rings), rasterized in bands of rows.
"""
function ice_fraction(g::ProjGrid, polys)
    nx, ny = size(g)
    F = zeros(Float32, nx, ny)
    d = DX / NSUB
    xs = g.xc[1] - DX / 2 + d / 2 .+ d .* (0:nx*NSUB-1)
    for j0 in 1:BAND:ny
        j1 = min(ny, j0 + BAND - 1)
        ys = g.yc[j0] - DX / 2 + d / 2 .+ d .* (0:(j1-j0+1)*NSUB-1)
        sg = ProjGrid("band", xs, ys, g.proj)
        mask = zeros(Bool, size(sg))
        for rings in polys
            rasterize!(mask, sg, rings)
        end
        Threads.@threads for jj in j0:j1
            for i in 1:nx
                s = 0
                for b in 1:NSUB, a in 1:NSUB
                    s += mask[(i-1)*NSUB+a, (jj-j0)*NSUB+b]
                end
                F[i, jj] = s / NSUB^2
            end
        end
    end
    return F
end

dir = download_dataset(manifest(), KEY)
g = ProjGrid("Batchelor2019", (XEDGES[1] + DX / 2, XEDGES[2] - DX / 2), (YEDGES[1] + DX / 2, YEDGES[2] - DX / 2), DX, PROJ)
nx, ny = size(g)
nt = length(SLICES)

path = joinpath(prepared_dir("Batchelor2019_NHIceMasks"), "Batchelor2019_NH_ICE.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "x", g.xc, ("x",); attrib=["units" => "km", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", g.yc, ("y",); attrib=["units" => "km", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "time", Float64[a for (_, _, a) in SLICES], ("time",);
           attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)",
                   "comment" => "ages assigned to the time slices in time_slices.md (see label)"])
    defVar(ds, "label", String[l for (_, l, _) in SLICES], ("time",); attrib=["long_name" => "time slice of Batchelor et al. (2019)"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic", "proj_params" => PROJ])
    for (name, _, est) in ESTIMATES
        attrib = ["units" => "1", "long_name" => "ice area fraction, $est ice-sheet extent", "grid_mapping" => "crs"]
        name == "f_ice_best" || push!(attrib, "comment" => "the LGM has only a best estimate, used here as well")
        defVar(ds, name, Float32, ("x", "y", "time"); deflatelevel=1, shuffle=true, chunksizes=(1000, 1000, 1), attrib)
    end
    ds.attrib["title"] = "Northern Hemisphere ice-sheet extents through the Quaternary (Batchelor et al., 2019)"
    ds.attrib["references"] = "Batchelor, C. L., Margold, M., Krapp, M., Murton, D. K., Dalton, A. S., Gibbard, P. L., " *
                              "Stokes, C. R., Murton, J. B. and Manica, A.: The configuration of Northern Hemisphere ice " *
                              "sheets through the Quaternary, Nat. Commun., 10, 3713, 2019, doi:10.1038/s41467-019-11601-2; " *
                              "data: https://osf.io/7jen3/"
    ds.attrib["doi"] = "10.1038/s41467-019-11601-2"
    ds.attrib["license"] = "No licence stated for the shapefiles (OSF project 7jen3); the article is CC BY 4.0"
    ds.attrib["comment"] = "Shapefiles rasterized as the fraction of $(NSUB)x$(NSUB) samples per cell inside the " *
                           "outlines; outlines of present-day glaciers south of the equator or outside the grid (low latitudes) left out"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))

    for (k, (folder, label, age)) in enumerate(SLICES)
        best = nothing
        for (name, suffix, _) in ESTIMATES
            shp = shapefile(dir, folder, suffix)
            if shp === nothing
                label == "LGM" && name != "f_ice_best" || error("$folder: no shapefile $suffix")
                ds[name][:, :, k] = best
                println("$label $name: best estimate")
                continue
            end
            polys, ndropped = read_polygons(shp)
            F = ice_fraction(g, polys)
            name == "f_ice_best" && (best = F)
            ds[name][:, :, k] = F
            println("$label $name: $(basename(shp)), $(length(polys)) polygons ($ndropped rings of glaciers south of the equator or outside the grid left out), ",
                    "ice area $(round(sum(F) * DX^2 / 1e6; digits=2)) million km2 (projected)")
        end
    end
end
println("Wrote $path")
