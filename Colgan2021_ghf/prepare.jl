# Prepare the Colgan & Wansing (2021) geothermal heat flow of Greenland for remapping:
# the equal-area points of geothermal_heat_flow_from_machinelearning.xyz (GEUS
# Dataverse, datamanifest key colgan2021_ghf) on a regular lon-lat grid, written to
# $FESMDATA_WORK/prepared/Colgan2021_ghf/Colgan2021_GHF.nc with ghf, ghf_min, ghf_max.
#
# Usage:
#     julia --project=Colgan2021_ghf Colgan2021_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Colgan2021_ghf/Colgan2021_GHF.nc Greenland

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "ringgrid.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

"Longitude spacing (degrees) of the regular grid the equal-area cells are put on."
const DLON = 0.1

# Columns: lon, lat, mean GHF (also offshore), minimum GHF, maximum GHF (onshore), in mW/m2
input = download_dataset(manifest(), "colgan2021_ghf")
data = readdlm(input; comments=true, comment_char='%')
lon, lat = Float64.(data[:, 1]), Float64.(data[:, 2])
lons, lats, (ghf, ghf_min, ghf_max) = ring_grid(lon, lat, (data[:, 3], data[:, 4], data[:, 5]); dlon=DLON)

path = joinpath(prepared_dir("Colgan2021_ghf"), "Colgan2021_GHF.nc")
mkpath(dirname(path))
isfile(path) && rm(path)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lons, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lats, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, F, long_name) in (("ghf", ghf, "geothermal heat flow"),
                                 ("ghf_min", ghf_min, "minimum geothermal heat flow of the model ensemble"),
                                 ("ghf_max", ghf_max, "maximum geothermal heat flow of the model ensemble"))
        defVar(ds, name, F, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "mW m-2", "long_name" => long_name])
    end
    ds.attrib["title"] = "Geothermal heat flow of Greenland (Colgan and Wansing, 2021)"
    ds.attrib["references"] = "Colgan, W. et al.: Greenland Geothermal Heat Flow Database and Map " *
                              "(Version 1), Earth Syst. Sci. Data, 14, 2209-2238, 2022, " *
                              "doi:10.5194/essd-14-2209-2022; data: Colgan, W. and Wansing, A.: Greenland " *
                              "Geothermal Heat Flow Database and Map, GEUS Dataverse, V2.1, 2021, " *
                              "doi:10.22008/FK2/F9P03L (geothermal_heat_flow_from_machinelearning.xyz)"
    ds.attrib["doi"] = "10.22008/FK2/F9P03L"
    ds.attrib["license"] = "CC0 1.0"
    ds.attrib["comment"] = "Equal-area points (0.5° in latitude, about 55 km) on a regular lon-lat grid: " *
                           "each cell has the value of the nearest point of its latitude ring. " *
                           "Model without the NGRIP basal heat flow (as in ISMIP7)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
