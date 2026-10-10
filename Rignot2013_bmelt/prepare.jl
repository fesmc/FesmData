# Prepare the Antarctic ice-shelf basal melt rates of Rignot et al. (2013) for remapping:
# the 1 km grid of Ant_MeltingRate.v2.nc (Dryad) as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/Rignot2013_bmelt/Rignot2013_BMELT.nc, with the actual and
# steady-state melt rates in m/yr ice equivalent (positive for melting).
#
# Usage:
#     julia --project=Rignot2013_bmelt Rignot2013_bmelt/prepare.jl

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))

const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

# The melt rates of the file are in m/yr water equivalent (see README): converted to
# ice equivalent with the densities used by Rignot et al. (2013)
const RHO_W = 1000.0
const RHO_I = 917.0

# Fields: name, source name, long name
const FIELDS = [
    ("bmelt", "melt_actual", "basal melt rate of ice shelves, 2007-2008 (positive for melting)"),
    ("bmelt_ss", "melt_steadystate", "steady-state basal melt rate of ice shelves (no thickness change; positive for melting)"),
]

input = get_dataset_path(manifest(), "rignot2013_melt_v2")

path = joinpath(prepared_dir("Rignot2013_bmelt"), "Rignot2013_BMELT.nc")
mkpath(dirname(path))
NCDataset(input) do src
    x = Float64.(src["xaxis"][:])
    y = Float64.(src["yaxis"][:])
    ix, jy = sortperm(x), sortperm(y)                  # y is descending in the source

    NCDataset(path, "c") do ds
        defVar(ds, "x", x[ix], ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
        defVar(ds, "y", y[jy], ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
        defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic",
                                                 "proj_params" => PROJ, "epsg_code" => "EPSG:3031"])
        for (name, srcname, long_name) in FIELDS
            A = Float64.(coalesce.(src[srcname][ix, jy], NaN))    # Julia order (x, y)
            # 0 outside the ice shelves (no data)
            F = Float32[a == 0 || !isfinite(a) ? NaN : a * RHO_W / RHO_I for a in A]
            defVar(ds, name, F, ("x", "y"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => "m yr-1", "long_name" => long_name * ", ice equivalent",
                           "grid_mapping" => "crs"])
        end
        ds.attrib["title"] = "Basal melt rates of Antarctic ice shelves (Rignot et al., 2013)"
        ds.attrib["references"] = "Rignot, E., Jacobs, S., Mouginot, J., and Scheuchl, B.: Ice-shelf melting " *
                                  "around Antarctica, Science, 341, 266-270, 2013, doi:10.1126/science.1235798; " *
                                  "data: Dryad, doi:10.5061/dryad.5hqbzkhg2"
        ds.attrib["doi"] = "10.5061/dryad.5hqbzkhg2"
        ds.attrib["license"] = "CC0 1.0"
        ds.attrib["comment"] = "Melt rates converted from water to ice equivalent (x $RHO_W / $RHO_I); " *
                               "cells with 0 in the original file (outside the ice shelves) are missing"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("basalmelt"))
    end
end
println("Wrote $path")
