# Vostok deuterium and temperature, 420 kyr (Petit et al., 1999)

δD of the Vostok ice core (78.47°S, 106.8°E, 3488 m) every 1 m, and the temperature
anomaly derived from it, over the last 420 kyr on the GT4 time scale. From:

Petit, J. R. et al.: Climate and atmospheric history of the past 420,000 years from the
Vostok ice core, Antarctica, Nature, 399, 429-436, 1999,
[doi:10.1038/20859](https://doi.org/10.1038/20859).

Data: Vostok Ice Core Data for 420,000 Years, NOAA NCEI,
[doi:10.25921/kcry-ae86](https://doi.org/10.25921/kcry-ae86).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publication and
the dataset. We assume the data may be published.

## Original data

`deutnat-noaa.txt` (NOAA template), downloaded by `prepare.jl` (datamanifest key
`petit1999_vostok`): depth (m), GT4 ice age (years before 1950), δD (‰ SMOW), temperature
anomaly (°C, relative to the present, δD of -438 ‰). The CO2 and CH4 of the same work
are in the composites of the GHG dataset; δD on AICC2012 is on PANGAEA
(doi:10.1594/PANGAEA.824892).

## Prepare and record

```bash
julia --project=Petit1999_Vostok Petit1999_Vostok/prepare.jl
julia fesmdata.jl record IceCores Petit1999
```

`prepare.jl` writes `$FESMDATA_PREPARED/Petit1999_Vostok/Petit1999_Vostok.nc` (see
`Records/README.md`), a time series at Vostok (featureType timeSeries) of 3311 depths:
`dD` (‰), `tas_anom` (K), `depth` (m), `time` (GT4) and `time_aicc2023` (AICC2023 age
at the same depth, from `Bouchet2023_AICC2023`; missing below 3272 m, the bottom of the
AICC2023 table).
