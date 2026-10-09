#
# Remap one original dataset onto the base grid of a domain, and write the result to
# $FESMDATA_WORK/topo/<BASE>/:
#
# - topography sources: z_bed, z_srf, H_ice, z_bed_sd, the area fractions f_ocn,
#   f_land, f_grnd, f_flt, and f_valid (the fraction of each cell covered by the
#   source);
# - thickness sources (glacier tiles): H_ice (cell mean, 0 off the glaciers) and the
#   glacier area fraction f_ice.
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
    regrid(src::GlacierTiles) -> fields

Cell-mean ice thickness `H_ice` (0 off the glaciers) and glacier area fraction
`f_ice` on the base grid. Each tile is remapped onto the base cells covering it,
with samples spaced at most half the tile spacing, and the tiles are summed. Since
the glacier pixels of a tile extend beyond its outline, the thickness and area of
each tile are scaled to the glacier volume and area given with it. Neighbouring
tiles still overlap along shared boundaries, so `f_ice` is limited to 1.
"""
function regrid(src::GlacierTiles)
    # (base cells covered, grid, thickness, area scale, volume scale) of each tile
    tiles = Tuple{UnitRange{Int},UnitRange{Int},ProjGrid,Matrix{Float32},Float32,Float32}[]
    area_tiles, vol_tiles, area_pix, vol_pix = 0.0, 0.0, 0.0, 0.0
    for path in src.files
        g, H, area, volume = read_tile(path)
        xl, yl = xy_bounds(g, base.proj)
        ix, iy = _cover(base.xc, xl), _cover(base.yc, yl)
        (isempty(ix) || isempty(iy)) && continue
        dx, dy = spacing(g)
        a = count(!isnan, H) * dx * dy
        v = sum(h -> isnan(h) ? 0.0 : Float64(h), H) / 1000 * dx * dy
        a > 0 || continue
        push!(tiles, (ix, iy, g, H, area / a, v > 0 ? volume / v : 1.0))
        area_tiles += area; vol_tiles += volume; area_pix += a; vol_pix += v
    end
    println("$(length(tiles)) of $(length(src.files)) tiles overlap $(base.name): ",
            "area $(round(area_tiles; digits=0)) km2 (pixels $(round(area_pix; digits=0))), ",
            "volume $(round(vol_tiles; digits=0)) km3 (pixels $(round(vol_pix; digits=0))), ",
            "incl. parts outside the domain")

    # Remap the tiles in parallel, then sum them in a fixed order (reproducible)
    parts = Vector{NTuple{2,Matrix{Float32}}}(undef, length(tiles))
    Threads.@threads :dynamic for k in eachindex(tiles)
        ix, iy, g, H, sa, sv = tiles[k]
        sub = ProjGrid("sub", base.xc[ix], base.yc[iy], base.proj)
        n = max(1, ceil(Int, 2 * spacing(base)[1] / spacing(g)[1]))
        Ht, fv = remap(sub, g, H; nsub=n)
        parts[k] = (map((h, f) -> f > 0 ? sv * h * f : 0f0, Ht, fv), sa .* fv)
    end
    H_ice = zeros(Float64, size(base))
    f_ice = zeros(Float64, size(base))
    for (k, (ix, iy, _, _)) in enumerate(tiles)
        H_ice[ix, iy] .+= parts[k][1]
        f_ice[ix, iy] .+= parts[k][2]
    end

    lon, lat = lonlat(base)
    area = cell_area(base, lon, lat) ./ 1e6  # km2
    println("On $(base.name): glacier area $(round(sum(f_ice .* area); digits=0)) km2 ",
            "($(round(sum(min.(f_ice, 1) .* area); digits=0)) km2 with f_ice <= 1, ",
            "max f_ice $(round(maximum(f_ice); digits=3))), ",
            "volume $(round(sum(H_ice .* area) / 1000; digits=0)) km3")
    return Dict("H_ice" => Float32.(H_ice), "f_ice" => Float32.(min.(f_ice, 1)))
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
