# Readers of the original datasets. Each returns the fields on the native grid of
# the source, with ascending axes:
#
#     (grid, z_bed, z_srf, H_ice, mask)
#
# where `grid` is a ProjGrid or LonLatGrid, and `mask` uses the classes below
# (`missing` where the source has no data).

using NCDatasets

const OCEAN = Int8(0)
const LAND  = Int8(1)
const GRND  = Int8(2)
const FLT   = Int8(3)
const MASK_CLASSES = (OCEAN, LAND, GRND, FLT)

const PS_NORTH = polar_stereographic_proj(lat_0=90, lat_ts=70, lon_0=-45, a=6378137, rf=298.257223563)
const PS_SOUTH = polar_stereographic_proj(lat_0=-90, lat_ts=-71, lon_0=0, a=6378137, rf=298.257223563)

"""
    read_source(name, dom) -> (grid, z_bed, z_srf, H_ice, mask)

Read source `name` (a key of datamanifest.toml, or "gebco2025") for domain `dom`.
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
        return read_gebco(_only_nc(get_dataset_path(db, "gebco2025.zip")),
                          _only_nc(get_dataset_path(db, "gebco2025_sub_ice.zip")), dom)
    end
    error("unknown source $name")
end

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
GEBCO 2025: ice surface elevation and sub-ice topography. Ice thickness is their
difference, which is only non-zero for the Greenland and Antarctic ice sheets.
Cells with ice are grounded or floating by flotation; ice-free cells are ocean at or
below sea level (surface elevation 0) and land above.
"""
function read_gebco(path_srf, path_bed, dom::Domain)
    latmin, latmax = lat_bounds(dom.base)
    r = dom.rho_ice / dom.rho_sw
    ds = NCDataset(path_srf)
    db = NCDataset(path_bed)
    lat = ds["lat"][:]
    j = findall(l -> latmin <= l <= latmax, lat)
    grid = LonLatGrid(ds["lon"][:], lat[j])
    z_srf = ds["elevation"][:, j]
    z_bed = db["elevation"][:, j]
    close(ds); close(db)

    H_ice = Matrix{Float32}(undef, size(z_srf))
    mask = Matrix{Int8}(undef, size(z_srf))
    Threads.@threads for jj in axes(z_srf, 2)
        @inbounds for i in axes(z_srf, 1)
            H = max(Float32(z_srf[i, jj]) - Float32(z_bed[i, jj]), 0f0)
            H_ice[i, jj] = H
            mask[i, jj] = H > 0 ? (z_bed[i, jj] + H * r < 0 ? FLT : GRND) :
                          z_srf[i, jj] <= 0 ? OCEAN : LAND
            # Surface of the ocean is sea level, not the sea floor
            mask[i, jj] == OCEAN && (z_srf[i, jj] = 0)
        end
    end
    return (grid=grid, z_bed=z_bed, z_srf=z_srf, H_ice=H_ice, mask=mask)
end
