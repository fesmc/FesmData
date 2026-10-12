# SMB: surface mass balance and surface climate

Surface mass balance and surface climate of the ice sheets from regional climate
models, remapped onto the grids of the domains. SMB is a thematic dataset made by
remapping (see Bring your own data, `Remap/README.md`): its products are defined in
`SMB/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `SMB-RACMO2.4p1-1981-2010`, `SMB-RACMO2.4p1-1991-2020`, `SMB-RACMO2.4p1-annual`; annual means `SMB-RACMO2.4p1-1981-2010-annual-mean`, `SMB-RACMO2.4p1-1991-2020-annual-mean` | van Dalum et al. (2025): RACMO2.4p1 forced by ERA5, 11 km, [doi:10.5194/tc-19-4061-2025](https://doi.org/10.5194/tc-19-4061-2025), data [doi:10.5281/zenodo.19255213](https://doi.org/10.5281/zenodo.19255213) | `smb`, `pr`, `sf`, `runoff`, `melt`, `subl` (kg m-2 yr-1), `t2m`, `T_srf` (K): monthly climatologies and their annual means, annual values 1979-2023; `z_srf`, `f_ice`, `mask_land`, `mask_icesheet` | Antarctica |
| `SMB-RACMO2.3p2-1981-2010`, `SMB-RACMO2.3p2-1991-2020`, `SMB-RACMO2.3p2-1985-2014`, `SMB-RACMO2.3p2-annual`; annual means `SMB-RACMO2.3p2-1981-2010-annual-mean`, `SMB-RACMO2.3p2-1991-2020-annual-mean`, `SMB-RACMO2.3p2-1985-2014-annual-mean` | van Wessem et al. (2018, 2023): RACMO2.3p2 forced by ERA5, 27 km, [doi:10.5194/tc-12-1479-2018](https://doi.org/10.5194/tc-12-1479-2018), data [doi:10.5281/zenodo.7760491](https://doi.org/10.5281/zenodo.7760491) | `smb`, `pr`, `sf`, `runoff`, `melt`, `subl` (kg m-2 yr-1), `t2m`, `T_srf` (K): monthly climatologies and their annual means, annual values 1979-2022; `z_srf`, `f_ice`, `mask_grounded`. 1985-2014: reference climate of ISMIP7, filled over the whole grid (see below) | Antarctica |
| `SMB-MARv3.14-1961-1990`, `SMB-MARv3.14-1981-2010`, `SMB-MARv3.14-1991-2020`, `SMB-MARv3.14-annual`; annual means `SMB-MARv3.14-1961-1990-annual-mean`, `SMB-MARv3.14-1981-2010-annual-mean`, `SMB-MARv3.14-1991-2020-annual-mean` | Fettweis et al. (2017), Timmermans et al. (2026): MAR v3.14.3 forced by ERA5, 1 km, [doi:10.5194/tc-11-1015-2017](https://doi.org/10.5194/tc-11-1015-2017) | `smb`, `pr`, `sf`, `rf`, `melt`, `runoff` (kg m-2 yr-1), `t2m`, `T_srf` (K): monthly climatologies and their annual means, annual values 1940-2025; `z_srf`, `f_ice`, `mask` | Greenland |

All sources use the same names and units: fluxes in kg m-2 yr-1 (mm water equivalent
per year), also for the months of a climatology, and temperatures in K. The
`-annual-mean` products are the annual means `(x, y)` of the monthly climatologies, the
months weighted by their mean length over the period. Each file also has `f_valid`, the
fraction of each cell covered by the source. Fields are remapped conservatively and
smoothed on grids finer than the source; the masks are remapped as classes.

`SMB-RACMO2.3p2-1985-2014` (and its annual mean) is a reference climate for model
forcing (the reference period of the ISMIP7 experiments), defined on the whole grid:
`smb` is `pr + subl` off the glaciated surfaces (see `vanWessem2023_racmo23/README.md`),
and `smb`, `pr`, `sf`, `t2m`, `T_srf` and `z_srf` are filled outside the RACMO domain
(the corners of the grids) by harmonic interpolation (`fill`, `mask = "all"`, marked by
`mask_fill`).

## Licences

| Source | Licence |
|---|---|
| van Dalum et al. (2025), RACMO2.4p1 | CC BY 4.0 |
| van Wessem et al. (2023), RACMO2.3p2 | CC BY 4.0 |
| Fettweis et al. (2017), MAR v3.14 | No licence stated (freely available at ftp.climato.be, cite the references); publishing assumed to be allowed |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap SMB
```
