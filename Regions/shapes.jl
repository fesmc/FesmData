# Polygons of the region and basin sources: reading shapefiles and lat/lon outlines,
# and projecting them onto the grid of a domain.
#
# Polygons are kept in lon/lat (degrees) until they are rasterized. Their edges are
# then densified in lon/lat, so that edges along parallels follow the parallel on
# the polar stereographic grids, and their vertices are projected. Edges along
# meridians (e.g. where polygons are cut at 180 degrees) are straight lines on these
# grids. Rings that lie entirely outside the latitudes of a grid are dropped, which
# also removes the rings around the opposite pole, which have no image on the grid.
# On grids without a pole (e.g. the UTM grids of mountain domains), the rings are
# also clipped to a lon/lat box around the grid before they are projected, since
# such projections cannot map points far from the grid (e.g. transverse Mercator
# beyond 90 degrees from its central meridian).

import ArchGDAL as AG
import GeoInterface as GI
import Proj

"""
    Shape

A polygon in lon/lat: its rings (outer rings and holes, even-odd rule) and the
attributes of its feature.
"""
struct Shape
    rings::Vector{Vector{NTuple{2,Float64}}}
    attrs::Dict{String,Any}
end

"""
    read_shapes(path) -> Vector{Shape}

The polygons of the first layer of a vector file (e.g. a shapefile), in lon/lat.
"""
function read_shapes(path::AbstractString)
    shapes = Shape[]
    AG.read(path) do ds
        layer = AG.getlayer(ds, 0)
        to_lonlat = _lonlat_transform(AG.getspatialref(layer))
        fd = AG.layerdefn(layer)
        names = [AG.getname(AG.getfielddefn(fd, i)) for i in 0:AG.nfield(fd)-1]
        for f in layer
            attrs = Dict{String,Any}(n => AG.getfield(f, i - 1) for (i, n) in enumerate(names))
            geom = AG.getgeom(f)
            push!(shapes, Shape(_rings(geom, to_lonlat), attrs))
        end
    end
    return shapes
end

# Transformation to lon/lat, or identity for files in lon/lat (WGS84)
function _lonlat_transform(sr)
    occursin("+proj=longlat +datum=WGS84", AG.toPROJ4(sr)) && return identity
    return Proj.Transformation(AG.toWKT(sr), "EPSG:4326"; always_xy=true)
end

function _rings(geom, to_lonlat)
    out = Vector{NTuple{2,Float64}}[]
    t = GI.geomtrait(geom)
    if t isa GI.MultiPolygonTrait
        for p in GI.getgeom(geom)
            append!(out, _rings(p, to_lonlat))
        end
    elseif t isa GI.PolygonTrait
        for r in GI.getgeom(geom)
            push!(out, [NTuple{2,Float64}(to_lonlat((GI.x(p), GI.y(p)))) for p in GI.getpoint(r)])
        end
    else
        error("unsupported geometry $(typeof(t))")
    end
    return out
end

"""
    project_rings(rings, g::ProjGrid; maxseg=0.1) -> rings in grid coordinates

Rings in lon/lat projected onto grid `g`, after densifying their edges to at most
`maxseg` degrees. Rings entirely outside the latitudes of `g` are dropped. On grids
without a pole, the rings are clipped to the lon/lat box of the grid (`lonlat_box`)
first, which leaves them unchanged within the grid.
"""
function project_rings(rings::AbstractVector, g::ProjGrid; maxseg::Real=0.1)
    latmin, latmax = lat_bounds(g)
    boxes = lonlat_box(g)
    trans = Proj.Transformation("EPSG:4326", g.proj; always_xy=true)
    out = Vector{NTuple{2,Float64}}[]
    for ring in rings
        lats = last.(ring)
        (maximum(lats) < latmin || minimum(lats) > latmax) && continue
        pts = _densify(ring, maxseg)
        if boxes === nothing
            push!(out, [trans(p) for p in pts])
        else
            pts = _unwrap(pts)
            lo, hi = extrema(first.(pts))
            for box in boxes, s in 360 .* (floor(Int, (lo - box[2]) / 360):ceil(Int, (hi - box[1]) / 360))
                c = _clip(pts, (box[1] + s, box[2] + s, box[3], box[4]))
                length(c) >= 3 && push!(out, [trans(p) for p in c])
            end
        end
    end
    return out
end

"""
    lonlat_box(g; margin=1) -> nothing or [(lonmin, lonmax, latmin, latmax)]

Lon/lat box around grid `g`, widened by `margin` degrees, from points along the
outline of its cells (nothing for a grid with a pole). Longitudes may extend beyond
180 degrees; rings are clipped to it shifted by multiples of 360 degrees (see
`project_rings`).
"""
function lonlat_box(g::ProjGrid; margin::Real=1)
    latmin, latmax = lat_bounds(g; margin=margin)
    (latmin == -90 || latmax == 90) && return nothing
    dx, dy = spacing(g)
    xe = vcat(g.xc .- dx / 2, g.xc[end] + dx / 2)
    ye = vcat(g.yc .- dy / 2, g.yc[end] + dy / 2)
    outline = vcat([(x, ye[1]) for x in xe], [(xe[end], y) for y in ye],
                   [(x, ye[end]) for x in reverse(xe)], [(xe[1], y) for y in reverse(ye)])
    trans = Proj.Transformation(g.proj, "EPSG:4326"; always_xy=true)
    lons = [first(trans(p)) for p in outline]
    for k in 2:length(lons)     # continuous across 180 degrees
        lons[k] += 360 * round((lons[k-1] - lons[k]) / 360)
    end
    lo, hi = minimum(lons) - margin, maximum(lons) + margin
    return [(lo, hi, latmin, latmax)]
end

# Densified ring with continuous longitudes (no jumps of 360 degrees where it crosses
# 180 degrees), so that its edges are straight in lon/lat. A ring around a pole (net
# change of longitude of 360 degrees, e.g. a circle around Antarctica) is closed
# along the pole of its hemisphere, which it encloses.
function _unwrap(pts)
    out = copy(pts)
    for k in 2:length(out)
        lon, lat = out[k]
        out[k] = (lon + 360 * round((out[k-1][1] - lon) / 360), lat)
    end
    # Closing edge, from the last point back to the first
    lon1 = out[1][1] + 360 * round((out[end][1] - out[1][1]) / 360)
    if abs(lon1 - out[1][1]) > 180
        pole = sum(last, out) > 0 ? 90.0 : -90.0
        append!(out, [(lon1, out[1][2]), (lon1, pole), (out[1][1], pole)])
    end
    return out
end

# Ring clipped to a lon/lat box (Sutherland-Hodgman, one side at a time). Edges are
# straight in lon/lat, as after `_densify`; parts of the result along the sides of the
# box, outside the grid, do not change which cells of the grid the ring covers.
function _clip(ring, box)
    lo, hi, latmin, latmax = box
    pts = ring
    for (k, v, keep_above) in ((1, lo, true), (1, hi, false), (2, latmin, true), (2, latmax, false))
        isempty(pts) && break
        inside(p) = keep_above ? p[k] >= v : p[k] <= v
        out = NTuple{2,Float64}[]
        n = length(pts)
        for i in 1:n
            a, b = pts[i], pts[i == n ? 1 : i + 1]
            ia, ib = inside(a), inside(b)
            ia && push!(out, a)
            if ia != ib
                t = (v - a[k]) / (b[k] - a[k])
                push!(out, (a[1] + t * (b[1] - a[1]), a[2] + t * (b[2] - a[2])))
            end
        end
        pts = out
    end
    return pts
end

# Edges are interpolated in lon/lat the short way round, so that rings around a pole
# or across 180 degrees (outlines given as points) stay intact, except edges spanning
# all longitudes (-180 to 180), which follow their parallel.
function _densify(ring, maxseg)
    out = NTuple{2,Float64}[]
    n = length(ring)
    for k in 1:n
        a, b = ring[k], ring[k == n ? 1 : k + 1]
        dlon = b[1] - a[1]
        if 180 < abs(dlon) < 360 - 1e-6
            dlon -= sign(dlon) * 360
        end
        dlat = b[2] - a[2]
        m = max(1, ceil(Int, max(abs(dlon), abs(dlat)) / maxseg))
        for s in 0:m-1
            push!(out, (a[1] + s / m * dlon, a[2] + s / m * dlat))
        end
    end
    return out
end

"""
    rasterize!(mask::Matrix{Bool}, g::ProjGrid, shapes::AbstractVector{Shape}) -> mask

Add the cells of `g` whose centre lies inside any of `shapes` to `mask`.
"""
function FesmUtils.rasterize!(mask::Matrix{Bool}, g::ProjGrid, shapes::AbstractVector{Shape})
    for s in shapes
        rings = project_rings(s.rings, g)
        isempty(rings) || rasterize!(mask, g, rings)
    end
    return mask
end

FesmUtils.rasterize(g::ProjGrid, shapes::AbstractVector{Shape}) =
    BitMatrix(rasterize!(zeros(Bool, size(g)), g, shapes))
