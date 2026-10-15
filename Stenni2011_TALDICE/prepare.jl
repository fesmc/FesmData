# Prepare the TALDICE d18O record of Stenni et al. (2011) on AICC2012 as a record (see
# Records/README.md): the PANGAEA dataset of the AICC2012 chronology (datamanifest key
# stenni2011_taldice), d18O every 1 m to 1437 m (153 ka), as a time series at Talos Dome
# (featureType timeSeries), $FESMDATA_PREPARED/Stenni2011_TALDICE/Stenni2011_TALDICE.nc.
#
# Usage:
#     julia --project=Stenni2011_TALDICE Stenni2011_TALDICE/prepare.jl
#     julia fesmdata.jl record IceCores Stenni2011

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

tab = download_dataset(manifest(), "stenni2011_taldice")
t = read_pangaea(tab)
ev = pangaea_event(tab)
depth = column(t, "Depth ice/snow [m]")

write_series(joinpath(prepared_dir("Stenni2011_TALDICE"), "Stenni2011_TALDICE.nc"); tag="icecores",
    sites=[Site("TALDICE", ev.lat, ev.lon; z_srf=ev.z_srf)],
    time=1000 .* nan64(column(t, "Age [ka BP]")),
    time_comment="AICC2012 ice age (Bazin et al., 2013), years before 1950 CE",
    axis_vars=[Var("time_aicc2023", aicc2023_age("TALDICE", depth), "years ago",
                   "AICC2023 ice age (Bouchet et al., 2023), years before 1950 CE"; T=Float64)],
    vars=[Var("depth", depth, "m", "depth in the core"; T=Float64, attrib=["positive" => "down"]),
          Var("d18O", column(t, "δ18O H2O [‰ SMOW]"), "1e-3", "delta-18O of the ice, per mil SMOW")],
    title="TALDICE d18O on AICC2012, 153 kyr (Stenni et al., 2011)",
    references="Stenni, B., Buiron, D., Frezzotti, M., Albani, S., Barbante, C., Bard, E., Barnola, J. M., " *
               "Baroni, M., Baumgartner, M., Bonazza, M., Capron, E., Castellano, E., Chappellaz, J., Delmonte, B., " *
               "Falourd, S., Genoni, L., Iacumin, P., Jouzel, J., Kipfstuhl, S., Landais, A., Lemieux-Dudon, B., " *
               "Maggi, V., Masson-Delmotte, V., Mazzola, C., Minster, B., Montagnat, M., Mulvaney, R., Narcisi, B., " *
               "Oerter, H., Parrenin, F., Petit, J. R., Ritz, C., Scarchilli, C., Schilt, A., Schüpbach, S., " *
               "Schwander, J., Selmo, E., Severi, M., Stocker, T. F., and Udisti, R.: Expression of the bipolar " *
               "see-saw in Antarctic climate records during the last deglaciation, Nat. Geosci., 4, 46-49, 2011, " *
               "doi:10.1038/ngeo1026. Data on AICC2012: Bazin, L. et al.: An optimized multi-proxy, multi-site " *
               "Antarctic ice and gas orbital chronology (AICC2012): 120-800 ka, Clim. Past, 9, 1715-1731, 2013, " *
               "doi:10.5194/cp-9-1715-2013; PANGAEA, doi:10.1594/PANGAEA.824890",
    doi="10.1594/PANGAEA.824890", license="CC BY 3.0 (PANGAEA)")
