# Atmosphere: reanalysis and satellite climatologies

Monthly climatologies of the atmosphere from reanalysis and satellite data, remapped
onto the grids of the domains and onto global lon-lat grids. Atmosphere is a thematic
dataset made by remapping (see [Gridded
data](https://fesmc.github.io/FesmData/remap.html)): its products are defined in
`Atmosphere/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `Atmosphere-ERA5-1981-2010`, `Atmosphere-ERA5-1991-2020` | Hersbach et al. (2020): ERA5 monthly means, N320 Gaussian grid (about 31 km), [doi:10.1002/qj.3803](https://doi.org/10.1002/qj.3803) | `zs`, `lsm`; monthly `sp`, `t2m`, `sst`, `u10`, `v10`, `ws10`, `tcc`, `al`, `tcw`, `tclw`, `tciw`, `pr`, `sf` | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Atmosphere-ERA5-plev-1981-2010`, `Atmosphere-ERA5-plev-1991-2020` | as above, 9 pressure levels from 1000 to 500 hPa | `t`, `z`, `u`, `v`, `w`, `uv` on `plev`, monthly | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Atmosphere-CERES-2001-2020` | Loeb et al. (2018): CERES EBAF Ed4.2.1, 1°, [doi:10.1175/JCLI-D-17-0208.1](https://doi.org/10.1175/JCLI-D-17-0208.1) | TOA and surface radiative fluxes (W m-2), monthly | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Atmosphere-CLIMPY-1981-2010`, `Atmosphere-CLIMPY-1991-2020` | Cuadrat et al. (2024): CLIMPY, the daily climate of the Pyrenees from station data, 1 km (UTM 30N), [doi:10.5281/zenodo.10972236](https://doi.org/10.5281/zenodo.10972236); monthly means of the days of each period | monthly `tas`, `tasmax`, `tasmin` (K), `pr` (kg m-2 d-1) | Pyrenees (PYR-1KM) |
| `Atmosphere-CHELSA-1981-2010` | Karger et al. (2017): CHELSA V2.1 climatologies, 30 arc seconds (about 1 km), [doi:10.16904/envidat.228](https://doi.org/10.16904/envidat.228) | monthly `tas`, `tasmax`, `tasmin` (K), `pr` (kg m-2 d-1) | Pyrenees (PYR-1KM) |

On the mountain-glacier domains (Pyrenees, Patagonia, Himalaya), on their 2 km grid: `Atmosphere-ERA5-1981-2010` and `Atmosphere-ERA5-1991-2020`; their nests and crops get these by cropping (see [Nests and crops](https://fesmc.github.io/FesmData/download.html#nests-and-crops)).

The regional climatologies of the Pyrenees (CLIMPY, CHELSA V2.1) are on the 1 km grid
of PYR, their own resolution, rather than on the 2 km grid of the thematic datasets.
CLIMPY covers the Pyrenees and their forelands (about 70% of PYR, all of the range and
of its glaciers at the Last Glacial Maximum). The rest of the grid is filled, so that
the product can force a model over the whole grid: the temperatures by the linear
regression on the surface elevation (`z_srf` of `TOPO-GLO90-GEBCO2026`) of the cells with
data within 50 km, the precipitation by harmonic interpolation (see [Gap
filling](https://fesmc.github.io/FesmData/adding.html#gap-filling)); the filled cells
are marked by `mask_fill` (`f_valid` = 0 there). Its `tas` is the mean of `tasmax` and
`tasmin`. CHELSA V2.1 covers the whole grid; its temperatures are those of its own
1 km orography, to be corrected to the model surface with a lapse rate. The
precipitation of both is given as a mean rate (kg m-2 d-1, mm per day), as ERA5: the
monthly sums of CHELSA divided by the mean length of the month (February 28.25 days).

Winds are remapped as vectors and rotated to the axes of projected grids. Each file also
has `f_valid`, the fraction of each cell covered by the source. Fields are remapped
conservatively and smoothed on grids finer than the source.

## Precision

The float fields are rounded on output to a tolerance by kind (see [Precision and file
sizes](https://fesmc.github.io/FesmData/precision.html)): temperatures (`t2m`,
`sst`, `t`, `tas`, `tasmax`, `tasmin`) to 0.01 K; the elevation `zs` and the geopotential height `z` to 0.01 m;
fractions (`lsm`, `tcc`, `al`, `f_valid`) to 0.001; precipitation, snowfall, winds, `w`
and the radiative fluxes to 1%; `sp`, `tcw`, `tclw` and `tciw` to 3 significant digits.

## Licences

| Source | Licence |
|---|---|
| Hersbach et al. (2020), ERA5 | Copernicus licence: free use and redistribution with attribution ("Contains modified Copernicus Climate Change Service information") |
| Loeb et al. (2018), CERES EBAF | NASA open data, no restrictions; cite the products |
| Cuadrat et al. (2024), CLIMPY | CC BY 4.0 (Zenodo) |
| Karger et al. (2017), CHELSA V2.1 | CC0 1.0 (EnviDat); cite Karger et al. (2017) and the data DOI |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap Atmosphere
```
