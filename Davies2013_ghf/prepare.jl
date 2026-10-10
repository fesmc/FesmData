# Prepare the Davies (2013) geothermal heat flow for remapping: the 2° lon-lat version of
# the map in the supporting information (Data_Table1_Eq_lon_lat_Global_HF.csv, datamanifest
# key davies2013_ghf) as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/Davies2013_ghf/Davies2013_GHF.nc, with ghf, ghf_median and ghf_err.
#
# Usage:
#     julia --project=Davies2013_ghf Davies2013_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Davies2013_ghf/Davies2013_GHF.nc all

using CSV
using DataFrames
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const INPUT = get_dataset_path(manifest(), "davies2013_ghf")
isfile(INPUT) || error("$INPUT is missing: download it by hand, see Davies2013_ghf/README.md")

# Columns: Longitude, Latitude, Mean_HF, Median_HF, Total_Erro (mW m-2); one row per
# cell centre of the 2° grid (lon -179:179, lat -89:89)
df = CSV.read(INPUT, DataFrame; ignoreemptyrows=true)
lon = sort(unique(Float64.(df.Longitude)))
lat = sort(unique(Float64.(df.Latitude)))
nx, ny = length(lon), length(lat)
nrow(df) == nx * ny || error("$INPUT is not a full lon-lat grid")

fields = (("ghf", :Mean_HF, "geothermal heat flow (based on the mean)"),
          ("ghf_median", :Median_HF, "geothermal heat flow (based on the median)"),
          ("ghf_err", :Total_Erro, "error estimate of geothermal heat flow"))
F = Dict(name => fill(NaN32, nx, ny) for (name, _, _) in fields)
for r in eachrow(df)
    i = searchsortedfirst(lon, r.Longitude)
    j = searchsortedfirst(lat, r.Latitude)
    for (name, col, _) in fields
        F[name][i, j] = r[col]
    end
end

path = joinpath(prepared_dir("Davies2013_ghf"), "Davies2013_GHF.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, _, long_name) in fields
        defVar(ds, name, F[name], ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "mW m-2", "long_name" => long_name])
    end
    ds.attrib["title"] = "Global geothermal heat flow (Davies, 2013)"
    ds.attrib["references"] = "Davies, J. H.: Global map of solid Earth surface heat flow, " *
                              "Geochem. Geophys. Geosyst., 14, 4608-4622, 2013"
    ds.attrib["doi"] = "10.1002/ggge.20271"
    ds.attrib["license"] = "Supporting information of an AGU article, under the Wiley standard terms " *
                           "(no open licence)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
