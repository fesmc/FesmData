# Prepare the Vostok deuterium and temperature record of Petit et al. (1999) as a record
# (see Records/README.md): the NOAA NCEI file (datamanifest key petit1999_vostok), dD
# every 1 m and the temperature anomaly over 420 kyr, on the GT4 time scale, as a time
# series at Vostok (featureType timeSeries),
# $FESMDATA_PREPARED/Petit1999_Vostok/Petit1999_Vostok.nc.
#
# Usage:
#     julia --project=Petit1999_Vostok Petit1999_Vostok/prepare.jl
#     julia fesmdata.jl record IceCores Petit1999

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "petit1999_vostok")
t = read_noaa(txt)
site = noaa_site(txt)
depth = column(t, "depth_m")

write_series(joinpath(prepared_dir("Petit1999_Vostok"), "Petit1999_Vostok.nc"); tag="icecores",
    sites=[Site("Vostok", site.lat, site.lon; z_srf=site.z_srf)],
    time=nan64(column(t, "ice_ageBP")),
    time_comment="GT4 ice age (Petit et al., 1999), years before 1950 CE",
    axis_vars=[Var("time_aicc2023", aicc2023_age("Vostok", depth), "years ago",
                   "AICC2023 ice age (Bouchet et al., 2023), years before 1950 CE"; T=Float64)],
    vars=[Var("depth", depth, "m", "depth in the core"; T=Float64, attrib=["positive" => "down"]),
          Var("dD", column(t, "deltaD"), "1e-3", "delta-D of the ice, per mil SMOW"),
          Var("tas_anom", column(t, "deltaTS"), "K",
              "surface temperature anomaly relative to the present (dD of -438 per mil), from dD")],
    title="Vostok deuterium and temperature, 420 kyr (Petit et al., 1999)",
    references="Petit, J. R., Jouzel, J., Raynaud, D., Barkov, N. I., Barnola, J.-M., Basile, I., Bender, M., " *
               "Chappellaz, J., Davis, M., Delaygue, G., Delmotte, M., Kotlyakov, V. M., Legrand, M., Lipenkov, V. Y., " *
               "Lorius, C., Pépin, L., Ritz, C., Saltzman, E., and Stievenard, M.: Climate and atmospheric history " *
               "of the past 420,000 years from the Vostok ice core, Antarctica, Nature, 399, 429-436, 1999, " *
               "doi:10.1038/20859. Data: Vostok Ice Core Data for 420,000 Years, NOAA NCEI, doi:10.25921/kcry-ae86",
    doi="10.25921/kcry-ae86",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
