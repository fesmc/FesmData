# Prepare the GPS vertical velocities of Schumacher et al. (2018) as a record (see
# Records/README.md): the uplift rates of all (about 4000) stations of the global data
# set (PANGAEA, datamanifest key schumacher2018_gps), one value per station
# (featureType point), $FESMDATA_PREPARED/Schumacher2018_gps/Schumacher2018_GPS.nc.
#
# Usage:
#     julia --project=Schumacher2018_gps Schumacher2018_gps/prepare.jl
#     julia fesmdata.jl record GPS Schumacher2018

using CSV
using DataFrames

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

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

lon = Float64.(df.Longitude)
write_points(joinpath(prepared_dir("Schumacher2018_gps"), "Schumacher2018_GPS.nc");
    sites=Site.(df.Station, Float64.(df.Latitude), lon), site_long_name="GPS station",
    vars=[Var("uplift_rate", df[:, 4], "mm yr-1", "vertical velocity of the land surface with the elastic part removed (GIA uplift rate)";
              attrib=["elastic_correction" => "removed",
                      "comment" => "GPS velocity corrected for non-GIA effects (atmospheric loading, elastic response to " *
                                   "present ice and ocean loading, rotational pole changes; see the article)"]),
          Var("uplift_rate_sd", df[:, 5], "mm yr-1", "standard deviation of the vertical velocity")],
    title="GPS vertical velocities for glacial isostatic adjustment (Schumacher et al., 2018)",
    references="Schumacher, M., King, M. A., Rougier, J., Sha, Z., Khan, S. A., and Bamber, J. L.: " *
               "A new global GPS data set for testing and improving modelled GIA uplift rates, " *
               "Geophys. J. Int., 214, 2164-2176, 2018, doi:10.1093/gji/ggy235. Data: PANGAEA, " *
               "doi:10.1594/PANGAEA.889923",
    doi="10.1594/PANGAEA.889923", license="CC BY 3.0 (PANGAEA)", tag="gps",
    attrib=["reference_frame" => "centre of mass of the Earth system (CM), as the GPS solutions (see the article)",
            "elastic_correction" => "removed"])
