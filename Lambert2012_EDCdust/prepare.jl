# Prepare the EPICA Dome C dust flux of Lambert et al. (2012) as a record (see
# Records/README.md): the PANGAEA dataset of 25-year means (datamanifest key
# lambert2012_edcdust) over 800 kyr, on EDC3, as a time series at EDC (featureType
# timeSeries), $FESMDATA_PREPARED/Lambert2012_EDCdust/Lambert2012_EDCdust.nc.
#
# Usage:
#     julia --project=Lambert2012_EDCdust Lambert2012_EDCdust/prepare.jl
#     julia fesmdata.jl record IceCores Lambert2012

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

tab = download_dataset(manifest(), "lambert2012_edcdust")
t = read_pangaea(tab)
ev = pangaea_event(tab)
depth = column(t, "Depth ice/snow [m]")

write_series(joinpath(prepared_dir("Lambert2012_EDCdust"), "Lambert2012_EDCdust.nc"); tag="icecores",
    sites=[Site("EDC", ev.lat, ev.lon; z_srf=ev.z_srf)],
    time=1000 .* nan64(column(t, "Age [ka BP]")),
    time_comment="EDC3 ice age of the 25-year mean, years before 1950 CE",
    axis_vars=[Var("time_aicc2023", aicc2023_age("EDC", depth), "years ago",
                   "AICC2023 ice age (Bouchet et al., 2023), years before 1950 CE"; T=Float64)],
    vars=[Var("depth", depth, "m", "depth in the core"; T=Float64, attrib=["positive" => "down"]),
          Var("dust_flux", column(t, "Dust flux [mg/m**2/a]"), "mg m-2 yr-1",
              "dust flux, 25-year mean of the 1 cm data (from few data points at the bottom of the core)")],
    title="EPICA Dome C dust flux, 800 kyr, 25-year means (Lambert et al., 2012)",
    references="Lambert, F., Bigler, M., Steffensen, J. P., Hutterli, M., and Fischer, H.: Centennial mineral dust " *
               "variability in high-resolution ice core data from Dome C, Antarctica, Clim. Past, 8, 609-623, 2012, " *
               "doi:10.5194/cp-8-609-2012. Data: Lambert, F. et al.: EDC dust flux 800 kyr (25 yr mean), PANGAEA, " *
               "doi:10.1594/PANGAEA.778213",
    doi="10.1594/PANGAEA.778213", license="CC BY 3.0 (PANGAEA)")
