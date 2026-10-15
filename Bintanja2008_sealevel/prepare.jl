# Prepare the sea level, ice volume and temperature of Bintanja and van de Wal (2008) as a
# record (see Records/README.md): the NOAA NCEI file (datamanifest key
# bintanja2008_sealevel), from the inverse modelling of benthic d18O with Northern
# Hemisphere ice-sheet models, every 100 years over 3 Myr, as a global series (featureType
# timeSeries), $FESMDATA_PREPARED/Bintanja2008_sealevel/Bintanja2008_sealevel.nc.
#
# Usage:
#     julia --project=Bintanja2008_sealevel Bintanja2008_sealevel/prepare.jl
#     julia fesmdata.jl record SeaLevel Bintanja2008
#
# The source gives sea-level lowering and ice volume as positive: they change sign here
# (sl and the contributions negative when lower). Values at present are kept as given
# (sl = -1.46 m).

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "bintanja2008_sealevel")
t = read_noaa(txt)
neg(c) = .-nan64(column(t, c))

write_series(joinpath(prepared_dir("Bintanja2008_sealevel"), "Bintanja2008_sealevel.nc"); tag="sealevel",
    sites=[Region("global")], instance="region", time=1000 .* nan64(column(t, "age_calkaBP")),
    time_comment="age model of the LR04 stack (Lisiecki and Raymo, 2005), every 100 years, years before 1950 CE",
    vars=[Var("sl", neg("RSL"), "m", "global sea level relative to the present (sign changed: negative when lower)"),
          Var("sl_nam", neg("Ice_nam"), "m",
              "contribution of the North American ice sheet to sea level relative to the present (minus its volume, m sea level equivalent)"),
          Var("sl_eas", neg("Ice_eas"), "m",
              "contribution of the Eurasian ice sheet to sea level relative to the present (minus its volume, m sea level equivalent)"),
          Var("tas_anom_nh", column(t, "Tsurf"), "K", "surface air temperature anomaly over Northern Hemisphere land (40-80N) relative to the present"),
          Var("t_deep_anom", column(t, "Tdo"), "K", "deep-water temperature anomaly relative to the present"),
          Var("d18O_benthic", column(t, "Iso_tot"), "1e-3", "modelled benthic d18O relative to the present, per mil"),
          Var("d18O_ice", column(t, "Iso_ice"), "1e-3", "ice-volume contribution to the benthic d18O, per mil"),
          Var("d18O_temp", column(t, "Iso_do"), "1e-3", "deep-water temperature contribution to the benthic d18O, per mil")],
    title="Sea level, Northern Hemisphere ice volume and temperature, 3 Myr (Bintanja and van de Wal, 2008)",
    references="Bintanja, R. and van de Wal, R. S. W.: North American ice-sheet dynamics and the onset of 100,000-year " *
               "glacial cycles, Nature, 454, 869-872, 2008, doi:10.1038/nature07158. Data: 3 Million Year Temperature, " *
               "Sea Level, and Ice Volume Reconstructions, NOAA NCEI, doi:10.25921/revb-da37",
    doi="10.25921/revb-da37",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
