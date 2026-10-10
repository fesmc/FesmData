# Prepare the Lösing & Ebbing (2021) geothermal heat flow of Antarctica for remapping:
# the equal-area points of HF_Min_Max_MaxAbs-1.csv (PANGAEA, datamanifest key
# loesing2021_ghf) on a regular lon-lat grid, written to
# $FESMDATA_WORK/prepared/Loesing2021_ghf/Loesing2021_GHF.nc with ghf, ghf_min, ghf_max.
#
# Usage:
#     julia --project=Loesing2021_ghf Loesing2021_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Loesing2021_ghf/Loesing2021_GHF.nc Antarctica

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "ringgrid.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

"Longitude spacing (degrees) of the regular grid the equal-area cells are put on."
const DLON = 0.1

# Columns: Lon, Lat, HF, HF_min, HF_max, HF_max_abs (= HF_max - HF_min), in mW/m2
input = download_dataset(manifest(), "loesing2021_ghf")
data = readdlm(input, ','; skipstart=1)
lon, lat = Float64.(data[:, 1]), Float64.(data[:, 2])
lons, lats, (ghf, ghf_min, ghf_max) = ring_grid(lon, lat, (data[:, 3], data[:, 4], data[:, 5]); dlon=DLON)

path = joinpath(prepared_dir("Loesing2021_ghf"), "Loesing2021_GHF.nc")
mkpath(dirname(path))
isfile(path) && rm(path)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lons, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lats, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, F, long_name) in (("ghf", ghf, "geothermal heat flow"),
                                 ("ghf_min", ghf_min, "minimum geothermal heat flow of the alternative models"),
                                 ("ghf_max", ghf_max, "maximum geothermal heat flow of the alternative models"))
        defVar(ds, name, F, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "mW m-2", "long_name" => long_name])
    end
    ds.attrib["title"] = "Geothermal heat flow of Antarctica (Lösing and Ebbing, 2021)"
    ds.attrib["references"] = "Lösing, M. and Ebbing, J.: Predicting geothermal heat flow in Antarctica " *
                              "with a machine learning approach, J. Geophys. Res. Solid Earth, 126, " *
                              "e2020JB021499, 2021, doi:10.1029/2020JB021499; data: Lösing, M. and Ebbing, J.: " *
                              "Predicted Antarctic heat flow and uncertainties using machine learning, " *
                              "PANGAEA, 2021, doi:10.1594/PANGAEA.930237 (HF_Min_Max_MaxAbs-1.csv)"
    ds.attrib["doi"] = "10.1594/PANGAEA.930237"
    ds.attrib["license"] = "CC BY 4.0"
    ds.attrib["comment"] = "Equal-area points (0.5° in latitude, about 55 km) on a regular lon-lat grid: " *
                           "each cell has the value of the nearest point of its latitude ring"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
