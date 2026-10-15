# Prepare the sea level of Waelbroeck et al. (2002) as a record (see Records/README.md):
# table 1 of the NOAA NCEI file (datamanifest key waelbroeck2002_sealevel), the global mean
# sea level and mean ocean d18O from benthic foraminifera every 1.5 kyr over 430 kyr, as a
# global series (featureType timeSeries),
# $FESMDATA_PREPARED/Waelbroeck2002_sealevel/Waelbroeck2002_sealevel.nc.
#
# Usage:
#     julia --project=Waelbroeck2002_sealevel Waelbroeck2002_sealevel/prepare.jl
#     julia fesmdata.jl record SeaLevel Waelbroeck2002
#
# The header calls the sea level "m below present sea level", but the values are negative
# when lower: they are relative sea level (m). RSL- is the shallower bound (sl_max), RSL+
# the deeper (sl_min).

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

const HEADER = ["Age", "d18Ow", "d18Ow-", "d18Ow+", "RSL", "RSL-", "RSL+", "Alt.Age1", "Alt.Age2", "Alt.Age3"]

txt = download_dataset(manifest(), "waelbroeck2002_sealevel")
lines = read_lines(txt)
h = findfirst(l -> split(l) == HEADER, lines)
h === nothing && error("$txt: no header line $(join(HEADER, " ")) (table 1)")
t = read_columns(txt, HEADER; skipto=h + 1)
ka(c) = 1000 .* nan64(column(t, c))

write_series(joinpath(prepared_dir("Waelbroeck2002_sealevel"), "Waelbroeck2002_sealevel.nc"); tag="sealevel",
    sites=[Region("global")], instance="region", time=ka("Age"),
    time_comment="14C then SPECMAP, adjusted at Termination II to coral U-Th dates, years before 1950 CE",
    axis_vars=[Var("time_alt1", ka("Alt.Age1"), "years ago", "alternate age model 1: 14C + SPECMAP, no Termination II adjustment"; T=Float64),
               Var("time_alt2", ka("Alt.Age2"), "years ago", "alternate age model 2: adjusted to Martinson et al. (1987) before 33 ka only"; T=Float64),
               Var("time_alt3", ka("Alt.Age3"), "years ago", "alternate age model 3: adjusted to Martinson et al. (1987) throughout"; T=Float64)],
    vars=[Var("sl", column(t, "RSL"), "m", "global mean sea level relative to the present, from benthic d18O"),
          Var("sl_min", column(t, "RSL+"), "m", "lower bound of the confidence interval of sl (RSL+)"),
          Var("sl_max", column(t, "RSL-"), "m", "upper bound of the confidence interval of sl (RSL-)"),
          Var("d18O_sw", column(t, "d18Ow"), "1e-3", "mean ocean d18O relative to the present, per mil SMOW"),
          Var("d18O_sw_min", column(t, "d18Ow-"), "1e-3", "lower bound of d18O_sw"),
          Var("d18O_sw_max", column(t, "d18Ow+"), "1e-3", "upper bound of d18O_sw")],
    title="Sea level and mean ocean d18O from benthic foraminifera, 430 kyr (Waelbroeck et al., 2002)",
    references="Waelbroeck, C., Labeyrie, L., Michel, E., Duplessy, J. C., McManus, J. F., Lambeck, K., Balbon, E., " *
               "and Labracherie, M.: Sea-level and deep water temperature changes derived from benthic foraminifera " *
               "isotopic records, Quat. Sci. Rev., 21, 295-305, 2002, doi:10.1016/S0277-3791(01)00101-9. Data: " *
               "Sea-level and Deep Water Temperature 430KYr Reconstructions, NOAA NCEI, doi:10.25921/08dt-1228",
    doi="10.25921/08dt-1228",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
