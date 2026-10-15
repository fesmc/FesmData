# Prepare the revised Antarctic CO2 composite of Bereiter et al. (2015) as a record (see
# Records/README.md): the NOAA NCEI file (datamanifest key bereiter2015_co2), CO2 over 800
# kyr from several Antarctic ice cores on their gas ages, as a series of the region
# "Antarctic ice cores" (featureType timeSeries),
# $FESMDATA_PREPARED/Bereiter2015_CO2/Bereiter2015_CO2.nc.
#
# Usage:
#     julia --project=Bereiter2015_CO2 Bereiter2015_CO2/prepare.jl
#     julia fesmdata.jl record GHG Bereiter2015

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "bereiter2015_co2")
t = read_noaa(txt)
age = nan64(column(t, "age_gas_calBP"))
sorted = all(>(0), diff(age))
println("$(nrows(t)) values, ages $(sorted ? "" : "not ")strictly increasing")

write_series(joinpath(prepared_dir("Bereiter2015_CO2"), "Bereiter2015_CO2.nc"); tag="ghg",
    sites=[Region("Antarctic ice cores")], instance="region", axis=sorted ? "time" : "sample", time=age,
    time_comment="gas age, AICC2012 (Bazin et al., 2013) except for Law Dome, WAIS Divide and Siple Dome, " *
                 "on their own time scales; years before 1950 CE",
    vars=[Var("co2", column(t, "co2_ppm"), "ppm", "atmospheric CO2 mole fraction, composite of Antarctic ice cores"),
          Var("co2_sd", column(t, "co2_1s_ppm"), "ppm",
              "uncertainty (1 sigma) of co2 (the mean of the system or record where not given individually)")],
    title="Revised Antarctic ice core CO2 composite, 800 kyr (Bereiter et al., 2015)",
    references="Bereiter, B., Eggleston, S., Schmitt, J., Nehrbass-Ahles, C., Stocker, T. F., Fischer, H., " *
               "Kipfstuhl, S., and Chappellaz, J.: Revision of the EPICA Dome C CO2 record from 800 to 600 kyr " *
               "before present, Geophys. Res. Lett., 42, 542-549, 2015, doi:10.1002/2014GL061957. Data: " *
               "Antarctic Ice Cores Revised 800KYr CO2 Data, NOAA NCEI, doi:10.25921/n8y4-bp27",
    doi="10.25921/n8y4-bp27",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
