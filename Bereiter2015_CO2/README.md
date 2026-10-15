# Antarctic ice core CO2 composite, 800 kyr (Bereiter et al., 2015)

The revised composite of atmospheric CO2 from Antarctic ice cores over the last 800 kyr
(Law Dome, EDC, WAIS Divide, Siple Dome, TALDICE, EDML, Vostok), which replaces the
composite of Lüthi et al. (2008). From:

Bereiter, B., Eggleston, S., Schmitt, J., Nehrbass-Ahles, C., Stocker, T. F., Fischer,
H., Kipfstuhl, S., and Chappellaz, J.: Revision of the EPICA Dome C CO2 record from 800
to 600 kyr before present, Geophys. Res. Lett., 42, 542-549, 2015,
[doi:10.1002/2014GL061957](https://doi.org/10.1002/2014GL061957).

Data: Antarctic Ice Cores Revised 800KYr CO2 Data, NOAA NCEI,
[doi:10.25921/n8y4-bp27](https://doi.org/10.25921/n8y4-bp27).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publication and
the dataset. We assume the data may be published.

## Original data

`antarctica2015co2composite-noaa.txt` (NOAA template), downloaded by `prepare.jl`
(datamanifest key `bereiter2015_co2`): gas age (years before 1950), CO2 (ppm) and its
1σ uncertainty (the mean of the system or record where not given individually). The
gas ages are on AICC2012, except for Law Dome, WAIS Divide and Siple Dome (their own time
scales). The composite gives neither the core nor the depth of a value (the per-core
files in the same folder do), so it has no AICC2023 ages.

## Prepare and record

```bash
julia --project=Bereiter2015_CO2 Bereiter2015_CO2/prepare.jl
julia fesmdata.jl record GHG Bereiter2015
```

`prepare.jl` writes `$FESMDATA_PREPARED/Bereiter2015_CO2/Bereiter2015_CO2.nc` (see
`Records/README.md`), a series of the region "Antarctic ice cores" (featureType
timeSeries, dimension `region`, no location) of 1901 values: `co2`, `co2_sd` (ppm) and
`time` (gas age, years before 1950 CE).
