# Ice extents from outlines (shapefiles of polygons) as area fractions on a fine grid of
# the North domain, for remapping onto its grids: the prepared grid, reading the polygons
# in its coordinates, and their rasterization. Used by the prepare.jl of
# Dalton2020_isochrones and Hughes2016_DATED1 (Batchelor2019_NHIceMasks has its own
# copy, with the filtering of the present-day glaciers of its files).
#
# Needs FesmUtils, ArchGDAL (as AG), GeoInterface (as GI) and Proj, loaded by the caller.

# The 2 km grid of the North domain (polar stereographic, as shared/domains.toml) whose
# cell edges are on the edges of the North grids, covering the grids of the North domain
# (whose first coarse cells reach up to 15 km beyond the base grid): the grid of
# Batchelor2019_NHIceMasks.
const NORTH_PROJ = "+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +x_0=0 +y_0=0 +a=6378137 +rf=298.25722356 +units=km"
const NORTH_XEDGES = (-5131.0, 4661.0)
const NORTH_YEDGES = (-5421.0, 4181.0)
const NORTH_DX = 2.0

"The 2 km prepared grid of the North domain (see `NORTH_XEDGES`, `NORTH_YEDGES`)."
north_outline_grid(name) = ProjGrid(name, (NORTH_XEDGES[1] + NORTH_DX / 2, NORTH_XEDGES[2] - NORTH_DX / 2),
                                    (NORTH_YEDGES[1] + NORTH_DX / 2, NORTH_YEDGES[2] - NORTH_DX / 2), NORTH_DX, NORTH_PROJ)

# Ring edges densified to at most `maxseg` (in the coordinates of the ring)
function densify_ring(ring, maxseg)
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

"""
    read_outlines(path, g; keep = f -> true) -> (polygons, stats)

The polygons of a shapefile (Polygon or MultiPolygon features, those for which
`keep(feature)` holds), each a vector of rings (outer rings and holes) in the coordinates
of the grid `g` (km), the edges densified to 0.01° (geographic files) or 1 km before
projecting, so that the curvature of the projection is kept. Rings entirely outside the
grid are dropped; rings partly outside are kept (rasterized where they lie in the grid).
`stats`: the number of features, of rings, of rings dropped and of rings partly outside.
"""
function read_outlines(path, g::ProjGrid; keep=f -> true)
    polys = Vector{Vector{NTuple{2,Float64}}}[]
    st = (features=0, rings=0, dropped=0, partly=0)
    h = (g.xc[2] - g.xc[1]) / 2
    xe = (g.xc[1] - h, g.xc[end] + h); ye = (g.yc[1] - h, g.yc[end] + h)
    ingrid((x, y)) = xe[1] <= x <= xe[2] && ye[1] <= y <= ye[2]
    AG.read(path) do ds
        layer = AG.getlayer(ds, 0)
        sr = AG.getspatialref(layer)
        geographic = occursin("+proj=longlat", AG.toPROJ4(sr))
        maxseg = geographic ? 0.01 : 1000.0                   # degrees or m
        to_grid = Proj.Transformation(AG.toWKT(sr), g.proj; always_xy=true)
        for f in layer
            keep(f) || continue
            st = merge(st, (features=st.features + 1,))
            geom = AG.getgeom(f)
            tr = GI.geomtrait(geom)
            parts = tr isa GI.MultiPolygonTrait ? collect(GI.getgeom(geom)) :
                    tr isa GI.PolygonTrait ? [geom] : error("$(basename(path)): geometry $tr, not polygons")
            rings = Vector{NTuple{2,Float64}}[]
            for p in parts, r in GI.getgeom(p)
                pts = [(Float64(GI.x(q)), Float64(GI.y(q))) for q in GI.getpoint(r)]
                st = merge(st, (rings=st.rings + 1,))
                ring = [NTuple{2,Float64}(to_grid(q)) for q in densify_ring(pts, maxseg)]
                all(q -> all(isfinite, q), ring) || error("$(basename(path)): a ring does not project onto the grid")
                inside = count(ingrid, ring)
                if inside == 0
                    st = merge(st, (dropped=st.dropped + 1,))
                    continue
                end
                inside < length(ring) && (st = merge(st, (partly=st.partly + 1,)))
                push!(rings, ring)
            end
            isempty(rings) || push!(polys, rings)
        end
    end
    return polys, st
end

"""
    outline_fraction(g, polys; nsub = 8, band = 250) -> Matrix{Float32}

Fraction of each cell of `g` inside any of the polygons (each by the even-odd rule over
its rings; union of the polygons), from `nsub` x `nsub` samples per cell, rasterized in
bands of `band` rows.
"""
function outline_fraction(g::ProjGrid, polys; nsub=8, band=250)
    nx, ny = size(g)
    F = zeros(Float32, nx, ny)
    dx = g.xc[2] - g.xc[1]
    d = dx / nsub
    xs = g.xc[1] - dx / 2 + d / 2 .+ d .* (0:nx*nsub-1)
    for j0 in 1:band:ny
        j1 = min(ny, j0 + band - 1)
        ys = g.yc[j0] - dx / 2 + d / 2 .+ d .* (0:(j1-j0+1)*nsub-1)
        sg = ProjGrid("band", xs, ys, g.proj)
        mask = zeros(Bool, size(sg))
        for rings in polys
            rasterize!(mask, sg, rings)
        end
        Threads.@threads for jj in j0:j1
            for i in 1:nx
                s = 0
                for b in 1:nsub, a in 1:nsub
                    s += mask[(i-1)*nsub+a, (jj-j0)*nsub+b]
                end
                F[i, jj] = s / nsub^2
            end
        end
    end
    return F
end

"Area [million km2, projected] of the fractions `F` on `g`."
outline_area(g::ProjGrid, F) = sum(Float64, F) * (g.xc[2] - g.xc[1])^2 / 1e6
