# EPICA Dome C nitrous oxide, 800 kyr (Schilt et al., 2010)

Atmospheric N2O from the EPICA Dome C ice core over the last 800 kyr on the EDC3 gas age,
with the data of earlier works for parts of the record. From:

Schilt, A., Baumgartner, M., Blunier, T., Schwander, J., Spahni, R., Fischer, H., and
Stocker, T. F.: Glacial-interglacial and millennial-scale variations in the atmospheric
nitrous oxide concentration during the last 800,000 years, Quat. Sci. Rev., 29, 182-192,
2010, [doi:10.1016/j.quascirev.2009.03.011](https://doi.org/10.1016/j.quascirev.2009.03.011);
with Spahni et al. (2005, MIS 3-7.3 and 13-15), Flückiger et al. (2002, Holocene) and
Stauffer et al. (2002, last deglaciation).

Data: EPICA Dome C Ice Core 800KYr N2O Data, IGBP PAGES/World Data Center for
Paleoclimatology Data Contribution Series # 2010-005, NOAA NCEI (no dataset DOI).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publications.
We assume the data may be published.

## Original data

`edc-n2o-2010-800k.txt` (free-text NOAA file), downloaded by `prepare.jl` (datamanifest
key `schilt2010_n2o`): depth on EDC96 and EDC99 (m), EDC3 gas age (years before 1950),
N2O (ppb), N2O values identified as artifacts (ppb), and the 1σ uncertainty (ppb); NaN
for missing values. The Talos Dome N2O of Schilt et al. (2010, EPSL) is not included.

## Prepare and record

```bash
julia --project=Schilt2010_N2O Schilt2010_N2O/prepare.jl
julia fesmdata.jl record GHG Schilt2010
```

`prepare.jl` writes `$FESMDATA_PREPARED/Schilt2010_N2O/Schilt2010_N2O.nc` (see
`Records/README.md`), a time series at EDC (featureType timeSeries) of 912 values:
`n2o` (ppb, missing where the value is an artifact), `n2o_artifact`, `n2o_sd` (ppb),
`depth` (EDC99, m), `time` (EDC3 gas age) and `time_aicc2023` (AICC2023 gas age at the
same depth, from `Bouchet2023_AICC2023`). The site location is that of the other EDC
files of NOAA NCEI (this file gives none).
