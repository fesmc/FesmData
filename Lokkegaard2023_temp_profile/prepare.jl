# Prepare the Greenland and Canadian Arctic ice temperature profiles database of
# Løkkegaard et al. (2023) as a record (see Records/README.md): the temperature profiles
# of 95 boreholes on a common 1 m depth axis and their metadata (GEUS Dataverse,
# datamanifest keys lokkegaard2023_temperature and lokkegaard2023_meta), one profile per
# borehole (featureType profile),
# $FESMDATA_WORK/prepared/Lokkegaard2023_temp_profile/Lokkegaard2023_boreholes.nc.
#
# Usage:
#     julia --project=Lokkegaard2023_temp_profile Lokkegaard2023_temp_profile/prepare.jl
#     julia fesmdata.jl record Boreholes Lokkegaard2023

using CSV
using DataFrames
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

db = manifest()
temp = CSV.read(download_dataset(db, "lokkegaard2023_temperature"), DataFrame)
meta = CSV.read(download_dataset(db, "lokkegaard2023_meta"), DataFrame; stringtype=String)

# temperature.csv: a column "depth [m]", then one column per borehole (°C, NaN where not
# measured, -999 below the base of the ice); meta.csv: one row per borehole, by
# "Borehole ID"
names(temp)[1] == "depth [m]" || error("temperature.csv: first column $(names(temp)[1]), expected depth [m]")
depth = Float64.(temp[:, 1])
issorted(depth; lt=<=) || error("temperature.csv: depth does not increase")
ids = strip.(meta[:, "Borehole ID"])
cols = Dict(strip(c) => c for c in names(temp)[2:end])
Set(keys(cols)) == Set(ids) || error("the boreholes of temperature.csv and meta.csv differ")
const BELOW_BED = -999.0
T = Float32[x == BELOW_BED ? NaN : x + 273.15 for x in Matrix{Float64}(temp[:, [cols[id] for id in ids]])]
nz, ns = size(T)

str(c) = String[ismissing(x) ? "" : strip(string(x)) for x in meta[:, c]]
num(c) = Float64[ismissing(x) ? NaN : x for x in meta[:, c]]

path = joinpath(prepared_dir("Lokkegaard2023_temp_profile"), "Lokkegaard2023_boreholes.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defDim(ds, "station", ns)
    defDim(ds, "depth", nz)
    defVar(ds, "site_name", String.(ids), ("station",); attrib=["long_name" => "borehole", "cf_role" => "profile_id"])
    defVar(ds, "lat", num("Latitude [°N]"), ("station",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "lon", num("Longitude [°E]"), ("station",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "depth", depth, ("depth",); attrib=["units" => "m", "positive" => "down", "long_name" => "depth below the surface",
                                                   "axis" => "Z"])
    defVar(ds, "T_ice", T, ("depth", "station"); fillvalue=NaN32, deflatelevel=1, attrib=[
        "units" => "K", "long_name" => "ice temperature", "coordinates" => "lat lon depth",
        "comment" => "converted from °C (+ 273.15); missing where not measured and below the base of the ice " *
                     "(-999 in the source)"])
    for (name, c, long_name) in (("H_ice", "Ice thickness [m]", "ice thickness at the borehole"),
                                 ("depth_top", "Depth of top measurement [m]", "depth of the top measurement"),
                                 ("depth_bottom", "Depth of bottom measurement [m]", "depth of the bottom measurement"))
        defVar(ds, name, num(c), ("station",); fillvalue=NaN, attrib=["units" => "m", "long_name" => long_name])
    end
    defVar(ds, "coverage", num("Coverage [% of thickness]"), ("station",); fillvalue=NaN,
           attrib=["units" => "%", "long_name" => "fraction of the ice thickness covered by the profile"])
    for (name, c, long_name) in (("date", "Date", "date or year of the measurement"),
                                 ("place_name", "Place name", "place name"),
                                 ("location", "Geographic location", "geographic location"),
                                 ("site_type", "Site type", "site type"),
                                 ("data_source", "Data Source", "source of the data"),
                                 ("data_doi", "Data DOI", "DOI of the data"),
                                 ("reference", "Science Source", "publication"),
                                 ("reference_doi", "Science DOI", "DOI of the publication"),
                                 ("location_source", "Location Source", "source of the location"),
                                 ("H_ice_source", "Ice thickness source", "source of the ice thickness"),
                                 ("note", "Note", "note"))
        defVar(ds, name, str(c), ("station",); attrib=["long_name" => long_name])
    end
    ds.attrib["title"] = "Greenland and Canadian Arctic ice temperature profiles (Løkkegaard et al., 2023)"
    ds.attrib["references"] = "Løkkegaard, A., Mankoff, K. D., Zdanowicz, C., Clow, G. D., Lüthi, M. P., Doyle, S. H., " *
                              "et al.: Greenland and Canadian Arctic ice temperature profiles database, The " *
                              "Cryosphere, 17, 3829-3845, 2023, doi:10.5194/tc-17-3829-2023. Data: Mankoff, K., " *
                              "Løkkegaard, A., Colgan, W., et al.: Greenland and Canadian Arctic ice temperature " *
                              "profiles database, GEUS Dataverse, V4.1, 2022, doi:10.22008/FK2/3BVF9V"
    ds.attrib["doi"] = "10.22008/FK2/3BVF9V"
    ds.attrib["license"] = "CC0 1.0 (GEUS Dataverse)"
    ds.attrib["featureType"] = "profile"
    ds.attrib["Conventions"] = "CF-1.11"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("boreholes"))
end
println("Wrote $path")
