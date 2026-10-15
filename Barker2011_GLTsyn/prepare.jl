# Prepare the synthetic Greenland record of Barker et al. (2011) as a record (see
# Records/README.md): Tables S2 and S3 of the supplement of the article (datamanifest key
# barker2011_gltsyn, manual download, re-saved as xlsx), the synthetic Greenland
# temperature record GLT_syn every 50 years from 5 to 800 ka, and the predicted
# Dansgaard-Oeschger events, as series of the region "Greenland (synthetic)" (featureType
# timeSeries), two files: $FESMDATA_PREPARED/Barker2011_GLTsyn/Barker2011_GLTsyn.nc and
# Barker2011_GLTsyn_events.nc.
#
# Usage:
#     julia --project=Barker2011_GLTsyn Barker2011_GLTsyn/prepare.jl
#     julia fesmdata.jl record IceCores Barker2011

using NCDatasets
using XLSX

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

const HEADER_S2 = ["EDC3 Age (kyr)", "SpeloAge (kyr)", "GLT_syn_hi", "GLT_syn_lo", "GLT_syn"]
const HEADER_S3 = ["Age kyr (EDC3)", "SpeloAge (kyr)", "DO pick", "DO pick variable threshold"]
const COMMON = (tag="icecores", sites=[Region("Greenland (synthetic)")], instance="region",
    references="Barker, S., Knorr, G., Edwards, R. L., Parrenin, F., Putnam, A. E., Skinner, L. C., Wolff, E., and " *
               "Ziegler, M.: 800,000 years of abrupt climate variability, Science, 334, 347-351, 2011, " *
               "doi:10.1126/science.1203580 (supplementary Tables S2 and S3)",
    doi="10.1126/science.1203580",
    license="Supplement of a Science article, no open licence stated; publishing assumed to be allowed")

xlsx = download_dataset(manifest(), "barker2011_gltsyn")
m = XLSX.readxlsx(xlsx)["Sheet1"][:]
h = findfirst(i -> string(m[i, 1]) == HEADER_S2[1], 1:size(m, 1))
h === nothing && error("$xlsx: no header row $(HEADER_S2[1])")
[string(m[h, j]) for j in 1:5] == HEADER_S2 || error("$xlsx: unexpected columns of Table S2: $(m[h, 1:5])")
[string(m[h, j]) for j in 8:11] == HEADER_S3 || error("$xlsx: unexpected columns of Table S3: $(m[h, 8:11])")
num(x) = x isa Number ? Float64(x) : missing
rows2 = [i for i in h+1:size(m, 1) if m[i, 1] isa Number && m[i, 5] isa Number]
rows3 = [i for i in h+1:size(m, 1) if m[i, 8] isa Number]
println("Table S2: $(length(rows2)) values, Table S3: $(length(rows3)) events")
col(j, rows) = num.(m[rows, j])

out = prepared_dir("Barker2011_GLTsyn")
write_series(joinpath(out, "Barker2011_GLTsyn.nc"); COMMON...,
    time=1000 .* nan64(col(1, rows2)),
    time_comment="EDC3 age (Parrenin et al., 2007), every 50 years, years before 1950 CE",
    axis_vars=[Var("time_speleo", 1000 .* nan64(col(2, rows2)), "years ago",
                   "age on the speleothem-based time scale of the article (to 400 ka), years before 1950 CE"; T=Float64)],
    vars=[Var("glt_syn", col(5, rows2), "1e-3", "synthetic Greenland temperature record GLT_syn, in units of the NGRIP d18O (per mil)"),
          Var("glt_syn_hi", col(3, rows2), "1e-3", "high-frequency (millennial) component of GLT_syn"),
          Var("glt_syn_lo", col(4, rows2), "1e-3", "low-frequency (orbital) component of GLT_syn")],
    title="Synthetic Greenland temperature record GLT_syn, 800 kyr (Barker et al., 2011)")
write_series(joinpath(out, "Barker2011_GLTsyn_events.nc"); COMMON...,
    axis="sample", time=1000 .* nan64(col(8, rows3)),
    time_comment="EDC3 age of the predicted Dansgaard-Oeschger warming, years before 1950 CE",
    axis_vars=[Var("time_speleo", 1000 .* nan64(col(9, rows3)), "years ago",
                   "age on the speleothem-based time scale of the article, years before 1950 CE"; T=Float64)],
    vars=[Var("do_pick", col(10, rows3), "1", "predicted Dansgaard-Oeschger event (1) or not (0), fixed threshold"; T=Int8),
          Var("do_pick_var", col(11, rows3), "1", "predicted Dansgaard-Oeschger event (1) or not (0), variable threshold"; T=Int8)],
    title="Predicted Dansgaard-Oeschger events of GLT_syn, 800 kyr (Barker et al., 2011)")
