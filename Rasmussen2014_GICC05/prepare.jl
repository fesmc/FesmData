# Prepare the synchronized Greenland d18O and calcium records of Rasmussen et al. (2014)
# and Seierstad et al. (2014) as a record (see Records/README.md): the 20-year means of
# NGRIP (NGRIP1 and NGRIP2 cores), GRIP and GISP2 on GICC05modelext (sheet 3 of the
# workbook of the Centre for Ice and Climate, datamanifest key rasmussen2014_gicc05),
# 20 ka b2k to 122 ka, as time series at the cores (featureType timeSeries),
# $FESMDATA_PREPARED/Rasmussen2014_GICC05/Rasmussen2014_GICC05.nc.
#
# Usage:
#     julia --project=Rasmussen2014_GICC05 Rasmussen2014_GICC05/prepare.jl
#     julia fesmdata.jl record IceCores Rasmussen2014
#
# The sheet is in step form: each 20-year interval is two rows, at its top and bottom age
# and depth, with the same values. The rows at the bottom are taken: `time` is the middle
# of the interval, `time_bnds` its top and bottom, `depth` the depth of its bottom.

using NCDatasets
using XLSX

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

const DT = 20.0                 # years, length of the intervals

# Cores, with their columns (depth, d18O, [Ca2+]; nothing: not given) in the sheet. The
# NGRIP1 core reaches 1372 m; the NGRIP2 data start at 1346 m. NGRIP1 and NGRIP2 are 20 m
# apart (their depths are offset by 0.43 m on average in the overlap).
const CORES = [
    (site=Site("NGRIP1", 75.10, -42.32; z_srf=2917.0), cols=(2, 3, nothing), aicc="NGRIP"),
    (site=Site("NGRIP2", 75.10, -42.32; z_srf=2917.0), cols=(4, 5, 6), aicc="NGRIP"),
    (site=Site("GRIP", 72.58, -37.64; z_srf=3232.0), cols=(7, 8, 9), aicc=nothing),
    (site=Site("GISP2", 72.58, -38.48; z_srf=3200.0), cols=(10, 11, 12), aicc=nothing),
]
const HEADER = ["Age", "NGRIP1 depth", "d18O NGRIP1", "NGRIP2 depth", "d18O NGRIP2", "[Ca2+] NGRIP2", "GRIP depth",
                "d18O GRIP", "[Ca2+] GRIP", "GISP2 depth", "d18O GISP2", "[Ca2+] GISP2", "MCE"]

xlsx = download_dataset(manifest(), "rasmussen2014_gicc05")
m = XLSX.readxlsx(xlsx)["3) d18O and Ca 20 yrs mean"][:]
h = findfirst(i -> strip(string(m[i, 1])) == "Age", 1:size(m, 1))
h === nothing && error("$xlsx: no header row starting with Age")
[strip(replace(string(m[h, j]), "δ" => "d")) for j in eachindex(HEADER)] == HEADER ||
    error("$xlsx: unexpected columns $(m[h, eachindex(HEADER)])")
num(x) = x isa Number && !(x isa AbstractFloat && isnan(x)) ? Float64(x) : missing
rows = [i for i in h+2:size(m, 1) if m[i, 1] isa Number]
top, bot = rows[1:2:end], rows[2:2:end]
length(top) == length(bot) && all(Float64.(m[bot, 1]) .- Float64.(m[top, 1]) .== DT) ||
    error("$xlsx: the rows are not pairs of top and bottom of 20-year intervals")
for j in (3, 5, 6, 8, 9, 11, 12)   # the data (not the depths and MCE) are the same at the top and bottom
    all(isequal.(num.(m[top, j]), num.(m[bot, j]))) ||
        error("$xlsx: column $(HEADER[j]) differs between the top and bottom of an interval")
end
col(j) = j === nothing ? fill(missing, length(bot)) : num.(m[bot, j])
age = Float64.(m[bot, 1])                     # bottom of the interval, years b2k
depth = hcat((col(c.cols[1]) for c in CORES)...)

write_series(joinpath(prepared_dir("Rasmussen2014_GICC05"), "Rasmussen2014_GICC05.nc"); tag="icecores",
    sites=[c.site for c in CORES], time=age .- DT / 2 .- B2K_TO_BP,
    time_bnds=permutedims(hcat(age .- DT .- B2K_TO_BP, age .- B2K_TO_BP)),
    time_comment="middle of the 20-year interval, GICC05modelext, converted from years b2k (before 2000 CE) " *
                 "by subtracting 50",
    axis_vars=[Var("mce", col(13), "yr", "maximum counting error of GICC05 at the bottom of the interval (about 2 sigma; to 60 ka b2k only)")],
    vars=[Var("depth", depth, "m", "depth in the core of the bottom of the 20-year interval"; T=Float64,
              attrib=["positive" => "down"]),
          Var("time_aicc2023", hcat((c.aicc === nothing ? fill(NaN, length(bot)) : aicc2023_age(c.aicc, depth[:, k])
                                     for (k, c) in enumerate(CORES))...), "years ago",
              "AICC2023 ice age at the bottom of the interval (Bouchet et al., 2023), years before 1950 CE (NGRIP only)";
              T=Float64),
          Var("d18O", hcat((col(c.cols[2]) for c in CORES)...), "1e-3", "delta-18O of the ice, 20-year mean, per mil"),
          Var("ca", hcat((col(c.cols[3]) for c in CORES)...), "ng g-1", "calcium concentration [Ca2+], 20-year mean")],
    title="NGRIP, GRIP and GISP2 d18O and calcium, 20-year means on GICC05modelext (Rasmussen et al., 2014; " *
          "Seierstad et al., 2014)",
    references="Rasmussen, S. O. et al.: A stratigraphic framework for abrupt climatic changes during the Last " *
               "Glacial period based on three synchronized Greenland ice-core records: refining and extending the " *
               "INTIMATE event stratigraphy, Quat. Sci. Rev., 106, 14-28, 2014, doi:10.1016/j.quascirev.2014.09.007; " *
               "Seierstad, I. K. et al.: Consistently dated records from the Greenland GRIP, GISP2 and NGRIP ice " *
               "cores for the past 104 ka reveal regional millennial-scale d18O gradients with possible Heinrich " *
               "event imprint, Quat. Sci. Rev., 106, 29-46, 2014, doi:10.1016/j.quascirev.2014.10.032. d18O: " *
               "North Greenland Ice Core Project members, Nature, 431, 147-151, 2004; Johnsen et al., J. Geophys. " *
               "Res., 102, 26397-26410, 1997; Grootes and Stuiver, J. Geophys. Res., 102, 26455-26470, 1997; " *
               "Stuiver and Grootes, Quat. Res., 53, 277-284, 2000. Calcium: Bigler (2004), Fuhrer et al. (1993), " *
               "Mayewski et al. (1997). Data: Centre for Ice and Climate, University of Copenhagen, " *
               "https://www.iceandclimate.nbi.ku.dk/data/ (version of 10 December 2014)",
    doi="10.1016/j.quascirev.2014.09.007",
    license="No licence stated (Centre for Ice and Climate: cite the publications); publishing assumed to be allowed")
