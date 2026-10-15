# Prepare the Dome Fuji water isotopes and temperatures of Uemura et al. (2012, 2018) as a
# record (see Records/README.md): the NOAA NCEI file (datamanifest key
# uemura2018_domefuji), d18O, dD, deuterium excess and the site and source temperatures
# over 720 kyr, on AICC2012, as a time series at Dome Fuji (featureType timeSeries),
# $FESMDATA_PREPARED/Uemura2018_DomeFuji/Uemura2018_DomeFuji.nc.
#
# Usage:
#     julia --project=Uemura2018_DomeFuji Uemura2018_DomeFuji/prepare.jl
#     julia fesmdata.jl record IceCores Uemura2018
#
# The samples of the bottom without an age are left out. The record joins the first core
# (to 2401.91 m) and the second (from 2399.5 m), so the depths reverse at about 2400 m:
# the samples are sorted by age (dimension `sample`).

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

# Dome Fuji (the NOAA file gives 38.7°E, a typo for 39.70°E)
const SITE = Site("Dome Fuji", -77.32, 39.70; z_srf=3810.0)

txt = download_dataset(manifest(), "uemura2018_domefuji")
t = read_noaa(txt)
age = column(t, "Age")
idx = sortperm(nan64(age))[1:count(!ismissing, age)]
println("$(nrows(t)) samples, $(nrows(t) - length(idx)) without an age left out")
col(name) = column(t, name)[idx]

write_series(joinpath(prepared_dir("Uemura2018_DomeFuji"), "Uemura2018_DomeFuji.nc"); tag="icecores",
    sites=[SITE], axis="sample", time=nan64(age[idx]),
    time_comment="AICC2012 ice age (Bazin et al., 2013), years before 1950 CE",
    vars=[Var("depth_top", col("Depth_top_m"), "m", "depth in the core of the top of the sample"; T=Float64,
              attrib=["positive" => "down"]),
          Var("depth_bottom", col("Depth_bottom_m"), "m", "depth in the core of the bottom of the sample"; T=Float64,
              attrib=["positive" => "down"]),
          Var("d18O", col("del_18O"), "1e-3", "delta-18O of the ice, per mil VSMOW"),
          Var("dD", col("del_D"), "1e-3", "delta-D of the ice, per mil VSMOW"),
          Var("dxs", col("dxs"), "1e-3", "deuterium excess (dD - 8 d18O), per mil"),
          Var("dln", col("dln"), "1e-3", "deuterium excess, logarithmic definition, per mil"),
          Var("tas_anom", col("T_site"), "K", "air temperature anomaly at the site relative to the present, from an isotope model"),
          Var("t_source_anom", col("T_source"), "K",
              "temperature anomaly of the ocean moisture source relative to the present, from an isotope model")],
    title="Dome Fuji water isotopes and temperatures, 720 kyr (Uemura et al., 2012, 2018)",
    references="Uemura, R., Motoyama, H., Masson-Delmotte, V., Jouzel, J., Kawamura, K., Goto-Azuma, K., Fujita, S., " *
               "Kuramoto, T., Hirabayashi, M., Miyake, T., Ohno, H., Fujita, K., Abe-Ouchi, A., Iizuka, Y., Horikawa, S., " *
               "Igarashi, M., Suzuki, K., Suzuki, T., and Fujii, Y.: Asynchrony between Antarctic temperature and CO2 " *
               "associated with obliquity over the past 720,000 years, Nat. Commun., 9, 961, 2018, " *
               "doi:10.1038/s41467-018-03328-3; Uemura, R. et al.: Ranges of moisture-source temperature estimated " *
               "from Antarctic ice cores stable isotope records over glacial-interglacial cycles, Clim. Past, 8, " *
               "1109-1125, 2012, doi:10.5194/cp-8-1109-2012. Data: Dome Fuji 720,000 Year Stable Isotope Data and " *
               "Temperature Reconstruction, NOAA NCEI, doi:10.25921/9886-bg13",
    doi="10.25921/9886-bg13",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
