# Prepare the Antarctic upper-mantle viscosity of Wiens et al. (2022) for remapping: the
# viscosity at 100, 200 and 300 km depth on its 40 km polar stereographic grid, from the
# isostasy_data archive (datamanifest key isostasy_data_v0_2), as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/Wiens2022_visc/Wiens2022_visc.nc, with log10_visc (on depth).
#
# Usage:
#     julia --project=Wiens2022_visc Wiens2022_visc/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Wiens2022_visc/Wiens2022_visc.nc Antarctica

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "isostasy_data_v0_2"
# Not given in the file: assumed to be the usual Antarctic polar stereographic
# projection (EPSG:3031), as used by FastIsostasy with this file
const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m"

db = manifest()
dir = get_dataset_path(db, KEY)
isdir(dir) || (dir = download_dataset(db, KEY))
root = joinpath(dir, only(filter(startswith("JanJereczek-isostasy_data"), readdir(dir))))

# log10visc (x, y, z) in Julia order, x and y in m, z the depth in m (100, 200, 300 km),
# log10 of the viscosity in Pa s (units "Pascal seconds"), NaN outside the model
x, y, z, V = NCDataset(joinpath(root, "earth_structure", "viscosity", "wiens2022.nc")) do ds
    Float64.(ds["x"][:]), Float64.(ds["y"][:]), Float64.(ds["z"][:]), Float32.(ds["log10visc"].var[:, :, :])
end
(issorted(x) && issorted(y) && issorted(z)) || error("wiens2022.nc: coordinates not ascending")

path = joinpath(prepared_dir("Wiens2022_visc"), "Wiens2022_visc.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "depth", z, ("depth",);
           attrib=["units" => "m", "standard_name" => "depth", "positive" => "down",
                   "long_name" => "depth below the surface"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic",
                                            "straight_vertical_longitude_from_pole" => 0.0,
                                            "latitude_of_projection_origin" => -90.0,
                                            "standard_parallel" => -71.0,
                                            "proj_params" => PROJ])
    defVar(ds, "log10_visc", V, ("x", "y", "depth"); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "log10(Pa s)", "long_name" => "log10 of upper-mantle viscosity in Pa s",
                   "grid_mapping" => "crs"])
    ds.attrib["title"] = "Antarctic upper-mantle viscosity at 100, 200 and 300 km depth (Wiens et al., 2022)"
    ds.attrib["references"] = "Wiens, D. A., Shen, W. and Lloyd, A. J.: The seismic structure of the " *
                              "Antarctic upper mantle, Geol. Soc. London Mem., 56, 195-212, 2023, " *
                              "doi:10.1144/M56-2020-18; Ivins, E. R., van der Wal, W., Wiens, D. A., " *
                              "Lloyd, A. J. and Caron, L.: Antarctic upper mantle rheology, Geol. Soc. " *
                              "London Mem., 56, 267-294, 2023, doi:10.1144/M56-2020-19; file from " *
                              "isostasy_data v0.2.0 (Swierczek-Jereczek, 2024), doi:10.5281/zenodo.11175418"
    ds.attrib["doi"] = "10.1144/M56-2020-18"
    ds.attrib["license"] = "No licence stated: not published by the authors, provided by D. A. Wiens for " *
                           "isostasy_data (archived under CC BY 4.0, doi:10.5281/zenodo.11175418); " *
                           "cite Wiens et al. (2022) and Ivins et al. (2022)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("solidearth"))
end
println("Wrote $path")
