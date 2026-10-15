# EDML d18O, 150 kyr (EPICA Community Members, 2006)

δ18O of the EPICA Dronning Maud Land ice core (75.00°S, 0.07°E, 2892 m) in 0.5 m samples
over the last 150 kyr on the EDML1 time scale, with its corrections for the isotopic
composition of sea water and the elevation of the site. From:

EPICA Community Members: One-to-one coupling of glacial climate variability in Greenland
and Antarctica, Nature, 444, 195-198, 2006,
[doi:10.1038/nature05301](https://doi.org/10.1038/nature05301).

Data: EPICA Community Members: Stable oxygen isotopes of ice core EDML, PANGAEA, 2010,
[doi:10.1594/PANGAEA.754444](https://doi.org/10.1594/PANGAEA.754444) (version 2, which
replaces doi:10.1594/PANGAEA.552270).

## Licence

CC BY 3.0 (PANGAEA).

## Original data

The tab-delimited text of the PANGAEA dataset (no login), downloaded by `prepare.jl`
(datamanifest key `epica2006_edml`): middle, top and bottom depth (m), EDML1 age and
its range (ka BP), δ18O measured (‰ SMOW), δ18O corrected for sea water, and for sea
water and elevation, the mean δ18O of sea water, and the elevation change (m). Two
columns have the same (truncated) name: the columns are read by position, after a check
of the header.

## Prepare and record

```bash
julia --project=EPICA2006_EDML EPICA2006_EDML/prepare.jl
julia fesmdata.jl record IceCores EPICA2006
```

`prepare.jl` writes `$FESMDATA_PREPARED/EPICA2006_EDML/EPICA2006_EDML.nc` (see
`Records/README.md`), a time series at EDML (featureType timeSeries) of 4832 samples:
`d18O`, `d18O_swcor`, `d18O_swaltcor`, `d18O_sw` (‰), `dz_srf` (m), `depth` (m, middle of
the sample), `time` (EDML1 age of the middle, with `time_bnds` from the ages of the top
and bottom) and `time_aicc2023` (AICC2023 age at the middle, from `Bouchet2023_AICC2023`;
missing above 18 m, the top of its table).
