# Prepare the radiostratigraphy of the Greenland Ice Sheet (RRRAG4 v2, MacGregor et al.)
# for remapping: the 5 km grid of the original file as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/MacGregor2025_strat/MacGregor2025_STRAT.nc, with the age of
# the ice at normalized depths (x, y, depth_norm) and the depth of isochrones (x, y, age),
# and their uncertainties.
#
# Usage:
#     julia --project=MacGregor2025_strat MacGregor2025_strat/prepare.jl

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))

const PROJ = "+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

input = get_dataset_path(manifest(), "rrrag4_v2")

# Fields: name, source name, extra dimension (depth_norm or age), units, long name
const FIELDS = [
    ("ice_age", "age_norm", "depth_norm", "ka", "age of ice at normalized depth"),
    ("ice_age_sd", "age_std", "depth_norm", "ka", "uncertainty (total) of the age of ice at normalized depth"),
    ("depth_iso", "depth_iso", "age", "m", "depth of isochrone below ice surface"),
    ("depth_iso_sd", "depth_std", "age", "m", "uncertainty (total) of the depth of isochrone below ice surface"),
]

path = joinpath(prepared_dir("MacGregor2025_strat"), "MacGregor2025_STRAT.nc")
mkpath(dirname(path))
NCDataset(input) do src
    x = Float64.(src["x"][:])
    y = Float64.(src["y"][:])
    jy = sortperm(y)                                   # y is descending in the source
    depth_norm = src["depth_norm"][:] ./ 100          # % -> fraction of ice thickness
    age = src["age_iso"][:]

    NCDataset(path, "c") do ds
        defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
        defVar(ds, "y", y[jy], ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
        defVar(ds, "depth_norm", depth_norm, ("depth_norm",);
               attrib=["units" => "1", "long_name" => "depth below ice surface as a fraction of ice thickness",
                       "positive" => "down"])
        defVar(ds, "age", age, ("age",); attrib=["units" => "ka", "long_name" => "age of isochrone"])
        defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic",
                                                 "proj_params" => PROJ, "epsg_code" => "EPSG:3413"])
        for (name, srcname, zdim, units, long_name) in FIELDS
            A = src[srcname]                             # Julia order (x, y, depth_norm|age)
            F = Float32.(coalesce.(A[:, jy, :], NaN))
            defVar(ds, name, F, ("x", "y", zdim); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => units, "long_name" => long_name, "grid_mapping" => "crs"])
        end
        ds.attrib["title"] = "Radiostratigraphy and age structure of the Greenland Ice Sheet, version 2 (RRRAG4 v2)"
        ds.attrib["references"] = "MacGregor, J. A., Fahnestock, M. A., Paden, J. D., Li, J., Harbeck, J. P., " *
                                  "and Aschwanden, A.: A revised and expanded deep radiostratigraphy of the " *
                                  "Greenland Ice Sheet from airborne radar sounding surveys between 1993 and " *
                                  "2019, Earth Syst. Sci. Data, 17, 2911-2931, 2025, doi:10.5194/essd-17-2911-2025; " *
                                  "data: RRRAG4 v2, NASA NSIDC DAAC, doi:10.5067/SZSVA3CWV3U4"
        ds.attrib["doi"] = "10.5067/SZSVA3CWV3U4"
        ds.attrib["license"] = "CC BY 4.0 (NASA open data, cite the data set)"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("stratigraphy"))
    end
end
println("Wrote $path")
