# Prepare the EPICA Dome C deuterium and temperature record of Jouzel et al. (2007) as a
# record (see Records/README.md): the NOAA NCEI file (datamanifest key jouzel2007_edc),
# dD of 0.55 m bags and the temperature anomaly over 800 kyr, on EDC3, as a time series
# at EDC (featureType timeSeries), $FESMDATA_PREPARED/Jouzel2007_EDC/Jouzel2007_EDC.nc.
#
# Usage:
#     julia --project=Jouzel2007_EDC Jouzel2007_EDC/prepare.jl
#     julia fesmdata.jl record IceCores Jouzel2007

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "jouzel2007_edc")
t = read_noaa(txt)
site = noaa_site(txt)
depth = column(t, "depth_top_m")

write_series(joinpath(prepared_dir("Jouzel2007_EDC"), "Jouzel2007_EDC.nc"); tag="icecores",
    sites=[Site("EDC", site.lat, site.lon; z_srf=site.z_srf)],
    time=nan64(column(t, "age_calBP")),
    time_comment="EDC3 ice age at the top of the 0.55 m bag (years before 1950 CE)",
    axis_vars=[Var("time_aicc2023", aicc2023_age("EDC", depth), "years ago",
                   "AICC2023 ice age at the top of the bag (Bouchet et al., 2023), years before 1950 CE"; T=Float64)],
    vars=[Var("depth", depth, "m", "depth in the core of the top of the bag"; T=Float64, attrib=["positive" => "down"]),
          Var("dD", column(t, "Deuterium"), "1e-3", "delta-D of the ice, per mil VSMOW"),
          Var("tas_anom", column(t, "Temperature"), "K",
              "surface temperature anomaly relative to the mean of the last 1000 years, from dD, corrected for the " *
              "isotopic composition of sea water (Bintanja et al., 2005) and for the ice sheet elevation (Parrenin et al., 2007)")],
    title="EPICA Dome C deuterium and temperature, 800 kyr (Jouzel et al., 2007)",
    references="Jouzel, J., Masson-Delmotte, V., Cattani, O., Dreyfus, G., Falourd, S., Hoffmann, G., Minster, B., " *
               "Nouet, J., Barnola, J. M., Chappellaz, J., Fischer, H., Gallet, J. C., Johnsen, S., Leuenberger, M., " *
               "Loulergue, L., Luethi, D., Oerter, H., Parrenin, F., Raisbeck, G., Raynaud, D., Schilt, A., Schwander, J., " *
               "Selmo, E., Souchez, R., Spahni, R., Stauffer, B., Steffensen, J. P., Stenni, B., Stocker, T. F., " *
               "Tison, J. L., Werner, M., and Wolff, E. W.: Orbital and millennial Antarctic climate variability over " *
               "the past 800,000 years, Science, 317, 793-796, 2007, doi:10.1126/science.1141038. Data: EPICA Dome C " *
               "Ice Core 800KYr Deuterium Data and Temperature Estimates, NOAA NCEI, doi:10.25921/8t7e-z147",
    doi="10.25921/8t7e-z147",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
