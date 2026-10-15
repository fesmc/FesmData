# Prepare the sea level and CO2 of Berends et al. (2021) as a record (see
# Records/README.md): the supplement on Zenodo (datamanifest key berends2021_sealevel),
# global mean sea level and atmospheric CO2 of the hybrid ice-sheet-climate model forced
# by the LR04 benthic d18O, every 100 years over 3.6 Myr, as a global series (featureType
# timeSeries), $FESMDATA_PREPARED/Berends2021_sealevel/Berends2021_sealevel.nc.
#
# Usage:
#     julia --project=Berends2021_sealevel Berends2021_sealevel/prepare.jl
#     julia fesmdata.jl record SeaLevel Berends2021
#
# The file gives the results of three simulations: the value and its lower and upper
# bound. Values at present are kept as given (sl = -3.32 m).

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

const HEADER = ["time", "SL", "SL_lower", "SL_upper", "pCO2", "pCO2_lower", "pCO2_upper"]

dat = download_dataset(manifest(), "berends2021_sealevel")
lines = read_lines(dat)
h = findfirst(l -> startswith(l, "% Time (kyr ago)"), lines)
h === nothing && error("$dat: no header line % Time (kyr ago) ...")
split(lines[h])[5:end] == HEADER[2:end] || error("$dat: unexpected columns $(lines[h])")
t = read_columns(dat, HEADER; skipto=h + 1)
time = -1000 .* nan64(column(t, "time")) .+ 0.0    # kyr, negative in the past (+ 0.0: no -0.0)
idx = sortperm(time)

write_series(joinpath(prepared_dir("Berends2021_sealevel"), "Berends2021_sealevel.nc"); tag="sealevel",
    sites=[Region("global")], instance="region", time=time[idx],
    time_comment="LR04 age model (Lisiecki and Raymo, 2005) of the forcing, every 100 years, years before present (1950 CE)",
    vars=[Var("sl", column(t, "SL")[idx], "m", "global mean sea level relative to the present day, model"),
          Var("sl_min", column(t, "SL_lower")[idx], "m", "lower bound of sl (three simulations)"),
          Var("sl_max", column(t, "SL_upper")[idx], "m", "upper bound of sl (three simulations)"),
          Var("co2", column(t, "pCO2")[idx], "ppm", "atmospheric CO2 concentration, model"),
          Var("co2_min", column(t, "pCO2_lower")[idx], "ppm", "lower bound of co2 (three simulations)"),
          Var("co2_max", column(t, "pCO2_upper")[idx], "ppm", "upper bound of co2 (three simulations)")],
    title="Sea level and CO2 of a coupled ice-sheet-climate model, 3.6 Myr (Berends et al., 2021)",
    references="Berends, C. J., de Boer, B., and van de Wal, R. S. W.: Reconstructing the evolution of ice sheets, " *
               "sea level, and atmospheric CO2 during the past 3.6 million years, Clim. Past, 17, 361-377, 2021, " *
               "doi:10.5194/cp-17-361-2021. Data: Zenodo, doi:10.5281/zenodo.3793592",
    doi="10.5281/zenodo.3793592", license="CC BY 4.0 (Zenodo)")
