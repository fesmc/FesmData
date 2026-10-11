# Prepare the GPS vertical velocities of Schumacher et al. (2018) as a record (see
# Records/README.md): the uplift rates of all (about 4000) stations of the global data
# set (PANGAEA, datamanifest key schumacher2018_gps), one value per station
# (featureType point), $FESMDATA_WORK/prepared/Schumacher2018_GIA_GrIS/Schumacher2018_GPS.nc.
#
# Usage:
#     julia --project=Schumacher2018_GIA_GrIS Schumacher2018_GIA_GrIS/prepare.jl
#     julia fesmdata.jl record GPS Schumacher2018

using CSV
using DataFrames
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

tab = download_dataset(manifest(), "schumacher2018_gps")

# PANGAEA text: a /* ... */ metadata header, then a table with the columns Station,
# Longitude, Latitude, V vert [mm/a], V vert std dev [±]
lines = readlines(tab)
h = findfirst(l -> startswith(l, "*/"), lines)
h === nothing && error("$tab: no end of the metadata header (*/)")
df = CSV.read(tab, DataFrame; delim='\t', header=h + 1, stringtype=String)
names(df) == ["Station", "Longitude", "Latitude", "V vert [mm/a]", "V vert std dev [±]"] ||
    error("$tab: unexpected columns $(names(df))")
any(ismissing, Matrix(df)) && error("$tab: missing values")
n = nrow(df)

path = joinpath(prepared_dir("Schumacher2018_GIA_GrIS"), "Schumacher2018_GPS.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defDim(ds, "station", n)
    defVar(ds, "site_name", df.Station, ("station",); attrib=["long_name" => "GPS station"])
    defVar(ds, "lat", Float64.(df.Latitude), ("station",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "lon", Float64.(df.Longitude), ("station",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "uplift_rate", Float32.(df[:, 4]), ("station",); attrib=[
        "units" => "mm yr-1", "long_name" => "vertical velocity of the land surface (GIA uplift rate)",
        "coordinates" => "lat lon",
        "comment" => "GPS velocity corrected for non-GIA effects (atmospheric loading, elastic response to present " *
                     "ice and ocean loading, rotational pole changes; see the article)"])
    defVar(ds, "uplift_rate_sd", Float32.(df[:, 5]), ("station",); attrib=[
        "units" => "mm yr-1", "long_name" => "standard deviation of the vertical velocity", "coordinates" => "lat lon"])
    ds.attrib["title"] = "GPS vertical velocities for glacial isostatic adjustment (Schumacher et al., 2018)"
    ds.attrib["references"] = "Schumacher, M., King, M. A., Rougier, J., Sha, Z., Khan, S. A., and Bamber, J. L.: " *
                              "A new global GPS data set for testing and improving modelled GIA uplift rates, " *
                              "Geophys. J. Int., 214, 2164-2176, 2018, doi:10.1093/gji/ggy235. Data: PANGAEA, " *
                              "doi:10.1594/PANGAEA.889923"
    ds.attrib["doi"] = "10.1594/PANGAEA.889923"
    ds.attrib["license"] = "CC BY 3.0 (PANGAEA)"
    ds.attrib["featureType"] = "point"
    ds.attrib["Conventions"] = "CF-1.11"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("gps"))
end
println("Wrote $path")
