# Prepare the EPICA Dome C methane record of Loulergue et al. (2008) as a record (see
# Records/README.md): the NOAA NCEI file (datamanifest key loulergue2008_ch4), CH4 over
# 800 kyr on the EDC3 gas age, as a time series at EDC (featureType timeSeries),
# $FESMDATA_PREPARED/Loulergue2008_CH4/Loulergue2008_CH4.nc.
#
# Usage:
#     julia --project=Loulergue2008_CH4 Loulergue2008_CH4/prepare.jl
#     julia fesmdata.jl record GHG Loulergue2008

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "loulergue2008_ch4")
t = read_noaa(txt)
site = noaa_site(txt)
depth = column(t, "depth_m")
age = nan64(column(t, "gas_age_calBP"))
sorted = all(>(0), diff(age))
lab = column(t, "Lab_name")
all(in(("b", "g")), lab) || error("$txt: laboratories other than b and g: $(unique(lab))")

write_series(joinpath(prepared_dir("Loulergue2008_CH4"), "Loulergue2008_CH4.nc"); tag="ghg",
    sites=[Site("EDC", site.lat, site.lon; z_srf=site.z_srf)], axis=sorted ? "time" : "sample", time=age,
    time_comment="EDC3 gas age (years before 1950 CE)",
    axis_vars=[Var("time_aicc2023", aicc2023_age("EDC", depth; kind="gas"), "years ago",
                   "AICC2023 gas age (Bouchet et al., 2023), years before 1950 CE"; T=Float64),
               Var("lab", [l == "b" ? 1 : 2 for l in lab], "1",
                   "laboratory of the measurement: 1 Bern, 2 Grenoble (Grenoble values corrected by +6 ppb)"; T=Int8)],
    vars=[Var("depth", depth, "m", "depth in the core (EDC99)"; T=Float64, attrib=["positive" => "down"]),
          Var("ch4", column(t, "CH4_mean"), "ppb", "atmospheric CH4 mole fraction"),
          Var("ch4_sd", column(t, "CH4_1s"), "ppb", "uncertainty (1 sigma) of ch4")],
    title="EPICA Dome C methane, 800 kyr (Loulergue et al., 2008)",
    references="Loulergue, L., Schilt, A., Spahni, R., Masson-Delmotte, V., Blunier, T., Lemieux, B., Barnola, " *
               "J.-M., Raynaud, D., Stocker, T. F., and Chappellaz, J.: Orbital and millennial-scale features of " *
               "atmospheric CH4 over the past 800,000 years, Nature, 453, 383-386, 2008, doi:10.1038/nature06950. " *
               "Data: EPICA Dome C Ice Core 800KYr Methane Data, NOAA NCEI, doi:10.25921/gfsj-jc86",
    doi="10.25921/gfsj-jc86",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
