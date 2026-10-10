# Prepare the Lucazeau (2019) geothermal heat flow for remapping: the 0.5° grid of
# the supplementary data (HFgrid14.csv, in this folder) as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/Lucazeau2019_ghf/Lucazeau2019_GHF.nc, with ghf and ghf_sd.
#
# Usage:
#     julia --project=Lucazeau2019_ghf Lucazeau2019_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Lucazeau2019_ghf/Lucazeau2019_GHF.nc all

using CSV
using DataFrames
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))

const INPUT = joinpath(@__DIR__, "2019GC008389-sup-0003-Data_Set_SI-S01", "HFgrid14.csv")

# Columns: longitude (misspelled), latitude, HF_pred, sHF_pred, Hf_obs; one row per cell
df = CSV.read(INPUT, DataFrame)
lon = sort(unique(Float64.(df[:, 1])))
lat = sort(unique(Float64.(df[:, 2])))
nx, ny = length(lon), length(lat)
nrow(df) == nx * ny || error("$INPUT is not a full lon-lat grid")

ghf = fill(NaN32, nx, ny)
ghf_sd = fill(NaN32, nx, ny)
for r in eachrow(df)
    i = searchsortedfirst(lon, r[1])
    j = searchsortedfirst(lat, r[2])
    ghf[i, j] = r.HF_pred
    ghf_sd[i, j] = r.sHF_pred
end

path = joinpath(prepared_dir("Lucazeau2019_ghf"), "Lucazeau2019_GHF.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, F, long_name) in (("ghf", ghf, "geothermal heat flow"),
                                 ("ghf_sd", ghf_sd, "standard deviation of geothermal heat flow"))
        defVar(ds, name, F, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "mW m-2", "long_name" => long_name])
    end
    ds.attrib["title"] = "Global geothermal heat flow (Lucazeau, 2019)"
    ds.attrib["references"] = "Lucazeau, F.: Analysis and mapping of an updated terrestrial heat flow " *
                              "data set, Geochem. Geophys. Geosyst., 20, 4001-4024, 2019"
    ds.attrib["doi"] = "10.1029/2019GC008389"
    ds.attrib["license"] = "Supporting information of an AGU article, under the Wiley standard terms " *
                           "(no open licence): redistribution needs permission from AGU or the author"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
