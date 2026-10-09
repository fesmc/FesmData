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

using NCDatasets
import ArchGDAL as AG

const OCEAN = Int8(0)
const LAND  = Int8(1)
const GRND  = Int8(2)
const FLT   = Int8(3)
const MASK_CLASSES = (OCEAN, LAND, GRND, FLT)

const PS_NORTH = polar_stereographic_proj(lat_0=90, lat_ts=70, lon_0=-45, a=6378137, rf=298.257223563)
const PS_SOUTH = polar_stereographic_proj(lat_0=-90, lat_ts=-71, lon_0=0, a=6378137, rf=298.257223563)

"""
    read_source(name, dom) -> (grid, z_bed, z_srf, H_ice, mask)

Read source `name` (an entry of datamanifest.toml) for domain `dom`.
Lon-lat sources are read only over the latitudes covered by its base grid.
"""
function read_source(name::AbstractString, dom::Domain)
    db = manifest()
    if name == "bedmachine_greenland_v6"
        return read_bedmachine(get_dataset_path(db, name), PS_NORTH)
    elseif name == "bedmachine_antarctica_v4"
        return read_bedmachine(get_dataset_path(db, name), PS_SOUTH)
    elseif name == "bedmap3"
        return read_bedmap3(get_dataset_path(db, name))
    elseif name == "gebco2025"
        return read_gebco(_only_nc(get_dataset_path(db, "gebco2025")), dom)
    elseif name == "iceboost_v2"
        return read_iceboost(db)
    end
    error("unknown source $name")
end

"True for sources that only give glacier ice thickness (see `GlacierTiles`)."
is_thickness_source(name::AbstractString) = name == "iceboost_v2"

function _only_nc(dir)
    files = filter(endswith(".nc"), readdir(dir; join=true))
    length(files) == 1 || error("expected one .nc file in $dir, found $(length(files))")
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
3 floating ice, 4 Lake Vostok (taken as grounded ice).
"""
function read_bedmachine(path, proj)
    NCDataset(path) do ds
        grid, flip = _proj_axes(ds["x"][:], ds["y"][:], proj)
        mask = map(v -> v == 4 ? GRND : Int8(v), _read2d(ds["mask"], flip))
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
GEBCO 2025 topography and bathymetry, used without ice: its sub-ice grid only has
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
    GlacierTiles(files)

Glacier ice thickness as one GeoTIFF per glacier, each on its own projected grid,
with the thickness (m) in band 1, NaN outside the glacier, and the area (km2) and
volume (km3) of the glacier in the metadata items `area` and `volume`. The pixels
touched by the outline count as glacier, so neighbouring tiles overlap along their
shared boundaries. Read one tile with `read_tile`.
"""
struct GlacierTiles
    files::Vector{String}
end

"""
IceBoost v2.0 (Maffezzoli et al.) glacier ice thickness for RGI 7.0 outlines:
one GeoTIFF per glacier, 100 m (finer for small glaciers), in UTM. Uses the regions
listed in datamanifest.toml (`iceboost_v2_rgiNN`), which cover the NH domain except
Greenland (region 05), where BedMachine includes the peripheral glaciers (also from
IceBoost).
"""
function read_iceboost(db)
    files = String[]
    for key in sort(filter(startswith("iceboost_v2_rgi"), collect(keys(db.datasets))))
        for (root, _, fs) in walkdir(get_dataset_path(db, key))
            append!(files, joinpath.(root, filter(endswith(".tif"), fs)))
        end
    end
    isempty(files) && error("no IceBoost tiles found (run 00_sources.jl --download)")
    return GlacierTiles(sort(files))
end

"""
    read_tile(path) -> (grid, H, area, volume)

Grid (km, ascending axes), thickness (band 1), and glacier area (km2) and volume
(km3) of a glacier tile (see `GlacierTiles`), a north-up GeoTIFF on a projection in
metres.
"""
function read_tile(path::AbstractString)
    AG.read(path) do ds
        x0, dx, rx, y0, ry, dy = AG.getgeotransform(ds)
        (rx == 0 && ry == 0 && dy < 0) || error("$path: not a north-up grid")
        proj = AG.toPROJ4(AG.importWKT(AG.getproj(ds)))
        occursin("+units=m ", proj * " ") || error("$path: projection not in metres: $proj")
        proj = replace(proj * " ", "+units=m " => "+units=km ") |> strip
        nx, ny = AG.width(ds), AG.height(ds)
        xc = (x0 .+ dx .* ((1:nx) .- 0.5)) ./ 1000
        yc = reverse(y0 .+ dy .* ((1:ny) .- 0.5)) ./ 1000
        H = reverse(AG.read(AG.getband(ds, 1)); dims=2)
        meta = Dict(Pair(split(m, "="; limit=2)...) for m in AG.metadata(ds))
        area, volume = parse(Float64, meta["area"]), parse(Float64, meta["volume"])
        # A grid needs two cells along each axis: pad single-cell tiles with NaN
        if nx == 1
            xc = [xc[1], xc[1] + dx / 1000]
            H = vcat(H, fill(eltype(H)(NaN), 1, size(H, 2)))
        end
        if ny == 1
            yc = [yc[1], yc[1] - dy / 1000]
            H = hcat(H, fill(eltype(H)(NaN), size(H, 1), 1))
        end
        return ProjGrid(basename(path), xc, yc, proj), H, area, volume
    end
end
