# Polygons of the region and basin sources: reading shapefiles and lat/lon outlines,
# and projecting them onto the grid of a domain.
#
# Polygons are kept in lon/lat (degrees) until they are rasterized. Their edges are
# then densified in lon/lat, so that edges along parallels follow the parallel on
# the polar stereographic grids, and their vertices are projected. Edges along
# meridians (e.g. where polygons are cut at 180 degrees) are straight lines on these
# grids. Rings that lie entirely outside the latitudes of a grid are dropped, which
# also removes the rings around the opposite pole, which have no image on the grid.

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
`maxseg` degrees. Rings entirely outside the latitudes of `g` are dropped.
"""
function project_rings(rings::AbstractVector, g::ProjGrid; maxseg::Real=0.1)
    latmin, latmax = lat_bounds(g)
    trans = Proj.Transformation("EPSG:4326", g.proj; always_xy=true)
    out = Vector{NTuple{2,Float64}}[]
    for ring in rings
        lats = last.(ring)
        (maximum(lats) < latmin || minimum(lats) > latmax) && continue
        push!(out, [trans(p) for p in _densify(ring, maxseg)])
    end
    return out
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
