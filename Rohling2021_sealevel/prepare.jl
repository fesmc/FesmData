# Prepare the sea level and ice sheet volumes of Rohling et al. (2021) as a record (see
# Records/README.md): the main regression on the LR04 stack of the NOAA NCEI archive
# (datamanifest key rohling2021_sealevel), every 1 kyr over 5.3 Myr, as a global series
# (featureType timeSeries),
# $FESMDATA_PREPARED/Rohling2021_sealevel/Rohling2021_sealevel.nc.
#
# Usage:
#     julia --project=Rohling2021_sealevel Rohling2021_sealevel/prepare.jl
#     julia fesmdata.jl record SeaLevel Rohling2021
#
# The ice volumes of the source (V_LIS, ...) are totals in m sea level equivalent,
# positive: the contributions here are minus their changes from the present (t = 0),
# negative when sea level is lower. The rows are sorted forward in age (the source gives
# negative ka).

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "rohling2021_sealevel")
t = read_noaa(txt)
age = -1000 .* nan64(column(t, "t(ka)")) .+ 0.0   # negative ka (+ 0.0: no -0.0)
idx = sortperm(age)
age[idx[1]] == 0 || error("$txt: no row at t = 0")
col(c) = nan64(column(t, c))[idx]
contribution(c) = (v = col(c); .-(v .- v[1]))

write_series(joinpath(prepared_dir("Rohling2021_sealevel"), "Rohling2021_sealevel.nc"); tag="sealevel",
    sites=[Region("global")], instance="region", time=age[idx],
    time_comment="LR04 age model (Lisiecki and Raymo, 2005), every 1 kyr, years before 1950 CE",
    vars=[Var("sl", col("SL"), "m", "sea level relative to the present, main regression"),
          Var("sl_lis", contribution("V_LIS"), "m", "contribution of the Laurentide ice sheet to sea level relative to the present"),
          Var("sl_eis", contribution("V_EIS"), "m", "contribution of the Eurasian ice sheet to sea level relative to the present"),
          Var("sl_ais", contribution("V_AIS"), "m", "contribution of the Antarctic ice sheet to sea level relative to the present"),
          Var("sl_gris", contribution("V_GrIS"), "m", "contribution of the Greenland ice sheet to sea level relative to the present"),
          Var("d18O_benthic", col("d18O"), "1e-3", "benthic d18O of the LR04 stack, per mil"),
          Var("d18O_sw", col("d18Ow_IV"), "1e-3", "ice-volume related d18O of sea water relative to the present, per mil"),
          Var("d18O_temp", col("d18O_T"), "1e-3", "temperature related d18O change relative to the present, per mil"),
          Var("t_deep_anom", col("Tw"), "K", "deep-sea temperature change relative to the present")],
    title="Sea level and ice sheet volumes, 5.3 Myr (Rohling et al., 2021)",
    references="Rohling, E. J., Yu, J., Heslop, D., Foster, G. L., Opdyke, B., and Roberts, A. P.: Sea level and " *
               "deep-sea temperature reconstructions suggest quasi-stable states and critical transitions over the " *
               "past 40 million years, Sci. Adv., 7, eabf5326, 2021, doi:10.1126/sciadv.abf5326. Data: NOAA NCEI, " *
               "doi:10.25921/rq2y-4k67 (rohling2021-lr-main.txt)",
    doi="10.25921/rq2y-4k67",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication; article CC BY 4.0)")
