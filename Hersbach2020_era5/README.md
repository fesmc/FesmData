# ERA5 monthly climatologies (Hersbach et al., 2020)

Monthly climatologies 1981-2010 and 1991-2020 of the ERA5 reanalysis, surface fields and
fields on pressure levels, on the ERA5 N320 Gaussian grid (about 0.28°):

Hersbach, H., Bell, B., Berrisford, P., et al.: The ERA5 global reanalysis, Q. J. R.
Meteorol. Soc., 146, 1999-2049, 2020,
[doi:10.1002/qj.3803](https://doi.org/10.1002/qj.3803).

Data: Hersbach, H., et al. (2017): Complete ERA5 from 1940: Fifth generation of ECMWF
atmospheric reanalyses of the global climate, Copernicus Climate Change Service (C3S) Data
Store, [doi:10.24381/cds.143582cf](https://doi.org/10.24381/cds.143582cf). Data
distribution by the German Climate Computing Center (DKRZ).

They replace the v1 products `<GRID>_ERA-INT_1981-2010.nc` and
`<GRID>_ERA-INT-<p>Mb_1981-2010.nc` (ERA-Interim). The folder `ERA5/` is a separate
workflow (CDS download at 2.5° for radiation and moist-column validation).

## Licence

Copernicus licence: free use and redistribution, also of modified products, with the
attribution "Contains modified Copernicus Climate Change Service information [year]" and
the statement that neither the European Commission nor ECMWF is responsible for any use of
it (https://cds.climate.copernicus.eu/api/v2/terms/static/licence-to-use-copernicus-products.pdf).
Both are in the `license` attribute of the files.

## Original data

On Levante, the ERA5 monthly means of the DKRZ data pool, `/pool/data/ERA5/E5`
(datamanifest key `era5_dkrz_pool`, used in place; see
`/pool/data/ERA5/README_ERA5_POOL_DATA_*.txt`), GRIB on the reduced Gaussian grid N320,
one file per year with 12 monthly means of daily means (of daily sums for accumulated
fields):

| Field | File (`<y>` = year) |
|---|---|
| `zs`, `lsm` | `sf/an/IV/129/E5sf00_IV_INVARIANT_129.grb`, `.../172/..._172.grb` |
| `sp`, `t2m`, `sst`, `u10`, `v10`, `ws10`, `tcc`, `tcw`, `al` | `sf/an/1M/<code>/E5sf00_1M_<y>_<code>.grb`, codes 134, 167, 034, 165, 166, 207, 164, 136, 243 |
| `tclw`, `tciw`, `pr`, `sf` | `sf/fc/1M/<code>/E5sf12_1M_<y>_<code>.grb`, codes 078, 079, 228, 144 |
| `t`, `z`, `u`, `v`, `w` | `pl/an/1M/<code>/E5pl00_1M_<y>_<code>.grb`, codes 130, 129, 131, 132, 135 |

Elsewhere, the same fields are in the CDS datasets
`reanalysis-era5-single-levels-monthly-means` and
`reanalysis-era5-pressure-levels-monthly-means` (product type
`monthly_averaged_reanalysis`); `prepare.jl` reads the DKRZ pool layout.

## Prepare and remap

On Levante (cdo reads about 150 GB of GRIB; 5 minutes on 16 cores of the shared partition):

```bash
source shared/machines/levante.env
sbatch Hersbach2020_era5/prepare.sbatch       # runs prepare.jl with cdo
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Hersbach2020_era5/Hersbach2020_ERA5_1991-2020.nc all --name=Atmosphere-ERA5-1991-2020
```

`prepare.jl` writes to `$FESMDATA_WORK/prepared/Hersbach2020_era5/`, for each period
1981-2010 and 1991-2020:

- `Hersbach2020_ERA5_<period>.nc`: `zs` (m, surface geopotential / g) and `lsm` (land
  fraction) (lon, lat); `sp` (Pa), `t2m`, `sst` (K, missing over land), `u10`, `v10`
  (eastward and northward wind at 10 m), `ws10` (mean 10 m wind speed, m s-1), `tcc`,
  `al` (cloud cover, albedo; 0-1), `tcw`, `tclw`, `tciw` (total column water, cloud
  liquid and ice water; kg m-2), `pr`, `sf` (precipitation and snowfall, kg m-2 d-1 =
  mm water equivalent per day) (lon, lat, month);
- `Hersbach2020_ERA5-plev_<period>.nc`: `t` (K), `z` (geopotential height, m,
  geopotential / g), `u`, `v` (eastward and northward wind, m s-1), `w` (vertical
  velocity, Pa s-1) and `uv` (speed of the monthly mean wind, m s-1) at 1000, 950, 850,
  750, 700, 650, 600, 550 and 500 hPa (lon, lat, plev, month).

cdo makes the climatology of each field (`ymonmean` of the monthly means of the years,
intermediate files in `$FESMDATA_WORK/era5/`), and `prepare.jl` converts the units and
writes the prepared files.

## Notes

- **Grid.** The pool has no regular lon-lat version. The reduced Gaussian grid is
  filled to the regular Gaussian N320 grid (1280 x 640, 0.28125° in longitude) with
  `cdo setgridtype,regular`, which interpolates linearly along each latitude row only
  (the rows near the equator are already full; rows nearer the poles have fewer points),
  without smoothing. The latitudes are the Gaussian latitudes (89.78° to -89.78°,
  spacing 0.2787° to 0.2811°, within 0.004° of a uniform spacing). Longitudes are shifted
  to -180:180.
- **Accumulated fields.** The 1M files of `tp` and `sf` are monthly means of daily sums in
  m of water; they are multiplied by 1000 to kg m-2 d-1.
- **Albedo.** `al` is the ERA5 forecast albedo (`fal`), the albedo of the whole surface
  including snow and sea ice (about 0.8 over Antarctica). The `al` of the v1 files was
  the snow-free background albedo of ERA-Interim (below 0.5), a different quantity.
- **Wind.** `u10`, `v10`, `u`, `v` are geographic components (standard names
  `eastward_wind`, `northward_wind`), rotated to the grid axes by the remapping onto
  projected grids. `ws10` is the ERA5 mean wind speed, larger than the speed of the mean
  wind `uv` given on the pressure levels.
- **Pressure levels below the surface** hold the values extrapolated by ECMWF (e.g. 1000
  hPa over Antarctica), not missing values.
- The column condensates `clw`, `ciw` of the v1 files (ERA-Interim) are not in ERA5;
  `tclw`, `tciw` are.
