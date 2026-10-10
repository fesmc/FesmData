# Greenland surface mass balance and surface climate (MAR v3.14, ERA5)

Surface mass balance, its components and the near-surface temperatures of Greenland from
the regional climate model MAR v3.14.3 forced by the ERA5 reanalysis, 1940-2025: the
monthly outputs of the MAR team (X. Fettweis, University of Liège), interpolated by them
from the 10 km MAR grid onto the 1 km ISMIP6 grid of Greenland. References:

Fettweis, X., Box, J. E., Agosta, C., Amory, C., Kittel, C., Lang, C., van As, D.,
Machguth, H., and Gallée, H.: Reconstructions of the 1900-2015 Greenland ice sheet
surface mass balance using the regional climate MAR model, The Cryosphere, 11,
1015-1033, 2017, [doi:10.5194/tc-11-1015-2017](https://doi.org/10.5194/tc-11-1015-2017).

Timmermans, G., Noël, B., Kittel, C., Dethinne, T., Ghilain, N., and Fettweis, X.:
Evaluation of MARv3.14 over the Greenland Ice Sheet, EGUsphere [preprint], 2026,
[doi:10.5194/egusphere-2026-2341](https://doi.org/10.5194/egusphere-2026-2341)
(the reference given for MAR v3.14 on the MAR web page of the University of Liège).

## Licence

No licence is stated: the outputs are freely available on the server of the University
of Liège, without terms of use or a DOI. We assume that they may be redistributed, citing
the references above. (A 5 km version of the same run, with fewer variables, is on Zenodo
under CC BY 4.0: [doi:10.5281/zenodo.19691263](https://doi.org/10.5281/zenodo.19691263).)

## Original data

http://ftp.climato.be/fettweis/MARv3.14/Greenland/ERA5-1km-monthly/ (no login; the FTP
port may time out, HTTP works): one file per year, `MARv3.14-monthly-ERA5-<year>.nc`,
about 1.2 GB each, 107 GB for 1940-2025. They are listed in `datamanifest.toml`
(`mar314_era5_1km_monthly`), and `prepare.jl` downloads the missing ones into
`$DATAMANIFEST_DATASETS_DIR/mar314_era5_1km_monthly/` (about 1.5 minutes per file).

## Prepare and remap

Download first (`download` only downloads, e.g. on a login node; 2 hours or so), then
prepare on a compute node (about 70 s per year, 1h45 in all, 15 GB memory):

```bash
julia --project=Fettweis2017_mar314 Fettweis2017_mar314/prepare.jl download
srun -A ba1442 -p compute -t 03:00:00 --mem=32G julia --project=Fettweis2017_mar314 Fettweis2017_mar314/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Fettweis2017_mar314/MARv3.14_ERA5_1991-2020.nc Greenland --name=SMB-MARv3.14-1991-2020
```

`prepare.jl` writes to `$FESMDATA_WORK/prepared/Fettweis2017_mar314/`:

- `MARv3.14_ERA5_1981-2010.nc`, `MARv3.14_ERA5_1991-2020.nc`: monthly climatologies,
  fields `(x, y, month)`;
- `MARv3.14_ERA5_annual_1940-2025.nc`: annual time series, fields `(x, y, time)`.

| Field | MAR variable | Climatologies | Time series |
|---|---|---|---|
| `smb` surface mass balance | `SMBcorr` | kg m-2 d-1 | kg m-2 yr-1 |
| `melt` | `MEcorr` | kg m-2 d-1 | kg m-2 yr-1 |
| `runoff` | `RUcorr` | kg m-2 d-1 | kg m-2 yr-1 |
| `sf` snowfall | `SF` | kg m-2 d-1 | kg m-2 yr-1 |
| `rf` rainfall | `RF` | kg m-2 d-1 | kg m-2 yr-1 |
| `pr` precipitation | `SF + RF` | kg m-2 d-1 | kg m-2 yr-1 |
| `tas` 2 m air temperature | `T2Mcorr` | degC | degC |
| `T_srf` surface temperature | `STcorr` | degC | degC |
| `z_srf` surface elevation | `SRF` | m | m |
| `mask` land and ice mask | `MSK` | classes | classes |
| `f_ice` ice-covered fraction | `MSK >= 2` | 1 | 1 |

All files have `z_srf`, `mask` and `f_ice` `(x, y)`.

Notes:

- Units. MAR gives the fluxes in mm water equivalent (= kg m-2) per month. The
  climatologies are means of the daily rate (kg m-2 d-1 = mm w.e. per day, the
  monthly total divided by the days of the month in each year), as in the v1 file; the
  time series are annual totals (kg m-2 yr-1 = mm w.e. per year), and annual means of
  the temperatures (weighted by the days of the months). Time is the middle of each
  year (1 July).
- The `*corr` variables of MAR are corrected for the difference between the 10 km MAR
  and the 1 km surface elevation (`SRF`); snowfall and rainfall are not corrected.
- The fields are defined on land, ice and a strip of ocean along the coast (the
  extended mask `MSK2` of MAR), and missing (NaN) elsewhere.
- `mask` (integer, `flag_values`) is the mask of MAR: 0 ocean, 1 ice-free land, 2 and
  3 glaciers and ice caps separate from the ice sheet (two classes that the files do not
  explain; MAR counts class 3 in its ice sheet totals, `MSK > 2.5`), 4 ice sheet.
  `f_ice` is 1 on the ice classes (2-4), 0 elsewhere, so that it gives the ice-covered
  fraction once remapped.
- Grid: EPSG:3413 (polar stereographic, true scale at 70°N, central meridian 45°W,
  WGS84), x and y in m, 1681 x 2881 cells with centres from -720 to 960 km and -3450 to
  -570 km: the grid of the Greenland domain (GRL grids), not the wider GreenlandPaleo.
