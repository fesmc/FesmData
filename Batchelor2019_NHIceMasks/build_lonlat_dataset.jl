#
# Build the regular lon/lat ice-mask dataset from the Batchelor et al. (2019)
# shapefiles. This produces `Batchelor2019_ice_masks.nc`, which is both a
# usable input dataset on its own and the prerequisite for
# `build_projected_dataset.jl`.
#
# Configure the source directory and resolution below, then run:
#
#     julia --project=. build_lonlat_dataset.jl
#
cd(@__DIR__)
import Pkg; Pkg.activate(".")

using GeoDataFrames
using Rasters
using NCDatasets

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Source shapefile directory.
const SRC = "Batchelor2019_NHextent"

# Output lon/lat resolution in degrees.
const RES = 0.5

# Output file.
const PATH_OUT = "Batchelor2019_ice_masks.nc"

const SOURCE_ATTR = "Batchelor et al. (2019) https://www.nature.com/articles/s41467-019-11601-2"

# Time slices available in the dataset: 18 snapshots, oldest to youngest,
# matching the subfolder names in the source shapefile directory.
const TIME_LABELS = [
    "Early Matuyama Chron",
    "Late Gauss Chron",
    "MIS 20-24",
    "MIS 16",
    "MIS 12",
    "MIS 10",
    "MIS 8",
    "MIS 6",
    "MIS 5d",
    "MIS 5c",
    "MIS 5b",
    "MIS 5a",
    "MIS 4",
    "45 ka",
    "40 ka",
    "35 ka",
    "30 ka",
    "LGM",
]

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

"""
Rasterize the Batchelor shapefiles onto a regular lon/lat grid and write all
time slices to a CF-compliant NetCDF file.

All slices except the LGM are defined on a projected grid in the source data,
so they are first rasterized onto an intermediate Lambert azimuthal equal-area
(laea) grid and then resampled to lon/lat. The LGM is already on lon/lat and is
rasterized directly.
"""
function build_lonlat_dataset(; src=SRC, res=RES, path_out=PATH_OUT)

    # Output lon/lat grid
    lon = -180:res:180
    lat = 0:res:90

    nx = length(lon)
    ny = length(lat)
    nt = length(TIME_LABELS)

    # Target lon/lat raster
    r = Rasters.Raster(zeros(nx, ny); dims=(X(lon), Y(lat)))
    r = Rasters.setcrs(r, EPSG(4326))

    # Intermediate laea raster (used for the projected source slices)
    crs = ProjString("+proj=laea +lat_0=90 +lon_0=0 +x_0=0 +y_0=0 +units=m +datum=WGS84")
    xy = range(-9e6, 9e6, step=100e3)
    rxy = Rasters.Raster(zeros(length(xy), length(xy)); dims=(X(xy), Y(xy)))
    rxy = Rasters.setcrs(rxy, crs)

    isfile(path_out) && rm(path_out)
    ds = NCDataset(path_out, "c")
    try
        ds.attrib["source"] = SOURCE_ATTR

        defDim(ds, "lon", nx)
        defDim(ds, "lat", ny)
        defDim(ds, "time", nt)

        lon_var = defVar(ds, "lon", Float32, ("lon",), attrib = Dict(
            "standard_name" => "longitude",
            "long_name"     => "longitude",
            "units"         => "degrees_east",
            "axis"          => "X"
        ))
        lon_var[:] = lon

        lat_var = defVar(ds, "lat", Float32, ("lat",), attrib = Dict(
            "standard_name" => "latitude",
            "long_name"     => "latitude",
            "units"         => "degrees_north",
            "axis"          => "Y"
        ))
        lat_var[:] = lat

        timevar = defVar(ds, "time", Float32, ("time",))
        timevar[:] = 1:nt

        timelabelvar = defVar(ds, "label", String, ("time",))
        timelabelvar[:] = TIME_LABELS

        maskvar = defVar(ds, "mask", Int8, ("lon","lat","time"))
        maskvar.attrib["long_name"] = "Ice mask (1=ice,0=no ice)"

        for k in 1:nt
            # Read shapefile and convert to raster grid
            dir = "$(src)/$(TIME_LABELS[k])/hypothesised ice-sheet reconstructions/"
            filename = filter(f -> endswith(f, "_best_estimate.shp"), readdir(dir))[1]
            shp = GeoDataFrames.read(joinpath(dir, filename))

            if k < nt
                mask_xy = Rasters.rasterize(last, shp, fill=1, to=rxy)
                mask = Rasters.resample(mask_xy; to=r, method=:mode)
            else
                mask = Rasters.rasterize(last, shp, fill=1, to=r)
            end

            Rasters.replace_missing!(mask, 0)
            maskvar[:, :, k] = mask

            println("  lon/lat slice $(k)/$(nt): $(TIME_LABELS[k])")
        end
    finally
        close(ds)
    end

    println("Wrote ", path_out)
    return path_out
end

build_lonlat_dataset()
