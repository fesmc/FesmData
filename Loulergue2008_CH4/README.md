# EPICA Dome C methane, 800 kyr (Loulergue et al., 2008)

Atmospheric CH4 from the EPICA Dome C ice core (75.1°S, 123.4°E, 3240 m) over the last
800 kyr on the EDC3 gas age. From:

Loulergue, L., Schilt, A., Spahni, R., Masson-Delmotte, V., Blunier, T., Lemieux, B.,
Barnola, J.-M., Raynaud, D., Stocker, T. F., and Chappellaz, J.: Orbital and
millennial-scale features of atmospheric CH4 over the past 800,000 years, Nature, 453,
383-386, 2008, [doi:10.1038/nature06950](https://doi.org/10.1038/nature06950).

Data: EPICA Dome C Ice Core 800KYr Methane Data, NOAA NCEI,
[doi:10.25921/gfsj-jc86](https://doi.org/10.25921/gfsj-jc86).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publication and
the dataset. We assume the data may be published.

## Original data

`edc-ch4-2008-noaa.txt` (NOAA template), downloaded by `prepare.jl` (datamanifest key
`loulergue2008_ch4`): depth (EDC99, m), EDC3 gas age (years before 1950), CH4 (ppb) and
its 1σ uncertainty, and the laboratory (Bern or Grenoble; the Grenoble values are
corrected by +6 ppb). Newer EDC methane of some intervals (Nehrbass-Ahles et al., 2020;
Shin et al., 2021; Schmidely et al., 2021) is not included.

## Prepare and record

```bash
julia --project=Loulergue2008_CH4 Loulergue2008_CH4/prepare.jl
julia fesmdata.jl record GHG Loulergue2008
```

`prepare.jl` writes `$FESMDATA_PREPARED/Loulergue2008_CH4/Loulergue2008_CH4.nc` (see
`Records/README.md`), a time series at EDC (featureType timeSeries) of 2103 values:
`ch4`, `ch4_sd` (ppb), `lab` (1 Bern, 2 Grenoble), `depth` (m), `time` (EDC3 gas age)
and `time_aicc2023` (AICC2023 gas age at the same depth, from `Bouchet2023_AICC2023`;
missing where the AICC2023 table has no gas age).
