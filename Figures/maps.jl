# Maps on the grids of the domains, shared by the figures: axes, coastlines and colour
# scales of continuous fields and of classes.

import GeoInterface
import NaturalEarth
import Proj

"Height of a map panel (px); its width follows the aspect of the grid."
const PANEL_HEIGHT = 240

"Colour of the cells without data."
const NODATA_COLOR = RGBf(0.9, 0.9, 0.9)

"Topography product of each domain (key) with its coastline: the products of the zones of Regions."
topo_reference() = TOML.parsefile(joinpath(REPO_DIR, "Regions", "regions.toml"))["zone"]["products"]

"Domain (key) of a grid."
domain_key(og::OutGrid) = folder_grids(og.folder)[1].key

"Width of the map of a grid relative to its height."
map_aspect(g::ProjGrid) = (g.xc[end] - g.xc[1]) / (g.yc[end] - g.yc[1])
map_aspect(g::LonLatGrid) = 2.0

"Cell centres of a grid in the coordinates of its maps (km, or degrees)."
map_coords(g::ProjGrid) = (g.xc, g.yc)
map_coords(g::LonLatGrid) = (g.lon, g.lat)

"""
    map_axis(pos, og; title="", window=nothing)

A map of a grid at `pos` of a figure: equal axes, no ticks, grey where there are no
data; the whole grid, or the `window` (xmin, xmax, ymin, ymax).
"""
function map_axis(pos, og::OutGrid; title::AbstractString="", window=nothing)
    ax = Axis(pos; aspect=DataAspect(), title=title, titlesize=11, backgroundcolor=NODATA_COLOR)
    hidedecorations!(ax)
    x, y = map_coords(og.grid)
    window === nothing ? limits!(ax, extrema(x), extrema(y)) : limits!(ax, window...)
    return ax
end

"""
    coastline!(ax, og)

The coastline on a map of a grid: the ice-free ocean margin (`f_ocn` = 0.5) of the
topography of the domain on the same grid (Topo), or the Natural Earth coastline on a
lon-lat grid.
"""
function coastline!(ax, og::OutGrid)
    if og.grid isa LonLatGrid
        lines!(ax, natural_earth_coastline(); color=:black, linewidth=0.5)
        return
    end
    path = product_file(og, topo_reference()[domain_key(og)])
    isfile(path) || (@warn "no coastline on $(og.grid.name): no $path"; return)
    f_ocn = NCDataset(ds -> Float32.(coalesce.(ds["f_ocn"][:, :], NaN)), path)
    contour!(ax, og.grid.xc, og.grid.yc, f_ocn; levels=[0.5], color=:black, linewidth=0.5)
end

const _COASTLINE = Ref{Vector{Point2f}}()

"The Natural Earth coastline (1:110m), in lon-lat, its lines separated by NaN."
function natural_earth_coastline()
    isassigned(_COASTLINE) && return _COASTLINE[]
    pts = Point2f[]
    for f in NaturalEarth.naturalearth("coastline", 110)
        for line in _lines(GeoInterface.coordinates(GeoInterface.geometry(f)))
            append!(pts, Point2f(c[1], c[2]) for c in line)
            push!(pts, Point2f(NaN, NaN))
        end
    end
    return _COASTLINE[] = pts
end

# The lines of a LineString or MultiLineString as nested coordinates
_lines(c) = first(first(c)) isa Number ? [c] : c

"Points (lon, lat) in the coordinates of a projected grid (km)."
function project(og::OutGrid, lon, lat)
    t = Proj.Transformation("EPSG:4326", og.grid.proj; always_xy=true)
    xy = [t(Float64(lo), Float64(la)) for (lo, la) in zip(lon, lat)]
    return first.(xy), last.(xy)
end

# ---------------------------------------------------------------------------
# Colour scales
# ---------------------------------------------------------------------------

"""
    ColorScale

How a field is coloured: a continuous scale (colormap, range, log or linear), or
classes, whose values are drawn as 1..n with their labels.
"""
struct ColorScale
    colormap::Any
    colorrange::Tuple{Float64,Float64}
    log::Bool
    classes::Vector{Int}            # empty for a continuous field
    labels::Vector{String}
end

is_classes(c::ColorScale) = !isempty(c.classes)

"""
    continuous_scale(values; colormap=nothing, colorrange=nothing, log=false) -> ColorScale

Colour scale of a continuous field from all its values (of all panels): the 2-98%
range, symmetric with a diverging colour map when the values have both signs in
similar amounts, unless given.
"""
function continuous_scale(values; colormap=nothing, colorrange=nothing, log::Bool=false)
    v = filter(x -> isfinite(x) && (!log || x > 0), values)
    if colorrange === nothing
        isempty(v) && (v = [0.0, 1.0])
        lo, hi = quantile(v, (0.02, 0.98))
        if !log && lo < 0 < hi && min(-lo, hi) / max(-lo, hi) > 0.2
            m = max(-lo, hi)
            lo, hi = -m, m
            colormap === nothing && (colormap = :balance)
        end
        lo == hi && (hi = lo + 1)
        colorrange = (lo, hi)
    end
    return ColorScale(something(colormap, :viridis), Tuple(Float64.(colorrange)), log, Int[], String[])
end

"""
    class_scale(values, names) -> ColorScale

Colour scale of classes (integer codes) from all their values (of all panels), with
the names of the codes (`flag_values`/`flag_meanings`), where known.
"""
function class_scale(values, names::AbstractDict)
    classes = sort(unique(Int(x) for x in values if isfinite(x)))
    n = max(length(classes), 1)
    colors = n <= 10 ? Makie.to_colormap(:tab10)[1:n] : n <= 20 ? Makie.to_colormap(:tab20)[1:n] :
             distinguishable_colors(n, [RGB(1, 1, 1), RGB(0, 0, 0)]; dropseed=true)
    labels = [get(names, c, string(c)) for c in classes]
    return ColorScale(cgrad(colors, n; categorical=true), (0.5, n + 0.5), false, classes, labels)
end

"Class names by code from the attributes `flag_values` and `flag_meanings` of a variable."
function flag_names(attrib)
    haskey(attrib, "flag_values") && haskey(attrib, "flag_meanings") || return Dict{Int,String}()
    return Dict(Int(v) => replace(m, "_" => " ") for (v, m) in zip(attrib["flag_values"], split(attrib["flag_meanings"])))
end

"Values of a field as drawn with a colour scale (classes: their index, NaN elsewhere)."
function drawn(c::ColorScale, data)
    is_classes(c) || return c.log ? map(x -> x > 0 ? x : NaN32, data) : data
    index = Dict(v => i for (i, v) in enumerate(c.classes))
    return map(x -> isfinite(x) ? Float32(get(index, Int(x), NaN)) : NaN32, data)
end

"""
    field!(ax, og, data, scale)

A field on a map of a grid, with its colour scale and the coastline; returns the plot.
"""
function field!(ax, og::OutGrid, data, scale::ColorScale)
    x, y = map_coords(og.grid)
    hm = heatmap!(ax, x, y, drawn(scale, data); colormap=scale.colormap, colorrange=scale.colorrange,
                  colorscale=scale.log ? log10 : identity, nan_color=:transparent)
    coastline!(ax, og)
    return hm
end

"A colour bar of a colour scale at `pos`: class names as ticks (up to 16 classes)."
function scale_bar(pos, hm, scale::ColorScale; label::AbstractString="")
    if is_classes(scale)
        n = length(scale.classes)
        ticks = n <= 16 ? (1:n, scale.labels) : ([1, n], scale.labels[[1, n]])
        return Colorbar(pos; colormap=scale.colormap, limits=scale.colorrange, ticks=ticks, label=label,
                        ticklabelsize=9, labelsize=10, width=10)
    end
    return Colorbar(pos, hm; label=label, ticklabelsize=9, labelsize=10, width=10)
end
