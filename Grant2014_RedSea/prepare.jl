# Prepare the Red Sea relative sea level of Grant et al. (2014) as a record (see
# Records/README.md): Supplementary Data 1 of the article (datamanifest key
# grant2014_redsea), the probabilistic record every 125 years over 492 kyr and the data
# points, as time series at the Hanish Sill (featureType timeSeries), two files:
# $FESMDATA_PREPARED/Grant2014_RedSea/Grant2014_RedSea_probabilistic.nc and
# Grant2014_RedSea_data.nc.
#
# Usage:
#     julia --project=Grant2014_RedSea Grant2014_RedSea/prepare.jl
#     julia fesmdata.jl record SeaLevel Grant2014

using NCDatasets
using XLSX

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

# The Hanish Sill, the sill of the Red Sea of which the record is the relative sea level
const SITE = Site("Red Sea (Hanish Sill)", 13.7, 42.7)
const HEADER = ["Age_kaBP", "RSL datapoints_m", "time_kyr", "RSL_95low_m", "RSL_95high_m", "RSL_Pmax_m",
                "RSL_Pmax95high_m", "RSL_Pmax95low_m", "dRSL_Pmax_m/kyr", "dRSL_Pmax95low_m/kyr", "dRSL_Pmax95high_m/kyr"]
const COMMON = (tag="sealevel", sites=[SITE], site_long_name="site of the relative sea level record",
    references="Grant, K. M., Rohling, E. J., Ramsey, C. B., Cheng, H., Edwards, R. L., Florindo, F., Heslop, D., " *
               "Marra, F., Roberts, A. P., Tamisiea, M. E., and Williams, F.: Sea-level variability over five " *
               "glacial cycles, Nat. Commun., 5, 5076, 2014, doi:10.1038/ncomms6076 (Supplementary Data 1); " *
               "0-150 ka: Grant, K. M. et al.: Rapid coupling between ice volume and polar temperature over the past " *
               "150,000 years, Nature, 491, 744-747, 2012, doi:10.1038/nature11593",
    doi="10.1038/ncomms6076",
    license="Supplement of a Nature Communications article, no open licence stated; publishing assumed to be allowed")

xlsx = download_dataset(manifest(), "grant2014_redsea")
m = XLSX.readxlsx(xlsx)["Sheet1"][:]
h = findfirst(i -> string(m[i, 1]) == "Age_kaBP", 1:size(m, 1))
h === nothing && error("$xlsx: no header row Age_kaBP")
[string(m[h, j]) for j in eachindex(HEADER)] == HEADER || error("$xlsx: unexpected columns $(m[h, eachindex(HEADER)])")
num(x) = x isa Number ? Float64(x) : missing
col(j, rows) = num.(m[rows, j])
# The probabilistic record (columns C-K) and the data points (A-B) have their own rows
rows_p = [i for i in h+1:size(m, 1) if m[i, 3] isa Number]
rows_d = [i for i in h+1:size(m, 1) if m[i, 1] isa Number]
# The labels of the bounds of the probability maximum (G, H) are swapped in the
# description of the sheet: check that G is the upper bound
hi, lo = col(7, rows_p), col(8, rows_p)
count(coalesce.(hi .>= lo, true)) == length(rows_p) || error("$xlsx: RSL_Pmax95high_m is not always >= RSL_Pmax95low_m")

out = prepared_dir("Grant2014_RedSea")
write_series(joinpath(out, "Grant2014_RedSea_probabilistic.nc"); COMMON...,
    time=1000 .* nan64(col(3, rows_p)),
    time_comment="every 125 years; chronology of Grant et al. (2012) to 150 ka and of Grant et al. (2014) beyond, " *
                 "years before 1950 CE",
    vars=[Var("rsl", col(6, rows_p), "m", "relative sea level of the Red Sea, probability maximum"),
          Var("rsl_min", lo, "m", "lower bound of the 95% probability interval of rsl"),
          Var("rsl_max", hi, "m", "upper bound of the 95% probability interval of rsl"),
          Var("rsl_data_min", col(4, rows_p), "m", "lower bound of the 95% probability interval of the data"),
          Var("rsl_data_max", col(5, rows_p), "m", "upper bound of the 95% probability interval of the data"),
          Var("drsl", col(9, rows_p), "m kyr-1", "rate of change of rsl, probability maximum"),
          Var("drsl_min", col(10, rows_p), "m kyr-1", "lower bound of the 95% probability interval of drsl"),
          Var("drsl_max", col(11, rows_p), "m kyr-1", "upper bound of the 95% probability interval of drsl")],
    title="Red Sea relative sea level, probabilistic record, 492 kyr (Grant et al., 2014)")
age = 1000 .* nan64(col(1, rows_d))
idx = sortperm(age)
write_series(joinpath(out, "Grant2014_RedSea_data.nc"); COMMON...,
    axis="sample", time=age[idx],
    time_comment="chronology of Grant et al. (2012) to 150 ka and of Grant et al. (2014) beyond, years before 1950 CE",
    vars=[Var("rsl", col(2, rows_d)[idx], "m", "relative sea level of the Red Sea, data points")],
    title="Red Sea relative sea level, data points, 492 kyr (Grant et al., 2014)")
