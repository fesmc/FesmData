# Seasonal temperatures at Greenland ice core sites, 22 ka to present (Buizert et al., 2018)

Annual and seasonal mean surface air temperatures every 20 years from 22 ka to present at
nine Greenland ice core sites (NEEM, NGRIP, GISP2, Dye-3, ReCAP/Renland, Agassiz, Hans
Tausen, Camp Century, EGRIP), from the reconstruction of:

Buizert, C., Keisling, B. A., Box, J. E., He, F., Carlson, A. E., Sinclair, G., and
DeConto, R. M.: Greenland-wide seasonal temperatures during the last deglaciation,
Geophys. Res. Lett., 45, 1905-1914, 2018,
[doi:10.1002/2017GL075601](https://doi.org/10.1002/2017GL075601).

Data: NOAA/WDS Paleoclimatology, Greenland 22,000 Year Seasonal Temperature
Reconstructions, NOAA NCEI, [doi:10.25921/psvs-yg80](https://doi.org/10.25921/psvs-yg80).
The gridded reconstruction is `Paleoclimate-Buizert2018` (`../Buizert2018`).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publication and
the dataset. We assume the data may be published.

## Original data

`buizert2018cores.txt` of the NCEI archive,
https://www.ncei.noaa.gov/pub/data/paleo/reconstructions/buizert2018/ (no login),
downloaded by `prepare.jl` (datamanifest key `buizert2018_cores`): a block of six
tab-separated columns per site (age in years BP, annual, DJF, MAM, JJA and SON
temperatures in °C), with the site location and elevation above. No correction is made
for ice flow or elevation change.

The temperatures of Buizert et al. (2014, Science, doi:10.1126/science.1254961) at
Summit, NGRIP and NEEM are only in the supplement of the article and are not used.

## Prepare and record

```bash
julia --project=Buizert2018_cores Buizert2018_cores/prepare.jl
julia fesmdata.jl record IceCores Buizert2018
```

`prepare.jl` writes `$FESMDATA_PREPARED/Buizert2018_cores/Buizert2018_cores.nc` (see
`Records/README.md`), time series at the nine sites (featureType timeSeries, with `lat`,
`lon`, `z_srf` of the table): `tas_ann`, `tas_djf`, `tas_mam`, `tas_jja`, `tas_son` (K,
from °C) and `time` (years before 1950 CE, every 20 years from -50).
