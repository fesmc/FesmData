# Ice-volume equivalent sea level, 35 ka to present (Lambeck et al., 2014)

The ice-volume equivalent sea level from the Last Glacial Maximum to the present,
inferred from about 1000 sea-level indicators with a model of glacial isostatic
adjustment, with its accuracy. From:

Lambeck, K., Rouby, H., Purcell, A., Sun, Y., and Sambridge, M.: Sea level and global ice
volumes from the Last Glacial Maximum to the Holocene, Proc. Natl. Acad. Sci. USA, 111,
15296-15303, 2014, [doi:10.1073/pnas.1411762111](https://doi.org/10.1073/pnas.1411762111).

## Licence

Supporting information of a PNAS article: no open licence stated. We assume the data may
be published.

## Original data

Table S3 of the supporting information, `pnas.1411762111.sapp.pdf` (datamanifest key
`lambeck2014_esl`): time (ka), the nominal equivalent sea level of the starting ice model,
the best estimate of the equivalent sea level (esl, m) and its accuracy (2σ, m), 326 rows
from 0 to 34.8 ka. The PNAS site refuses scripted downloads: download the PDF by hand from
the supporting information of the article and put it in
`$FESMDATA_SOURCES/lambeck2014_esl/`.

## Prepare and record

```bash
julia --project=Lambeck2014_esl Lambeck2014_esl/prepare.jl
julia fesmdata.jl record SeaLevel Lambeck2014
```

`prepare.jl` extracts the text of the PDF with `pdftotext -layout` (poppler; on Levante
in the mambaforge module) and reads the rows of four numbers after "Table S3.". It writes
`$FESMDATA_PREPARED/Lambeck2014_esl/Lambeck2014_esl.nc` (see `Records/README.md`), a
global series (dimension `region`, no location): `sl` (m, -132 m at 20 ka), `sl_sd` (m,
1σ: half the 2σ of the table) and `sl_nominal` (m).
