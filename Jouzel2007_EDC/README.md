# EPICA Dome C deuterium and temperature, 800 kyr (Jouzel et al., 2007)

δD of the EPICA Dome C ice core (75.1°S, 123.4°E, 3240 m) in 0.55 m bags, and the
temperature anomaly derived from it, over the last 800 kyr on the EDC3 time scale. From:

Jouzel, J. et al.: Orbital and millennial Antarctic climate variability over the past
800,000 years, Science, 317, 793-796, 2007,
[doi:10.1126/science.1141038](https://doi.org/10.1126/science.1141038).

Data: EPICA Dome C Ice Core 800KYr Deuterium Data and Temperature Estimates, NOAA NCEI,
[doi:10.25921/8t7e-z147](https://doi.org/10.25921/8t7e-z147).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publication and
the dataset. We assume the data may be published.

## Original data

`edc3deuttemp2007-noaa.txt` (NOAA template, revised 26 November 2007 with the EDC3 ages;
the version of 16 October 2007 had the wrong age scale), downloaded by `prepare.jl`
(datamanifest key `jouzel2007_edc`): bag number, top depth (m), EDC3 age (years before
1950), δD (‰ VSMOW), temperature anomaly (°C, relative to the mean of the last 1000
years, corrected for the isotopic composition of sea water and the elevation of the
ice sheet). The same data are on PANGAEA (doi:10.1594/PANGAEA.683655), and on AICC2012
(doi:10.1594/PANGAEA.824891).

## Prepare and record

```bash
julia --project=Jouzel2007_EDC Jouzel2007_EDC/prepare.jl
julia fesmdata.jl record IceCores Jouzel2007
```

`prepare.jl` writes `$FESMDATA_PREPARED/Jouzel2007_EDC/Jouzel2007_EDC.nc` (see
`Records/README.md`), a time series at EDC (featureType timeSeries) of 5800 bags:
`dD` (‰), `tas_anom` (K), `depth` (m, top of the bag), `time` (EDC3 age at the top of
the bag) and `time_aicc2023` (AICC2023 age at the same depth, from
`Bouchet2023_AICC2023`). The first bags have no data (missing values).
