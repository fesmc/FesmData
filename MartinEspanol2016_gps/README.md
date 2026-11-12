# Elastic-corrected GPS vertical velocities of Antarctica (Martín-Español et al., 2016)

Vertical velocities of 67 GPS stations in Antarctica (ANET/POLENET and other networks),
from the data of 2009-2014 in ITRF2008, **corrected** for the elastic response to the
Antarctic ice mass changes of the period (computed with REAR from the RATES mass
trends) and for atmospheric pressure loading, as observational estimates of glacial
isostatic adjustment (GIA) uplift rates. From:

Martín-Español, A., King, M. A., Zammit-Mangion, A., Andrews, S. B., Moore, P., and
Bamber, J. L.: An assessment of forward and inverse GIA solutions for Antarctica, J.
Geophys. Res. Solid Earth, 121, 6947-6965, 2016,
[doi:10.1002/2016JB013154](https://doi.org/10.1002/2016JB013154).

Only the elastic correction for the Antarctic ice is applied (not for the far-field
ice and water changes). For the station near Dumont d'Urville the article uses the
pre-1998 DORIS velocity (see the article).

## Licence

CC BY 4.0: the article and its supporting information are open access under CC BY 4.0
(also in PubMed Central, PMC5111427).

## Original data

Table S1 of the supporting information, `JGRB-121-6947-s002.xlsx`, from the open-access
copy of PubMed Central
(<https://pmc-oa-opendata.s3.amazonaws.com/PMC5111427.1/JGRB-121-6947-s002.xlsx>, no
login; the publisher's site refuses scripted downloads), downloaded by `prepare.jl`
(datamanifest key `martinespanol2016_gps`): site, latitude, longitude (0-360°), start
and end of the series used (decimal years), number of days, DOI of the RINEX data, the
observed (elastic-corrected) rate and its standard deviation, and the rates of 8 GIA
solutions (mm/yr).

## Prepare and record

```bash
julia --project=MartinEspanol2016_gps MartinEspanol2016_gps/prepare.jl
julia fesmdata.jl record GPS MartinEspanol2016
```

`prepare.jl` writes `$FESMDATA_PREPARED/MartinEspanol2016_gps/MartinEspanol2016_GPS.nc`,
one value per station (featureType point, dimension `station`): `uplift_rate` and
`uplift_rate_sd` (mm yr-1), `time_start` and `time_end` (decimal years), `lat`, `lon` (in
-180:180) and `site_name`. The rates of the GIA solutions are left out.
