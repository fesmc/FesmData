# Prepare the WAIS Divide d18O record of the WAIS Divide Project Members (2015) as a record
# (see Records/README.md): the full data set of USAP-DC (datamanifest key wais2015_wdc,
# manual download), d18O of about 1 m tubes over 68 kyr on WD2014, as a time series at
# WAIS Divide (featureType timeSeries), $FESMDATA_PREPARED/WAIS2015_WDC/WAIS2015_WDC.nc.
#
# Usage:
#     julia --project=WAIS2015_WDC WAIS2015_WDC/prepare.jl
#     julia fesmdata.jl record IceCores WAIS2015
#
# AICC2023 has no depth-age table of WAIS Divide, but ties it to EDC: the AICC2023 ages
# of the tie points of AICC2023 (WDC depth, ice ages on WD2014 and AICC2023; datamanifest
# key aicc2023_wdc_ties) are interpolated linearly in WDC depth (10-57 ka; missing
# outside).

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

# WAIS Divide (WDC06A), as in the PANGAEA event of the tie points of AICC2023
const SITE = Site("WAIS Divide", -79.468, -112.086; z_srf=1766.0)
const HEADER = ["tube", "depth_top", "depth_bottom", "d18O", "age_top", "age_bottom"]

txt = download_dataset(manifest(), "wais2015_wdc")
lines = read_lines(txt)
any(l -> occursin("ka 1950.0", l), lines) || error("$txt: no ages in ka before 1950.0 in the header")
data = [split(l, '\t') for l in lines if !startswith(l, "%") && !isempty(strip(l))]
all(length.(data) .== length(HEADER)) || error("$txt: rows without $(length(HEADER)) columns")
t = Table(txt, HEADER, data; missing_values=(999999,))
keep = findall(i -> !ismissing(column(t, "age_top")[i]) && !ismissing(column(t, "age_bottom")[i]), 1:nrows(t))
println("$(nrows(t)) tubes, $(nrows(t) - length(keep)) without an age left out")
col(c) = column(t, c)[keep]
age_top, age_bot = 1000 .* nan64(col("age_top")), 1000 .* nan64(col("age_bottom"))
depth = (nan64(col("depth_top")) .+ nan64(col("depth_bottom"))) ./ 2

# AICC2023 ages of the tie points (ka b2k) along the WDC depth
ties = read_pangaea(download_dataset(manifest(), "aicc2023_wdc_ties"))
z_tie = nan64(column(ties, "Depth ice/snow [m] (WDC)"))
a_tie = 1000 .* nan64(column(ties, "Ice age [ka b2k] (AICC2023)")) .- B2K_TO_BP
issorted(z_tie) || error("$(ties.path): the WDC depths of the tie points are not sorted")

write_series(joinpath(prepared_dir("WAIS2015_WDC"), "WAIS2015_WDC.nc"); tag="icecores",
    sites=[SITE], time=(age_top .+ age_bot) ./ 2, time_bnds=permutedims(hcat(age_top, age_bot)),
    time_comment="WD2014 ice age of the middle of the tube (Buizert et al., 2015; Sigl et al., 2016), years before " *
                 "1950 CE; bounds: ages of the top and bottom of the tube",
    axis_vars=[Var("time_aicc2023", [interp_linear(z_tie, a_tie, z) for z in depth], "years ago",
                   "AICC2023 ice age of the middle of the tube, interpolated in depth between the WDC-EDC tie points " *
                   "of AICC2023 (Bouchet et al., 2023), years before 1950 CE"; T=Float64),
               Var("tube", col("tube"), "1", "number of the tube (about 1 m of core)"; T=Float64)],
    vars=[Var("depth", depth, "m", "depth in the core of the middle of the tube"; T=Float64, attrib=["positive" => "down"]),
          Var("depth_top", col("depth_top"), "m", "depth of the top of the tube"; T=Float64, attrib=["positive" => "down"]),
          Var("depth_bottom", col("depth_bottom"), "m", "depth of the bottom of the tube"; T=Float64, attrib=["positive" => "down"]),
          Var("d18O", col("d18O"), "1e-3", "delta-18O of the ice, mean of the tube, per mil VSMOW/SLAP")],
    title="WAIS Divide d18O, 68 kyr (WAIS Divide Project Members, 2015)",
    references="WAIS Divide Project Members: Precise interpolar phasing of abrupt climate change during the last ice " *
               "age, Nature, 520, 661-665, 2015, doi:10.1038/nature14401; WAIS Divide Project Members: Onset of " *
               "deglacial warming in West Antarctica driven by local orbital forcing, Nature, 500, 440-444, 2013, " *
               "doi:10.1038/nature12376; Steig, E. J. et al.: Recent climate and ice-sheet changes in West " *
               "Antarctica compared with the past 2000 years, Nat. Geosci., 6, 372-375, 2013, doi:10.1038/ngeo1778; " *
               "WD2014: Buizert, C. et al., Clim. Past, 11, 153-173, 2015, doi:10.5194/cp-11-153-2015; Sigl, M. et al., " *
               "Clim. Past, 12, 769-786, 2016, doi:10.5194/cp-12-769-2016. Data: Steig, " *
               "E. J. et al.: WAIS Divide Ice Core Oxygen Isotopes, USAP-DC, doi:10.7265/N5GT5K41",
    doi="10.7265/N5GT5K41", license="CC BY-NC 4.0 (USAP-DC)")
