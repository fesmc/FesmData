# Prepare the sea level and ice sheet contributions of de Boer et al. (2014) as a record
# (see Records/README.md): the NOAA NCEI file (datamanifest key deboer2014_sealevel), from
# the inverse modelling of the LR04 benthic d18O with four ice-sheet models (ANICE), every
# 100 years over 5.3 Myr, as a global series (featureType timeSeries),
# $FESMDATA_PREPARED/deBoer2014_sealevel/deBoer2014_sealevel.nc.
#
# Usage:
#     julia --project=deBoer2014_sealevel deBoer2014_sealevel/prepare.jl
#     julia fesmdata.jl record SeaLevel deBoer2014
#
# The ice volumes of the source (EuIS-sc, ...) are totals in m sea level equivalent with
# a negative sign: the contributions here are their changes from the present (t = 0), the
# sign kept (negative when lower). The rows are reversed (the source runs back in time).

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "deboer2014_sealevel")
t = read_noaa(txt; missing_values=(-999,))
age = 1000 .* nan64(column(t, "age_calkaBP"))
idx = sortperm(age)
age[idx[1]] == 0 || error("$txt: no row at t = 0")
col(c) = nan64(column(t, c))[idx]
anomaly(c) = (v = col(c); v .- v[1])

write_series(joinpath(prepared_dir("deBoer2014_sealevel"), "deBoer2014_sealevel.nc"); tag="sealevel",
    sites=[Region("global")], instance="region", time=age[idx],
    time_comment="LR04 age model (Lisiecki and Raymo, 2005), every 100 years, years before 1950 CE",
    vars=[Var("sl", col("sealev"), "m", "eustatic sea level relative to the present, from the ice volume"),
          Var("sl_eis", anomaly("EuIS-sc"), "m", "contribution of the Eurasian ice sheet to sea level relative to the present"),
          Var("sl_nais", anomaly("NaIS-sc"), "m", "contribution of the North American ice sheet to sea level relative to the present"),
          Var("sl_ais", anomaly("AIS-sc"), "m", "contribution of the Antarctic ice sheet to sea level relative to the present"),
          Var("sl_gris", anomaly("GrIS-sc"), "m", "contribution of the Greenland ice sheet to sea level relative to the present"),
          Var("tas_anom_nh", col("tempanomNH"), "K", "continental surface air temperature anomaly of the Northern Hemisphere (40-80N) relative to the present"),
          Var("d18O_benthic", col("d18Obenth"), "1e-3", "modelled benthic d18O (close to the LR04 stack), per mil"),
          Var("d18O_sw", col("d18Osw"), "1e-3", "ice-volume contribution to the benthic d18O relative to the present, per mil"),
          Var("d18O_temp", col("d18Otemp"), "1e-3", "temperature contribution to the benthic d18O relative to the present, per mil"),
          Var("V_ais", col("AnIS-V"), "1e6 km3", "Antarctic ice volume"),
          Var("D_ais", col("AnIS-ID"), "Gt yr-1", "Antarctic ice discharge to the open ocean (as given, negative)")],
    title="Sea level and ice sheet contributions, 5.3 Myr (de Boer et al., 2014)",
    references="de Boer, B., Lourens, L. J., and van de Wal, R. S. W.: Persistent 400,000-year variability of " *
               "Antarctic ice volume and the carbon cycle is revealed throughout the Plio-Pleistocene, Nat. Commun., " *
               "5, 2999, 2014, doi:10.1038/ncomms3999. Data: 5 Myr Global Sea Level, Ice Volume, and Temperature " *
               "Reconstructions, NOAA NCEI, doi:10.25921/xs31-nt56",
    doi="10.25921/xs31-nt56",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
