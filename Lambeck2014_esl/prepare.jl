# Prepare the ice-volume equivalent sea level of Lambeck et al. (2014) as a record (see
# Records/README.md): Table S3 of the supporting information of the article (PDF,
# datamanifest key lambeck2014_esl, manual download), the equivalent sea level from 35 ka
# to the present with its accuracy, as a global series (featureType timeSeries),
# $FESMDATA_PREPARED/Lambeck2014_esl/Lambeck2014_esl.nc.
#
# Usage:
#     julia --project=Lambeck2014_esl Lambeck2014_esl/prepare.jl
#     julia fesmdata.jl record SeaLevel Lambeck2014
#
# The text of the PDF is extracted with pdftotext (poppler, -layout); the table is the
# lines of four numbers after "Table S3." (page breaks in between).

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

pdf = download_dataset(manifest(), "lambeck2014_esl")
Sys.which("pdftotext") === nothing && error("pdftotext (poppler) is needed to read $pdf")
lines = split(read(`pdftotext -layout $pdf -`, String), '\n')
i0 = findfirst(l -> startswith(strip(l), "Table S3."), lines)
i0 === nothing && error("$pdf: no Table S3")
startswith(strip(lines[i0+1]), "Best estimates of the ice-volume equivalent sea-level function (esl)") ||
    error("$pdf: Table S3 is not the equivalent sea level: $(lines[i0+1])")
row = r"^\s*([0-9.]+)\s+(-?[0-9.]+)\s+(-?[0-9.]+)\s+([0-9.]+)\s*$"
rows = [parse.(Float64, m.captures) for l in lines[i0:end] for m in (match(row, l),) if m !== nothing]
time = 1000 .* [r[1] for r in rows]
all(diff(time) .> 0) || error("$pdf: the times of Table S3 are not increasing")
println("Table S3: $(length(rows)) rows, $(time[1])-$(time[end]) years")

write_series(joinpath(prepared_dir("Lambeck2014_esl"), "Lambeck2014_esl.nc"); tag="sealevel",
    sites=[Region("global")], instance="region", time,
    time_comment="calibrated ages, years before present (1950 CE)",
    vars=[Var("sl", [r[3] for r in rows], "m", "ice-volume equivalent sea level relative to the present, best estimate"),
          Var("sl_sd", [r[4] / 2 for r in rows], "m", "uncertainty (1 sigma, half the 2-sigma accuracy estimate of the source) of sl"),
          Var("sl_nominal", [r[2] for r in rows], "m", "nominal equivalent sea level of the starting ice model")],
    title="Ice-volume equivalent sea level, 35 ka to present (Lambeck et al., 2014)",
    references="Lambeck, K., Rouby, H., Purcell, A., Sun, Y., and Sambridge, M.: Sea level and global ice volumes " *
               "from the Last Glacial Maximum to the Holocene, Proc. Natl. Acad. Sci. USA, 111, 15296-15303, 2014, " *
               "doi:10.1073/pnas.1411762111 (supporting information, Table S3)",
    doi="10.1073/pnas.1411762111",
    license="Supporting information of a PNAS article, no open licence stated; publishing assumed to be allowed")
