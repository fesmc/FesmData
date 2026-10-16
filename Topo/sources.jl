# Readers of the original datasets. Each topography source returns the fields on
# its native grid, with ascending axes:
#
#     (grid, z_bed, z_srf, H_ice, mask)
#
# where `grid` is a ProjGrid or LonLatGrid, and `mask` uses the classes below
# (`missing` where the source has no data).
#
# Thickness sources (`is_thickness_source`) only give the ice thickness of glaciers,
# as tiles on their own projections (`GlacierTiles`). In a product they add grounded
# ice onto the ice-free land of the sources below them (see 03_merge.jl).
#
# Land sources (`is_land_source`) only give the elevation of the land, as lon-lat
# tiles (`DEMTiles`). In a product they set the land, ice-free, and its elevation
# wherever their tiles reach (see 03_merge.jl).
#
# A topography source replaces the sources below it in a product with a weight rising
# from 0 at the edge of its coverage to 1 at `taper_km` inside it (see 03_merge.jl).

using NCDatasets
import ArchGDAL as AG
import Downloads
using MAT

const OCEAN = Int8(0)
const LAND  = Int8(1)
const GRND  = Int8(2)
const FLT   = Int8(3)
const MASK_CLASSES = (OCEAN, LAND, GRND, FLT)

const PS_NORTH = polar_stereographic_proj(lat_0=90, lat_ts=70, lon_0=-45, a=6378137, rf=298.257223563)
const PS_SOUTH = polar_stereographic_proj(lat_0=-90, lat_ts=-71, lon_0=0, a=6378137, rf=298.257223563)

"""
    read_source(name, dom) -> (grid, z_bed, z_srf, H_ice, mask)

Read source `name` (an entry of datamanifest.toml, or `bedmap2` for its entries
`bedmap2_*`) for domain `dom`. Lon-lat sources are read only over the latitudes
covered by its base grid, and glacier tiles only within these latitudes.
"""
function read_source(name::AbstractString, dom::Domain)
    db = manifest()
    if startswith(name, "bedmachine_greenland_")
        return read_bedmachine(get_dataset_path(db, name), PS_NORTH, LAND)
    elseif startswith(name, "bedmachine_antarctica_")
        return read_bedmachine(get_dataset_path(db, name), PS_SOUTH, GRND)
    elseif name == "bedmap3"
        return read_bedmap3(get_dataset_path(db, name))
    elseif name == "bedmap2"
        return read_bedmap2(db)
    elseif startswith(name, "gebco")
        return read_gebco(_nc_file(get_dataset_path(db, name)), dom)
    elseif name == "iceboost_v2"
        return read_iceboost(db, dom)
    elseif haskey(COPERNICUS_DEMS, name)
        return read_copdem(db, name, dom)
    elseif name == "sommers2025_drangdrung"
        return read_sommers2025(db, dom)
    end
    error("unknown source $name")
end

"""
    taper_km(name) -> Float64

Width (km) over which a topography source fades in from the edge of its coverage in a
product (see 03_merge.jl): 20 km, so that a regional dataset meets GEBCO smoothly, and
0 for the sources that replace exactly the base cells they fully cover (a regional
dataset smaller than the taper, whose edge lies on land of the same surface).
"""
taper_km(name::AbstractString) = name == "sommers2025_drangdrung" ? 0.0 : 20.0

"True for sources that only give glacier ice thickness (see `GlacierTiles`)."
is_thickness_source(name::AbstractString) = name == "iceboost_v2"

"True for sources that only give the elevation of the land (see `DEMTiles`)."
is_land_source(name::AbstractString) = haskey(COPERNICUS_DEMS, name)

# The NetCDF file `path`, or the only one in folder `path` (an extracted zip)
function _nc_file(path)
    isfile(path) && return path
    files = filter(endswith(".nc"), readdir(path; join=true))
    length(files) == 1 || error("expected one .nc file in $path, found $(length(files))")
    return files[1]
end

# Projected grid from axes in m, flipping a descending y axis.
function _proj_axes(x, y, proj)
    flip = y[2] < y[1]
    yc = flip ? reverse(y) : y
    return ProjGrid("native", Float64.(x) ./ 1000, Float64.(yc) ./ 1000, proj), flip
end

_read2d(v, flip) = flip ? reverse(v[:, :]; dims=2) : v[:, :]

"""
BedMachine Greenland/Antarctica: mask 0 ocean, 1 ice-free land, 2 grounded ice,
3 floating ice, and 4, taken as class `mask4`: Lake Vostok in Antarctica (grounded
ice), non-Greenland land in Greenland up to v5 (ice-free land).
"""
function read_bedmachine(path, proj, mask4)
    NCDataset(path) do ds
        grid, flip = _proj_axes(ds["x"][:], ds["y"][:], proj)
        mask = map(v -> v == 4 ? mask4 : Int8(v), _read2d(ds["mask"], flip))
        return (grid=grid,
                z_bed=_read2d(ds["bed"], flip),
                z_srf=_read2d(ds["surface"], flip),
                H_ice=_read2d(ds["thickness"], flip),
                mask=mask)
    end
end

"""
Bedmap3: mask 1 grounded ice, 2 transiently grounded ice shelf (taken as floating),
3 floating ice shelf, 4 rock, missing elsewhere. Missing mask with valid bed is
ocean, where surface and thickness are 0.
"""
function read_bedmap3(path)
    NCDataset(path) do ds
        grid, flip = _proj_axes(ds["x"][:], ds["y"][:], PS_SOUTH)
        z_bed = _read2d(ds["bed_topography"], flip)
        m = _read2d(ds["mask"], flip)
        ocean = ismissing.(m) .& .!ismissing.(z_bed)
        mask = map(m, ocean) do v, o
            o ? OCEAN : ismissing(v) ? missing : v == 1 ? GRND : v == 4 ? LAND : FLT
        end
        z_srf = _read2d(ds["surface_topography"], flip)
        H_ice = _read2d(ds["ice_thickness"], flip)
        z_srf[ocean] .= 0
        H_ice[ocean] .= 0
        return (grid=grid, z_bed=z_bed, z_srf=z_srf, H_ice=H_ice, mask=mask)
    end
end

"""
Bedmap2 (Fretwell et al., 2013): one GeoTIFF per field (datamanifest entries
`bedmap2_*`), 1 km. The ice mask is 0 for grounded ice (including rock outcrops),
1 for floating ice, and no data elsewhere; the rock mask is 0 on rock outcrops
(ice-free land). Cells without ice mask but with a valid bed are ocean, where
surface and thickness are 0. Heights are relative to the GL04C geoid. Lake Vostok
is grounded ice.
"""
function read_bedmap2(db)
    tif(field) = _read_tif(get_dataset_path(db, "bedmap2_$field"))
    x, y, z_bed = tif("bed")
    _, _, z_srf = tif("surface")
    _, _, H_ice = tif("thickness")
    _, _, ice = tif("icemask_grounded_and_shelves")
    _, _, rock = tif("rockmask")
    ocean = ismissing.(ice) .& .!ismissing.(z_bed)
    mask = map(ice, rock, ocean) do i, r, o
        o ? OCEAN : ismissing(i) ? missing : i == 1 ? FLT : ismissing(r) ? GRND : LAND
    end
    z_srf[ocean] .= 0
    H_ice[ocean] .= 0
    return (grid=ProjGrid("native", x, y, PS_SOUTH), z_bed=z_bed, z_srf=z_srf, H_ice=H_ice, mask=mask)
end

"""
    _read_tif(path) -> (xc, yc, A)

Cell centres (km, ascending) and band 1 of a north-up GeoTIFF on a projection in
metres, with `missing` for no data.
"""
function _read_tif(path)
    AG.read(path) do ds
        xc, yc, _ = _tif_axes(ds, path)
        b = AG.getband(ds, 1)
        A = reverse(AG.read(b); dims=2)
        nd = AG.getnodatavalue(b)
        return xc, yc, nd === nothing ? A : map(v -> v == nd ? missing : v, A)
    end
end

# Cell centres (km, ascending) and projection (km) of a north-up GeoTIFF in metres
_tif_axes(ds, path) = _tif_axes(_tif_header(ds, path))

function _tif_axes(h::NamedTuple)
    xc = (h.x0 .+ h.dx .* ((1:h.nx) .- 0.5)) ./ 1000
    yc = reverse(h.y0 .+ h.dy .* ((1:h.ny) .- 0.5)) ./ 1000
    return xc, yc, h.proj
end

# Origin and spacing (m), size, and projection (km) of a north-up GeoTIFF in metres
function _tif_header(ds, path)
    x0, dx, rx, y0, ry, dy = AG.getgeotransform(ds)
    (rx == 0 && ry == 0 && dy < 0) || error("$path: not a north-up grid")
    proj = AG.toPROJ4(AG.importWKT(AG.getproj(ds)))
    occursin("+units=m ", proj * " ") || error("$path: projection not in metres: $proj")
    proj = String(strip(replace(proj * " ", "+units=m " => "+units=km ")))
    return (x0=x0, dx=dx, y0=y0, dy=dy, nx=AG.width(ds), ny=AG.height(ds), proj=proj)
end

"""
GEBCO topography and bathymetry, used without ice: its sub-ice grid only has
ice thickness for the Greenland and Antarctic ice sheets, which the regional
sources cover. Bed elevation is the GEBCO elevation; cells at or below sea level are
ocean (surface elevation 0), and cells above are land.
"""
function read_gebco(path, dom::Domain)
    latmin, latmax = lat_bounds(dom.base)
    NCDataset(path) do ds
        lat = ds["lat"][:]
        j = findall(l -> latmin <= l <= latmax, lat)
        grid = LonLatGrid(ds["lon"][:], lat[j])
        z_bed = ds["elevation"][:, j]
        z_srf = max.(z_bed, Int16(0))
        H_ice = zeros(Float32, size(z_bed))
        mask = map(z -> z <= 0 ? OCEAN : LAND, z_bed)
        return (grid=grid, z_bed=z_bed, z_srf=z_srf, H_ice=H_ice, mask=mask)
    end
end

"""
    GlacierTiles(files, grids)

Glacier ice thickness as one GeoTIFF per glacier, each on its own projected grid
(`grids`, from the file headers), with the thickness (m) in band 1, NaN outside the
glacier, and the area (km2) and volume (km3) of the glacier in the metadata items
`area` and `volume`. The pixels touched by the outline count as glacier, so
neighbouring tiles overlap along their shared boundaries. Read one tile with
`read_tile`.
"""
struct GlacierTiles
    files::Vector{String}
    grids::Vector{ProjGrid}
end

"""
IceBoost v2.0 (Maffezzoli et al.) glacier ice thickness for RGI 7.0 outlines:
one GeoTIFF per glacier, 100 m (finer for small glaciers), in UTM. Uses the regions
listed in datamanifest.toml (`iceboost_v2_rgiNN`), which cover the NH domain except
Greenland (region 05), where BedMachine includes the peripheral glaciers (also from
IceBoost), and the PYR and SRG domains. Only the tiles within the latitudes of the
base grid of `dom` are kept (from the tile index, see `tile_index`), without reading
the tiles.
"""
function read_iceboost(db, dom::Domain)
    latmin, latmax = lat_bounds(dom.base)
    files, grids, ntiles = String[], ProjGrid[], 0
    for key in sort(filter(startswith("iceboost_v2_rgi"), collect(keys(db.datasets))))
        for t in tile_index(key, get_dataset_path(db, key))
            ntiles += 1
            (t.lat[1] <= latmax && t.lat[2] >= latmin) || continue
            push!(files, t.file)
            push!(grids, t.grid)
        end
    end
    ntiles > 0 || error("no IceBoost tiles found (run 00_sources.jl --download)")
    println("$(length(files)) of $ntiles IceBoost tiles within latitudes ",
            "$(round(latmin; digits=1)) to $(round(latmax; digits=1))")
    p = sortperm(files)
    return GlacierTiles(files[p], grids[p])
end

"""
    tile_index(key, dir) -> Vector{(file, grid, lat)}

Path, grid (see `read_tile`) and latitude range (see `lat_bounds`) of each glacier
tile in folder `dir` of dataset `key`, sorted by path. The index is kept in
\$FESMDATA_WORK/topo/tiles/<key>.tsv, and built from the file headers when it is
missing or lists other files than those in `dir`.
"""
function tile_index(key::AbstractString, dir::AbstractString)
    files = String[]
    for (root, _, fs) in walkdir(dir)
        append!(files, relpath.(joinpath.(root, filter(endswith(".tif"), fs)), dir))
    end
    sort!(files)
    path = joinpath(workdir(), "tiles", "$key.tsv")
    rows = isfile(path) ? _read_tile_index(path) : nothing
    if rows === nothing || first.(rows) != files
        rows = _tile_index_rows(dir, files)
        _write_tile_index(path, rows)
    end
    return [(file=joinpath(dir, f), grid=_tile_grid(basename(f), h), lat=lat) for (f, h, lat) in rows]
end

# (file, header, latitude range) of each tile, from its header (threaded); the
# latitude ranges on one thread (Proj transformations are not thread-safe)
function _tile_index_rows(dir, files)
    t0 = time()
    hdrs = Vector{Any}(undef, length(files))
    Threads.@threads :dynamic for k in eachindex(files)
        path = joinpath(dir, files[k])
        hdrs[k] = AG.read(ds -> _tif_header(ds, path), path)
    end
    lats = [lat_bounds(_tile_grid(basename(f), h)) for (f, h) in zip(files, hdrs)]
    println("Indexed $(length(files)) tiles in $dir: $(round(time() - t0; digits=1)) s")
    return [(f, h, lat) for (f, h, lat) in zip(files, hdrs, lats)]
end

const _TILE_INDEX_HEADER = "file\tx0\tdx\ty0\tdy\tnx\tny\tlatmin\tlatmax\tproj"

function _write_tile_index(path, rows)
    mkpath(dirname(path))
    tmp = "$path.$(getpid())"
    open(tmp, "w") do io
        println(io, _TILE_INDEX_HEADER)
        for (f, h, lat) in rows
            println(io, join((f, h.x0, h.dx, h.y0, h.dy, h.nx, h.ny, lat..., h.proj), '\t'))
        end
    end
    mv(tmp, path; force=true)  # atomic: jobs may build the same index at once
end

function _read_tile_index(path)
    lines = readlines(path)
    (isempty(lines) || lines[1] != _TILE_INDEX_HEADER) && return nothing
    return map(lines[2:end]) do line
        c = split(line, '\t')
        x0, dx, y0, dy, latmin, latmax = parse.(Float64, c[[2, 3, 4, 5, 8, 9]])
        h = (x0=x0, dx=dx, y0=y0, dy=dy, nx=parse(Int, c[6]), ny=parse(Int, c[7]), proj=String(c[10]))
        (String(c[1]), h, (latmin, latmax))
    end
end

# Grid of a glacier tile from its header. A grid needs two cells along each axis:
# single-cell axes get a second cell (NaN in `read_tile`).
function _tile_grid(name, h)
    xc, yc, proj = _tif_axes(h)
    h.nx == 1 && (xc = [xc[1], xc[1] + h.dx / 1000])
    h.ny == 1 && (yc = [yc[1], yc[1] - h.dy / 1000])
    return ProjGrid(name, xc, yc, proj)
end

"""
    read_tile(path) -> (grid, H, area, volume)

Grid (km, ascending axes), thickness (band 1), and glacier area (km2) and volume
(km3) of a glacier tile (see `GlacierTiles`), a north-up GeoTIFF on a projection in
metres.
"""
function read_tile(path::AbstractString)
    AG.read(path) do ds
        h = _tif_header(ds, path)
        H = reverse(AG.read(AG.getband(ds, 1)); dims=2)
        meta = Dict(Pair(split(m, "="; limit=2)...) for m in AG.metadata(ds))
        area, volume = parse(Float64, meta["area"]), parse(Float64, meta["volume"])
        # Pad single-cell axes with NaN (see `_tile_grid`)
        h.nx == 1 && (H = vcat(H, fill(eltype(H)(NaN), 1, size(H, 2))))
        h.ny == 1 && (H = hcat(H, fill(eltype(H)(NaN), size(H, 1), 1)))
        return _tile_grid(basename(path), h), H, area, volume
    end
end

"""
    DEMTiles(files, grids)

Land surface elevation as lon-lat tiles (`grids`, from the file headers), one GeoTIFF
each, with the elevation (m) in band 1 and 0 over the ocean. Read one tile with
`read_dem_tile`.
"""
struct DEMTiles
    files::Vector{String}
    grids::Vector{LonLatGrid}
end

"""
Copernicus DEMs (ESA, doi:10.5270/ESA-c5d3d65): surface elevation of the land (m above
the EGM2008 geoid), in 1-degree tiles from the public buckets of the AWS Open Data
programme, GLO-90 with a spacing of 3" in latitude and 3" to 30" in longitude (by
latitude), GLO-30 with 1" and 1" to 10". They are the edited TanDEM-X DEM (acquisitions
2011-2015), from the same acquisitions as the TanDEM-X EDEM from which IceBoost takes
its surface features. The ocean is 0 m, and there are no tiles over the open ocean.
Elevations at or below 0 m are taken as ocean, so land below sea level is ocean.

By source name: label, bucket and code of the spacing in the tile names (arc seconds
times 10).
"""
const COPERNICUS_DEMS = Dict(
    "copernicus_glo90" => (label="GLO-90", url="https://copernicus-dem-90m.s3.amazonaws.com", code="30"),
    "copernicus_glo30" => (label="GLO-30", url="https://copernicus-dem-30m.s3.amazonaws.com", code="10"),
)

# Name of the tile of Copernicus DEM `name` with its south-west corner at (lat, lon) (integers)
copdem_tile(name::AbstractString, lat::Integer, lon::Integer) =
    "Copernicus_DSM_COG_$(COPERNICUS_DEMS[name].code)_$(lat < 0 ? "S" : "N")$(lpad(abs(lat), 2, '0'))_00_" *
    "$(lon < 0 ? "W" : "E")$(lpad(abs(lon), 3, '0'))_00_DEM"

"""
    lonlat_extent(g) -> ((lonmin, lonmax), (latmin, latmax))

Longitudes and latitudes (degrees) covered by the projected grid `g`, from its outline
(latitudes as in `lat_bounds`, without margin). The grid must not cross the
antimeridian.
"""
function lonlat_extent(g::ProjGrid; npts::Integer=200)
    dx, dy = spacing(g)
    x0, x1 = g.xc[1] - dx / 2, g.xc[end] + dx / 2
    y0, y1 = g.yc[1] - dy / 2, g.yc[end] + dy / 2
    s = range(0, 1; length=npts)
    pts = vcat([(x0 + t * (x1 - x0), y) for t in s, y in (y0, y1)][:],
               [(x, y0 + t * (y1 - y0)) for t in s, x in (x0, x1)][:])
    trans = FesmUtils.Proj.Transformation(g.proj, "EPSG:4326"; always_xy=true)
    lon = first.(map(trans, pts))
    lonmin, lonmax = extrema(lon)
    lonmax - lonmin < 180 || error("grid $(g.name) crosses the antimeridian")
    return (lonmin, lonmax), lat_bounds(g; margin=0.0)
end

"""
    copdem_tiles(name, g, dir) -> Vector{String}

Names of the tiles of Copernicus DEM `name` over the lon-lat extent of the projected grid
`g` (or of the base grid of a domain, see `lonlat_extent`), of those listed in
`dir`/tileList.txt (the tiles that exist).
"""
copdem_tiles(name::AbstractString, dom::Domain, dir::AbstractString) = copdem_tiles(name, dom.base, dir)

function copdem_tiles(name::AbstractString, g::ProjGrid, dir::AbstractString)
    (lon0, lon1), (lat0, lat1) = lonlat_extent(g)
    listed = Set(readlines(joinpath(dir, "tileList.txt")))
    names = [copdem_tile(name, la, lo) for la in floor(Int, lat0):ceil(Int, lat1)-1
                                       for lo in floor(Int, lon0):ceil(Int, lon1)-1]
    return sort(filter(in(listed), names))
end

copdem_file(dir, tile) = joinpath(dir, "$tile.tif")

"""
    download_copdem(name, dir, dom) -> Int

Download the tiles of Copernicus DEM `name` over `dom` missing in `dir` (and the tile
list), on a machine with internet access. Returns the number of tiles of the domain.
"""
function download_copdem(name::AbstractString, dir::AbstractString, dom::Domain)
    (; label, url) = COPERNICUS_DEMS[name]
    mkpath(dir)
    list = joinpath(dir, "tileList.txt")
    isfile(list) || Downloads.download("$url/tileList.txt", list)
    tiles = copdem_tiles(name, dom, dir)
    missing_tiles = filter(t -> !isfile(copdem_file(dir, t)), tiles)
    println("$(dom.key): $(length(tiles)) $label tiles, downloading $(length(missing_tiles))")
    for t in missing_tiles
        tmp = copdem_file(dir, t) * ".part"
        Downloads.download("$url/$t/$t.tif", tmp)
        mv(tmp, copdem_file(dir, t); force=true)
    end
    return length(tiles)
end

"""
Tiles of Copernicus DEM `name` over the base grid of `dom` (see `copdem_tiles`), or over
the projected grid `g`, which must all have been downloaded (00_sources.jl --download,
for the domain with key `key`).
"""
read_copdem(db, name::AbstractString, dom::Domain) = read_copdem(db, name, dom.base, dom.key)

function read_copdem(db, name::AbstractString, g::ProjGrid, key::AbstractString)
    label = COPERNICUS_DEMS[name].label
    dir = get_dataset_path(db, name)
    isfile(joinpath(dir, "tileList.txt")) || error("no $label tile list in $dir (run 00_sources.jl --download)")
    tiles = copdem_tiles(name, g, dir)
    files = copdem_file.(dir, tiles)
    absent = filter(!isfile, files)
    isempty(absent) || error("$(length(absent)) of $(length(files)) $label tiles over $(g.name) missing in $dir " *
                             "(run 00_sources.jl --download $key)")
    grids = Vector{LonLatGrid}(undef, length(files))
    Threads.@threads :dynamic for k in eachindex(files)
        grids[k] = AG.read(ds -> _lonlat_tif_grid(ds, files[k]), files[k])
    end
    println("$(length(files)) $label tiles over $(g.name)")
    return DEMTiles(files, grids)
end

# Lon-lat grid (ascending latitudes) of a north-up GeoTIFF in degrees
function _lonlat_tif_grid(ds, path)
    x0, dx, rx, y0, ry, dy = AG.getgeotransform(ds)
    (rx == 0 && ry == 0 && dy < 0) || error("$path: not a north-up grid")
    lon = x0 .+ dx .* ((1:AG.width(ds)) .- 0.5)
    lat = reverse(y0 .+ dy .* ((1:AG.height(ds)) .- 0.5))
    return LonLatGrid(lon, lat; name=basename(path))
end

"""
    read_dem_tile(path) -> (grid, z)

Lon-lat grid and elevation (band 1, rows in ascending latitude) of a DEM tile.
"""
function read_dem_tile(path::AbstractString)
    AG.read(path) do ds
        return _lonlat_tif_grid(ds, path), reverse(AG.read(AG.getband(ds, 1)); dims=2)
    end
end

# ---------------------------------------------------------------------------
# Drang Drung Glacier (Sommers, 2025)
# ---------------------------------------------------------------------------

"UTM zone 43N (EPSG:32643) in km."
const UTM43N = "+proj=tmerc +lat_0=0 +lon_0=75 +k=0.9996 +x_0=500000 +y_0=0 +a=6378137 +rf=298.257223563 +units=km"

"""
Drang Drung Glacier, Zanskar (Sommers, 2025, doi:10.5281/zenodo.17593643, CC BY 4.0):
the data of an ISSM model setup, in UTM zone 43N (EPSG:32643, as MATLAB files with
axes `x`, `y` in m, rows in descending `y`).

- Surface: the 2 m DEM of LEGOS and OMP (2025), in heights above the WGS84 ellipsoid,
  converted to heights above the EGM2008 geoid (as GLO-90 and GEBCO) at each point
  with PROJ and the EGM2008 grid (`egm2008_geoid`, see `ellipsoid_to_egm2008!`). Its
  voids (NaN, 29% of the grid, mostly on ice-free slopes) are filled with the GLO-30
  surface, interpolated bilinearly.
- Ice thickness: Millan et al. (2022), 50 m, for all glaciers in a 25 x 25 km box (0
  off the ice), taken at each DEM point from the cell that contains it.

The source is the DEM grid within the box of the thickness (where both are given),
without missing values: bed elevation is surface minus thickness, grounded ice where
the thickness is positive, and ice-free land elsewhere.
"""
function read_sommers2025(db, dom::Domain)
    gd, zs = _read_mat_grid(get_dataset_path(db, "sommers2025_drangdrung_dem"), "zs")
    gh, H = _read_mat_grid(get_dataset_path(db, "sommers2025_drangdrung_thickness"), "H")

    # DEM grid within the box of the thickness
    dxh, dyh = spacing(gh)
    ix = findall(x -> gh.xc[1] - dxh / 2 <= x <= gh.xc[end] + dxh / 2, gd.xc)
    iy = findall(y -> gh.yc[1] - dyh / 2 <= y <= gh.yc[end] + dyh / 2, gd.yc)
    grid = ProjGrid("sommers2025_drangdrung", gd.xc[ix], gd.yc[iy], UTM43N)
    z_srf = Float32.(view(zs, ix, iy))
    zs = nothing
    nvoid = count(isnan, z_srf)
    println("Sommers (2025) DEM within the thickness box: $(size(grid)) points, ",
            "$(round(100 * nvoid / length(z_srf); digits=1))% voids")

    # Ellipsoidal heights to EGM2008, then voids from GLO-30
    N = ellipsoid_to_egm2008!(z_srf, grid, get_dataset_path(db, "egm2008_geoid"))
    println("EGM2008 geoid height over the DEM: $(round.(N; digits=2)) m")
    glo = read_copdem(db, "copernicus_glo30", grid, dom.key)
    for (file, g) in zip(glo.files, glo.grids)
        _, z = read_dem_tile(file)
        zg, fv = remap_bilinear(grid, g, z)
        Threads.@threads for j in axes(z_srf, 2)
            @inbounds for i in axes(z_srf, 1)
                isnan(z_srf[i, j]) && fv[i, j] > 0 && (z_srf[i, j] = Float32(zg[i, j]))
            end
        end
    end
    left = count(isnan, z_srf)
    left == 0 || error("$left voids of the Sommers (2025) DEM not covered by GLO-30")

    # Thickness of the cell containing each point (all points are inside the box)
    nxh, nyh = size(gh)
    ih = [clamp(floor(Int, (x - gh.xc[1]) / dxh + 0.5) + 1, 1, nxh) for x in grid.xc]
    jh = [clamp(floor(Int, (y - gh.yc[1]) / dyh + 0.5) + 1, 1, nyh) for y in grid.yc]
    H_ice = Float32.(H[ih, jh])
    z_bed = z_srf .- H_ice
    mask = map(h -> h > 0 ? GRND : LAND, H_ice)
    return (grid=grid, z_bed=z_bed, z_srf=z_srf, H_ice=H_ice, mask=mask)
end

"""
    _read_mat_grid(path, var) -> (grid, A)

Grid (UTM 43N, km, ascending axes) and field `var` (columns of x, rows of ascending y)
of a MATLAB file with axes `x`, `y` (m) and `var` with rows of `y`.
"""
function _read_mat_grid(path, var)
    d = matread(path)
    x, y = vec(d["x"]) ./ 1000, vec(d["y"]) ./ 1000
    A = permutedims(d[var])
    if y[2] < y[1]
        y = reverse(y)
        A = reverse(A; dims=2)
    end
    return ProjGrid("native", x, y, UTM43N), A
end

"""
    ellipsoid_to_egm2008!(z, grid, geoid) -> (Nmin, Nmax)

Convert the heights `z` (m above the WGS84 ellipsoid, NaN kept) on the projected grid
`grid` to heights above the EGM2008 geoid, at each point, with a PROJ pipeline using
the geoid grid file `geoid` (us_nga_egm08_25.tif of the PROJ data; no network access
needed). Threaded over rows, with one transformation per task. Returns the range of
the geoid height N (height = ellipsoidal height - N).
"""
function ellipsoid_to_egm2008!(z::AbstractMatrix{<:AbstractFloat}, grid::ProjGrid, geoid::AbstractString)
    isfile(geoid) || error("no EGM2008 geoid grid at $geoid (run 00_sources.jl --download)")
    # Inverse projection to geographic coordinates (radians), then the vertical shift
    # h - N, with N the geoid height of the grid
    pipeline = "+proj=pipeline +step +inv $(replace(grid.proj, "+units=km" => "+units=m")) " *
               "+step +proj=vgridshift +grids=$geoid +multiplier=-1"
    P = FesmUtils.Proj
    nrows = size(z, 2)
    chunks = collect(Iterators.partition(1:nrows, cld(nrows, 4 * Threads.nthreads())))
    ranges = Vector{NTuple{2,Float64}}(undef, length(chunks))
    Threads.@threads :dynamic for k in eachindex(chunks)
        trans = P.Transformation(pipeline; ctx=P.proj_context_create())
        lo, hi = Inf, -Inf
        for j in chunks[k], i in axes(z, 1)
            isnan(z[i, j]) && continue
            h = Float64(z[i, j])
            _, _, H = trans((grid.xc[i] * 1000, grid.yc[j] * 1000, h))
            isfinite(H) || error("no geoid height at $(grid.xc[i]), $(grid.yc[j]) km")
            z[i, j] = H
            lo, hi = min(lo, h - H), max(hi, h - H)
        end
        ranges[k] = (lo, hi)
    end
    return minimum(first.(ranges)), maximum(last.(ranges))
end
