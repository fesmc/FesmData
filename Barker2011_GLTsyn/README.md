# Synthetic Greenland temperature record GLT_syn, 800 kyr (Barker et al., 2011)

The synthetic Greenland temperature record GLT_syn, constructed from the EPICA Dome C
temperature record with the thermal bipolar seesaw, every 50 years from 5 to 800 ka on
EDC3 (and on the speleothem-based time scale of the article to 400 ka), with its high-
and low-frequency components, and the predicted Dansgaard-Oeschger events. From:

Barker, S., Knorr, G., Edwards, R. L., Parrenin, F., Putnam, A. E., Skinner, L. C., Wolff,
E., and Ziegler, M.: 800,000 years of abrupt climate variability, Science, 334, 347-351,
2011, [doi:10.1126/science.1203580](https://doi.org/10.1126/science.1203580).

## Licence

Supplementary material of a Science article: no open licence stated. We assume the data
may be published.

## Original data

Tables S2 and S3 of the supplementary material (datamanifest key `barker2011_gltsyn`),
manual steps:

1. Download `1203580-barker_tables_s2-s3.zip` from the supplementary material of the
   article (the site of Science refuses scripted downloads; the data are in no data
   centre).
2. Unzip it: `1203580s2.xls`, in the Excel 97-2003 format, which Julia does not read.
3. Open it in Excel and save it again as `1203580s2.xlsx` (values unchanged), in
   `$FESMDATA_SOURCES/barker2011_gltsyn/`.

Sheet 1 has Table S2 (EDC3 age and speleothem age in kyr, GLT_syn_hi, GLT_syn_lo,
GLT_syn) and, next to it, Table S3 (EDC3 and speleothem ages of the predicted
Dansgaard-Oeschger events, picked with a fixed and a variable threshold).

## Prepare and record

```bash
julia --project=Barker2011_GLTsyn Barker2011_GLTsyn/prepare.jl
julia fesmdata.jl record IceCores Barker2011
```

`prepare.jl` writes two files in `$FESMDATA_PREPARED/Barker2011_GLTsyn/` (see
`Records/README.md`), series of the region "Greenland (synthetic)" (featureType
timeSeries, dimension `region`, no location), the two parts of the product:

- `Barker2011_GLTsyn.nc`: 15861 values every 50 years: `glt_syn`, `glt_syn_hi`,
  `glt_syn_lo` (‰, in the units of the NGRIP δ18O), `time` (EDC3) and `time_speleo`
  (missing beyond 400 ka);
- `Barker2011_GLTsyn_events.nc`: the 126 events (dimension `sample`): `do_pick`,
  `do_pick_var` (1: event, 0: none), `time` (EDC3) and `time_speleo`.

GLT_syn has no AICC2023 ages: it is on EDC3 without depths (the EDC3-AICC2023
differences are those of the EDC records, see IceCores-Jouzel2007).
