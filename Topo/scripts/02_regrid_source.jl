#
# Remap one original dataset onto the base grid of a domain, and write the result to
# $FESMDATA_WORK/topo/<BASE>/:
#
# - topography sources: z_bed, z_srf, H_ice, z_bed_sd, the area fractions f_ocn,
#   f_land, f_grnd, f_flt, and f_valid (the fraction of each cell covered by the
#   source);
# - thickness sources (glacier tiles): H_ice (cell mean, 0 off the glaciers) and the
#   glacier area fraction f_ice;
# - land sources (DEM tiles): z_land and z_land_sd (mean and standard deviation of the
#   land elevation), the land fraction f_land, and f_valid (the fraction of each cell
#   covered by the tiles).
#
# Usage:
#     julia --project=Topo -t N Topo/scripts/02_regrid_source.jl DOMAIN SOURCE
#
include(joinpath(@__DIR__, "..", "common.jl"))
include(joinpath(TOPO_DIR, "sources.jl"))

length(ARGS) == 2 || error("usage: 02_regrid_source.jl DOMAIN SOURCE")
dom = Domain(ARGS[1])
source = ARGS[2]
base = dom.base

# Remapping onto the base grid, by source grid type
remapper(src::ProjGrid) = (m = AlignedMap(base, src); F -> remap(m, F))
fractions(src::ProjGrid, M) = remap_fractions(base, src, M, MASK_CLASSES)

# Lon-lat sources: samples spaced at most half the source latitude spacing
nsub(src::LonLatGrid) = max(1, ceil(Int, 2 * spacing(base)[1] / (src.dlat * 111.195)))
remapper(src::LonLatGrid) = F -> remap(base, src, F; nsub=nsub(src))
fractions(src::LonLatGrid, M) = remap_fractions(base, src, M, MASK_CLASSES; nsub=nsub(src))

_sq(v) = ismissing(v) ? missing : Float64(v)^2

"""
    regrid(src) -> fields

Fields of a topography source `(grid, z_bed, z_srf, H_ice, mask)` on the base grid.
"""
function regrid(src::NamedTuple)
    println("Source grid: $(size(src.grid)) cells")
    rmp = remapper(src.grid)
    fields = Dict{String,Matrix{Float32}}()
    z_bed, f_valid = rmp(src.z_bed)
    fields["z_bed"] = z_bed
    fields["f_valid"] = f_valid
    fields["z_srf"] = rmp(src.z_srf)[1]
    fields["H_ice"] = rmp(src.H_ice)[1]

    # Standard deviation from the cell means of z_bed and z_bed^2
    z2 = rmp(map(_sq, src.z_bed))[1]
    fields["z_bed_sd"] = Float32.(sqrt.(max.(z2 .- Float64.(z_bed) .^ 2, 0.0)))

    fr, _ = fractions(src.grid, src.mask)
    for (name, c) in (("f_ocn", OCEAN), ("f_land", LAND), ("f_grnd", GRND), ("f_flt", FLT))
        fields[name] = fr[c]
    end
    return fields
end

# Cells of the axis `c` (centres) that overlap the interval `lim`, at least two
# (a grid needs two cells along each axis); empty if there are none.
function _cover(c, lim)
    d = c[2] - c[1]
    i0 = max(1, floor(Int, (lim[1] - c[1]) / d + 0.5) + 1)
    i1 = min(length(c), floor(Int, (lim[2] - c[1]) / d + 0.5) + 1)
    i0 > i1 && return 1:0
    i0 == i1 && return i0 > 1 ? (i0-1:i1) : (i0:i1+1)
    return i0:i1
end

"""
    regrid_glacier_tile(path, ix, iy) -> (H, f, (area, volume, area_pix, volume_pix)) or nothing

Thickness times glacier fraction and glacier fraction of the glacier tile `path` on the
base cells `ix`, `iy` covering it, scaled to the glacier area and volume given with the
tile, and these, given and from the pixels (nothing for a tile without glacier pixels).
"""
function regrid_glacier_tile(path, ix, iy)
    g, H, area, volume = read_tile(path)
    dx, dy = spacing(g)
    a = count(!isnan, H) * dx * dy
    v = sum(h -> isnan(h) ? 0.0 : Float64(h), H) / 1000 * dx * dy
    a > 0 || return nothing
    sa, sv = Float32(area / a), Float32(v > 0 ? volume / v : 1.0)
    sub = ProjGrid("sub", base.xc[ix], base.yc[iy], base.proj)
    n = max(1, ceil(Int, 2 * spacing(base)[1] / spacing(g)[1]))
    Ht, fv = remap(sub, g, H; nsub=n)
    return (map((h, f) -> f > 0 ? sv * h * f : 0f0, Ht, fv), sa .* fv, (area, volume, a, v))
end

"""
    regrid(src::GlacierTiles) -> fields

Cell-mean ice thickness `H_ice` (0 off the glaciers) and glacier area fraction
`f_ice` on the base grid. Only the tiles whose extent overlaps the base grid are
read (threaded). Each is remapped onto the base cells covering it, with samples
spaced at most half the tile spacing, and the tiles are summed in order. Since
the glacier pixels of a tile extend beyond its outline, the thickness and area of
each tile are scaled to the glacier volume and area given with it. Neighbouring
tiles still overlap along shared boundaries, so `f_ice` is limited to 1.
"""
function regrid(src::GlacierTiles)
    # Base cells covered by each tile, from its grid (on one thread: Proj
    # transformations are not thread-safe)
    cover = map(src.grids) do g
        xl, yl = xy_bounds(g, base.proj)
        (_cover(base.xc, xl), _cover(base.yc, yl))
    end
    sel = findall(c -> !(isempty(c[1]) || isempty(c[2])), cover)

    # Read and remap these tiles in parallel: thickness and glacier fraction on the
    # cells covered, and glacier area and volume, given and from the pixels (nothing
    # for tiles without glacier pixels)
    parts = Vector{Union{Nothing,Tuple{Matrix{Float32},Matrix{Float32},NTuple{4,Float64}}}}(nothing, length(sel))
    Threads.@threads :dynamic for k in eachindex(sel)
        parts[k] = regrid_glacier_tile(src.files[sel[k]], cover[sel[k]]...)
    end

    # Sum the tiles in a fixed order (reproducible)
    H_ice = zeros(Float64, size(base))
    f_ice = zeros(Float64, size(base))
    ntiles, area_tiles, vol_tiles, area_pix, vol_pix = 0, 0.0, 0.0, 0.0, 0.0
    for (k, p) in enumerate(parts)
        p === nothing && continue
        ix, iy = cover[sel[k]]
        H_ice[ix, iy] .+= p[1]
        f_ice[ix, iy] .+= p[2]
        area, volume, a, v = p[3]
        ntiles += 1; area_tiles += area; vol_tiles += volume; area_pix += a; vol_pix += v
    end
    println("$ntiles of $(length(src.files)) tiles overlap $(base.name) ($(length(sel)) read): ",
            "area $(round(area_tiles; digits=0)) km2 (pixels $(round(area_pix; digits=0))), ",
            "volume $(round(vol_tiles; digits=0)) km3 (pixels $(round(vol_pix; digits=0))), ",
            "incl. parts outside the domain")

    lon, lat = lonlat(base)
    area_cells = cell_area(base, lon, lat) ./ 1e6  # km2
    println("On $(base.name): glacier area $(round(sum(f_ice .* area_cells); digits=0)) km2 ",
            "($(round(sum(min.(f_ice, 1) .* area_cells); digits=0)) km2 with f_ice <= 1, ",
            "max f_ice $(round(maximum(f_ice); digits=3))), ",
            "volume $(round(sum(H_ice .* area_cells) / 1000; digits=0)) km3")
    return Dict("H_ice" => Float32.(H_ice), "f_ice" => Float32.(min.(f_ice, 1)))
end

# Base cells overlapping the lon-lat box of the lon-lat grid `g` (from its outline on
# the base projection)
function _tile_cover(g::LonLatGrid, trans; npts::Integer=50)
    lon0, lon1 = g.lon[1] - g.dlon / 2, g.lon[end] + g.dlon / 2
    lat0, lat1 = g.latedges[1], g.latedges[end]
    s = range(0, 1; length=npts)
    pts = vcat([(lon0 + t * (lon1 - lon0), la) for t in s, la in (lat0, lat1)][:],
               [(lo, lat0 + t * (lat1 - lat0)) for t in s, lo in (lon0, lon1)][:])
    xy = map(trans, pts)
    return (_cover(base.xc, extrema(first.(xy))), _cover(base.yc, extrema(last.(xy))))
end

"""
    regrid_dem_tile(path, ix, iy) -> (sz, sz2, f_land, f_valid)

Sums of the DEM tile `path` on the base cells `ix`, `iy` covering it: land elevation and
its square times the land fraction, land fraction, and coverage.
"""
function regrid_dem_tile(path, ix, iy)
    g, z = read_dem_tile(path)
    sub = ProjGrid("sub", base.xc[ix], base.yc[iy], base.proj)
    m = SampledMap(sub, g, max(1, ceil(Int, 2 * spacing(base)[1] / (g.dlat * 111.195))))
    land = map(v -> v > 0 ? Float64(v) : NaN, z)
    zl, fl = remap(m, land)
    z2, _ = remap(m, land .^ 2)
    _, fc = remap(m, ones(Float32, size(z)))
    sz = map((v, f) -> f > 0 ? v * f : 0.0, zl, fl)
    sz2 = map((v, f) -> f > 0 ? v * f : 0.0, z2, fl)
    return (sz, sz2, Float64.(fl), Float64.(fc))
end

"""
    regrid(src::DEMTiles) -> fields

Mean and standard deviation of the land elevation (`z_land`, `z_land_sd`, NaN where
there is no land), land fraction `f_land` and tile coverage `f_valid` on the base grid.
Only the tiles overlapping the base grid are read (threaded). Each is remapped onto
the base cells covering it, with samples spaced at most half the tile spacing in
latitude; elevations at or below 0 m are ocean. The tiles are summed in order, so
cells on the edges between tiles combine them.
"""
function regrid(src::DEMTiles)
    trans = FesmUtils.Proj.Transformation("EPSG:4326", base.proj; always_xy=true)
    cover = map(g -> _tile_cover(g, trans), src.grids)
    sel = findall(c -> !(isempty(c[1]) || isempty(c[2])), cover)

    # Sums of each tile on the cells it covers (see `regrid_dem_tile`)
    parts = Vector{NTuple{4,Matrix{Float64}}}(undef, length(sel))
    Threads.@threads :dynamic for k in eachindex(sel)
        parts[k] = regrid_dem_tile(src.files[sel[k]], cover[sel[k]]...)
    end

    # Sum the tiles in a fixed order (reproducible)
    S = [zeros(Float64, size(base)) for _ in 1:4]
    for (k, p) in enumerate(parts)
        ix, iy = cover[sel[k]]
        for q in 1:4
            S[q][ix, iy] .+= p[q]
        end
    end
    sz, sz2, f_land, f_valid = S
    z_land = map((s, f) -> f > 0 ? s / f : NaN, sz, f_land)
    z_sd = map((s2, z, f) -> f > 0 ? sqrt(max(s2 / f - z^2, 0.0)) : NaN, sz2, z_land, f_land)
    lon, lat = lonlat(base)
    area_cells = cell_area(base, lon, lat) ./ 1e6  # km2
    println("$(length(sel)) of $(length(src.files)) tiles overlap $(base.name): land ",
            "$(round(sum(min.(f_land, 1) .* area_cells); digits=0)) km2, covered ",
            "$(round(100 * sum(min.(f_valid, 1) .* area_cells) / sum(area_cells); digits=1))% of the grid")
    return Dict("z_land" => Float32.(z_land), "z_land_sd" => Float32.(z_sd),
                "f_land" => Float32.(min.(f_land, 1)), "f_valid" => Float32.(min.(f_valid, 1)))
end

t0 = time()
src = read_source(source, dom)
println("Read $source: $(round(time() - t0; digits=1)) s")

t0 = time()
fields = regrid(src)
println("Remapped onto $(base.name): $(round(time() - t0; digits=1)) s, threads=$(Threads.nthreads())")

path = write_fields(source_file(dom, source), base, fields; dataset=DATASET,
                    attrib=["source_dataset" => source])
println("Wrote $path")
