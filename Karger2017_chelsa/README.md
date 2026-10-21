# CHELSA V2.1 climatologies (Karger et al., 2017)

Monthly climatologies 1981-2010 of the near-surface air temperature (mean, daily maximum
and minimum) and of the precipitation, downscaled from ERA-Interim to 30 arc seconds
(about 1 km) with the orography (CHELSA, Climatologies at high resolution for the
earth's land surface areas), here over the Pyrenees:

Karger, D. N., Conrad, O., Böhner, J., Kawohl, T., Kreft, H., Soria-Auza, R. W.,
Zimmermann, N. E., Linder, H. P., and Kessler, M.: Climatologies at high resolution for
the earth's land surface areas, Sci. Data, 4, 170122, 2017,
[doi:10.1038/sdata.2017.122](https://doi.org/10.1038/sdata.2017.122).

Data: CHELSA V2.1, EnviDat,
[doi:10.16904/envidat.228](https://doi.org/10.16904/envidat.228).

## Licence

CC0 1.0 (EnviDat record and the CHELSA website): no restrictions; cite the article and
the data.

## Original data

Global Cloud-Optimized GeoTIFFs, one per variable and month, on
`https://os.zhdk.cloud.switch.ch/chelsav2/GLOBAL/climatologies/1981-2010/<var>/CHELSA_<var>_<mm>_1981-2010_V.2.1.tif`
(`<var>` = `tas`, `tasmax`, `tasmin`, `pr`; `<mm>` = 01, ..., 12), about 0.5 GB each:
48 files. They are not downloaded: `prepare.jl` reads only the box 2.5°W-3.5°E,
41.3-44°N of each file through GDAL `/vsicurl/` (`gdal_translate -projwin`), the PYR
domain with a margin of at least 0.4°, and keeps the clipped GeoTIFFs (721 x 325 cells,
about 1 MB each) in the storage folder of the datamanifest entry `chelsa_v21`.

The values are stored as integers with a scale and offset in the files: temperatures
x 0.1 - 273.15 (degC), precipitation x 0.1 (kg m-2 month-1, the monthly sum).

## Prepare and remap

```bash
julia --project=Karger2017_chelsa Karger2017_chelsa/prepare.jl
julia fesmdata.jl remap Atmosphere CHELSA-1981-2010
```

`prepare.jl` writes `$FESMDATA_PREPARED/Karger2017_chelsa/Karger2017_CHELSA-V2.1_1981-2010_Pyrenees.nc`:
`tas`, `tasmax`, `tasmin` (K) and `pr` (kg m-2 d-1, the monthly sum divided by the mean
length of the month, February 28.25 days) on (lon, lat, month), latitudes ascending.

## Notes

- **Orography.** The temperatures are those of the 1 km orography of CHELSA; models
  should correct them to their own surface with a lapse rate.
- **Ocean.** CHELSA has values over the sea too (from the downscaling), so the whole
  PYR-1KM grid is covered.
- **Other domains.** The same script can clip any other box (`BOX`), e.g. for other
  mountain-glacier domains.
