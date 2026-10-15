# Prepare the EDML d18O record of EPICA Community Members (2006, 2010) as a record (see
# Records/README.md): the PANGAEA dataset (datamanifest key epica2006_edml), d18O of 0.5 m
# samples over 150 kyr, on the EDML1 time scale, with its corrections for sea water and
# elevation, as a time series at EDML (featureType timeSeries),
# $FESMDATA_PREPARED/EPICA2006_EDML/EPICA2006_EDML.nc.
#
# Usage:
#     julia --project=EPICA2006_EDML EPICA2006_EDML/prepare.jl
#     julia fesmdata.jl record IceCores EPICA2006

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

tab = download_dataset(manifest(), "epica2006_edml")
t = read_pangaea(tab)
ev = pangaea_event(tab)
# Two corrected d18O columns have the same (truncated) name: take the columns by position
COLUMNS = ["Depth ice/snow [m]", "Age [ka BP]", "Depth top [m]", "Depth bot [m]", r"^Age min \[ka\]", r"^Age max \[ka\]",
           r"^δ18O H2O \[‰ SMOW\] \(measured", r"^δ18O reconst \[‰\] \(d18O values corrected for sea",
           r"^δ18O reconst \[‰\] \(d18O values corrected for sea", r"^δ18O reconst \[‰\] \(Mean d18O content of sea",
           r"^Altitude cor \[m\]"]
length(t.names) == length(COLUMNS) && all(occursin.(COLUMNS, t.names)) ||
    error("$tab: unexpected columns $(join(t.names, " | "))")
depth, age, age_min, age_max, d18O, d18O_sw_cor, d18O_sw_alt_cor, d18O_sw, dz_alt = t.columns[[1, 2, 5, 6, 7, 8, 9, 10, 11]]

write_series(joinpath(prepared_dir("EPICA2006_EDML"), "EPICA2006_EDML.nc"); tag="icecores",
    sites=[Site("EDML", ev.lat, ev.lon; z_srf=ev.z_srf)],
    time=1000 .* nan64(age), time_bnds=permutedims(hcat(1000 .* nan64(age_min), 1000 .* nan64(age_max))),
    time_comment="EDML1 ice age at the middle of the 0.5 m sample (Ruth et al., 2007), years before 1950 CE; " *
                 "bounds: ages of the top and bottom of the sample",
    axis_vars=[Var("time_aicc2023", aicc2023_age("EDML", depth), "years ago",
                   "AICC2023 ice age at the middle of the sample (Bouchet et al., 2023), years before 1950 CE"; T=Float64)],
    vars=[Var("depth", depth, "m", "depth in the core of the middle of the sample"; T=Float64, attrib=["positive" => "down"]),
          Var("d18O", d18O, "1e-3", "delta-18O of the ice, measured, per mil SMOW"),
          Var("d18O_swcor", d18O_sw_cor, "1e-3", "delta-18O corrected for the d18O of sea water (sea level), per mil"),
          Var("d18O_swaltcor", d18O_sw_alt_cor, "1e-3",
              "delta-18O corrected for the d18O of sea water (sea level) and for the elevation of the site, per mil"),
          Var("d18O_sw", d18O_sw, "1e-3", "mean d18O of sea water used in the correction, per mil"),
          Var("dz_srf", dz_alt, "m", "elevation change of EDML used in the correction, relative to the present")],
    title="EDML d18O, 150 kyr (EPICA Community Members, 2006)",
    references="EPICA Community Members: One-to-one coupling of glacial climate variability in Greenland and " *
               "Antarctica, Nature, 444, 195-198, 2006, doi:10.1038/nature05301. Data: EPICA Community Members: " *
               "Stable oxygen isotopes of ice core EDML, PANGAEA, 2010, doi:10.1594/PANGAEA.754444",
    doi="10.1594/PANGAEA.754444", license="CC BY 3.0 (PANGAEA)")
