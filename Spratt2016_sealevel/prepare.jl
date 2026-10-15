# Prepare the sea-level stacks of Spratt and Lisiecki (2016) as a record (see
# Records/README.md): the NOAA NCEI file (datamanifest key spratt2016_sealevel), the
# scaled first principal components of seven (0-430 ka) and five (0-798 ka) sea-level
# reconstructions every 1 kyr, as a global series (featureType timeSeries),
# $FESMDATA_PREPARED/Spratt2016_sealevel/Spratt2016_sealevel.nc.
#
# Usage:
#     julia --project=Spratt2016_sealevel Spratt2016_sealevel/prepare.jl
#     julia fesmdata.jl record SeaLevel Spratt2016

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "spratt2016_sealevel")
t = read_noaa(txt)

vars = Var[]
for (name, col, what) in (("sl_short", "SeaLev_shortPC1", "seven sea-level reconstructions, 0-430 ka"),
                          ("sl_long", "SeaLev_longPC1", "five sea-level reconstructions, 0-798 ka"))
    push!(vars, Var(name, column(t, col), "m", "sea level relative to the present, scaled first principal component of $what"),
                Var("$(name)_sd", column(t, "$(col)_err_sig"), "m", "uncertainty (1 sigma, bootstrap) of $name"),
                Var("$(name)_min", column(t, "$(col)_err_lo"), "m", "lower bound of the 95% confidence interval of $name"),
                Var("$(name)_max", column(t, "$(col)_err_up"), "m", "upper bound of the 95% confidence interval of $name"))
end

write_series(joinpath(prepared_dir("Spratt2016_sealevel"), "Spratt2016_sealevel.nc"); tag="sealevel",
    sites=[Region("global")], instance="region", time=1000 .* nan64(column(t, "age_calkaBP")),
    time_comment="LR04 age model (Lisiecki and Raymo, 2005), every 1 kyr, years before 1950 CE",
    vars, title="Sea-level stacks of the last 798 kyr (Spratt and Lisiecki, 2016)",
    references="Spratt, R. M. and Lisiecki, L. E.: A Late Pleistocene sea level stack, Clim. Past, 12, 1079-1092, " *
               "2016, doi:10.5194/cp-12-1079-2016. Data: Late Pleistocene Sea Level Stack, NOAA NCEI, " *
               "doi:10.25921/rd66-5820",
    doi="10.25921/rd66-5820",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
