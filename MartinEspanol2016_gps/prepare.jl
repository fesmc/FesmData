# Prepare the elastic-corrected GPS vertical velocities of Antarctica of Martín-Español
# et al. (2016) as a record (see Records/README.md): the 67 stations of their Table S1
# (2009-2014, ITRF2008; datamanifest key martinespanol2016_gps), one value per station
# (featureType point), $FESMDATA_PREPARED/MartinEspanol2016_gps/MartinEspanol2016_GPS.nc.
#
# Usage:
#     julia --project=MartinEspanol2016_gps MartinEspanol2016_gps/prepare.jl
#     julia fesmdata.jl record GPS MartinEspanol2016

using XLSX

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

xlsx = download_dataset(manifest(), "martinespanol2016_gps")

# One sheet: a row of column names (Site, Lat, Lon (0:360), Start, End (decimal years),
# N days, RINEX data DOI, ID, Obs Rate, Obs std, then the rates of 8 GIA solutions), one
# row per station, then empty rows
m = XLSX.readxlsx(xlsx)[1][:]
header = [ismissing(h) ? "" : strip(string(h)) for h in m[1, :]]
function col(name)
    j = findfirst(==(name), header)
    j === nothing && error("$xlsx: no column $name in $(join(header, " | "))")
    return j
end
rows = [i for i in 2:size(m, 1) if !ismissing(m[i, col("Site")]) && !isempty(strip(string(m[i, col("Site")])))]
num(name) = Float64[m[i, col(name)] for i in rows]
site = String[strip(string(m[i, col("Site")])) for i in rows]
allunique(site) || error("$xlsx: sites repeat")
length(site) == 67 || error("$xlsx: $(length(site)) sites, expected 67")

write_points(joinpath(prepared_dir("MartinEspanol2016_gps"), "MartinEspanol2016_GPS.nc");
    sites=Site.(site, num("Lat"), mod.(num("Lon") .+ 180, 360) .- 180), site_long_name="GPS station",
    vars=[Var("uplift_rate", num("Obs Rate"), "mm yr-1", "vertical velocity of the land surface with the elastic part removed (GIA uplift rate)";
              attrib=["elastic_correction" => "removed",
                      "comment" => "GPS velocity of 2009-2014 corrected for the elastic response to the Antarctic " *
                                   "ice mass changes of the period (REAR, from the RATES mass trends) and for " *
                                   "atmospheric pressure loading (see the article)"]),
          Var("uplift_rate_sd", num("Obs std"), "mm yr-1", "uncertainty (1 sigma) of the vertical velocity"),
          Var("time_start", num("Start"), "year", "first epoch of the series used (decimal year CE)"; T=Float64),
          Var("time_end", num("End"), "year", "last epoch of the series used (decimal year CE)"; T=Float64)],
    title="Elastic-corrected GPS vertical velocities of Antarctica, 2009-2014, ITRF2008 (Martín-Español et al., 2016)",
    references="Martín-Español, A., King, M. A., Zammit-Mangion, A., Andrews, S. B., Moore, P., and Bamber, J. L.: " *
               "An assessment of forward and inverse GIA solutions for Antarctica, J. Geophys. Res. Solid Earth, " *
               "121, 6947-6965, 2016, doi:10.1002/2016JB013154 (Table S1)",
    doi="10.1002/2016JB013154", license="CC BY 4.0 (open access article and its supporting information)",
    tag="gps",
    attrib=["reference_frame" => "ITRF2008 (IGS08, JPL GIPSY precise point positioning)",
            "elastic_correction" => "removed"])
