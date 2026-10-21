# CLIMPY, climate of the Pyrenees (Cuadrat et al., 2024)

Daily gridded maximum and minimum temperature and precipitation of the Pyrenees and their
forelands, 1981-2020, at 1 km, from station observations:

Cuadrat, J. M., Serrano-Notivoli, R., Prohom, M., Cunillera, J., Tejedor, E., Saz, M. A.,
de Luis, M., Llabrés-Brustenga, A., and Soubeyroux, J.-M.: Climate of the Pyrenees:
Extremes indices and long-term trends, Sci. Total Environ., 933, 173052, 2024,
[doi:10.1016/j.scitotenv.2024.173052](https://doi.org/10.1016/j.scitotenv.2024.173052).

Data: Climate of the Pyrenees (CLIMPY), Zenodo,
[doi:10.5281/zenodo.10972236](https://doi.org/10.5281/zenodo.10972236).

## Licence

CC BY 4.0 (Zenodo record): free use and redistribution, also of derived products, citing
the article and the data.

## Original data

Three NetCDF files on Zenodo (datamanifest keys `climpy_tmax`, `climpy_tmin`,
`climpy_pcp`), downloaded by `prepare.jl`:

| File | Field | Size |
|---|---|---|
| `tmax_daily_1981_2020.nc` | daily maximum temperature (degC) | 0.8 GB |
| `tmin_daily_1981_2020.nc` | daily minimum temperature (degC) | 0.7 GB |
| `pcp_daily_1981_2020.nc` | daily precipitation (mm) | 0.4 GB |

Each has 14,610 days (1981-2020) on a grid of 537 x 181 cells of 1 km (`easting`,
`northing`) on UTM zone 30N with the GRS80 ellipsoid (attribute `proj4` of `crs`), and
names its field `pcp`, whatever the variable (with `units = "celsius"` in all three).
The error estimates of the precipitation (`err_pcp_daily_1981_2020.zip`) are not used.

## Prepare and remap

```bash
julia --project=Cuadrat2024_climpy Cuadrat2024_climpy/prepare.jl
julia fesmdata.jl remap Atmosphere CLIMPY-1981-2010
```

`prepare.jl` reads the daily files one year at a time and writes to
`$FESMDATA_PREPARED/Cuadrat2024_climpy/`, for 1981-2010 and 1991-2020,
`Cuadrat2024_CLIMPY_<period>.nc`: `tasmax`, `tasmin` (K, the monthly means of the daily
values), `tas` (K, the mean of the two) and `pr` (kg m-2 d-1, the monthly mean of the
daily precipitation, mm per day), on (x, y, month), with `x`, `y` in m on the grid of the
data (northing ascending) and the PROJ string of the files as `proj_params` of `crs`.

## Notes

- **Coverage and filling.** The data cover the Pyrenees and their forelands, not the
  whole PYR domain (about 70% of PYR-1KM, all of the range and of its glaciers at the
  Last Glacial Maximum). The prepared files keep the gaps (missing values). The products
  of Atmosphere (`Atmosphere-CLIMPY-<period>`) are extended over the whole grid by the
  gap filling of the remapping (`fill` in `../Atmosphere/remap.toml`): the temperatures
  by the linear regression on the surface elevation of the Topo product
  (`TOPO-GLO90-GEBCO2026`) within 50 km, the precipitation by harmonic interpolation, the
  filled cells marked by `mask_fill`. (The Pyrenees workflow this comes from filled them
  by nearest neighbour, with the temperatures reduced to sea level with a lapse rate of
  6.5 K km-1.)
- **Grid.** UTM 30N (GRS80), while PYR is on UTM 31N (WGS84): the remapping onto PYR-1KM
  samples each cell at points of half the source spacing. GRS80 and WGS84 differ by less
  than a millimetre here.
- **Temperature.** `tas` is the mean of `tasmax` and `tasmin` (no daily mean in the data).
