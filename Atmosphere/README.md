# Atmosphere: reanalysis and satellite climatologies

Monthly climatologies of the atmosphere from reanalysis and satellite data, remapped
onto the grids of the domains and onto global lon-lat grids. Atmosphere is a thematic
dataset made by remapping (see Bring your own data, `Remap/README.md`): its products are
defined in `Atmosphere/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `Atmosphere-ERA5-1981-2010`, `Atmosphere-ERA5-1991-2020` | Hersbach et al. (2020): ERA5 monthly means, N320 Gaussian grid (about 31 km), [doi:10.1002/qj.3803](https://doi.org/10.1002/qj.3803) | `zs`, `lsm`; monthly `sp`, `t2m`, `sst`, `u10`, `v10`, `ws10`, `tcc`, `al`, `tcw`, `tclw`, `tciw`, `pr`, `sf` | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Atmosphere-ERA5-plev-1981-2010`, `Atmosphere-ERA5-plev-1991-2020` | as above, 9 pressure levels from 1000 to 500 hPa | `t`, `z`, `u`, `v`, `w`, `uv` on `plev`, monthly | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Atmosphere-CERES-2001-2020` | Loeb et al. (2018): CERES EBAF Ed4.2.1, 1°, [doi:10.1175/JCLI-D-17-0208.1](https://doi.org/10.1175/JCLI-D-17-0208.1) | TOA and surface radiative fluxes (W m-2), monthly | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |

Winds are remapped as vectors and rotated to the axes of projected grids. Each file also
has `f_valid`, the fraction of each cell covered by the source. Fields are remapped
conservatively and smoothed on grids finer than the source.

## Licences

| Source | Licence |
|---|---|
| Hersbach et al. (2020), ERA5 | Copernicus licence: free use and redistribution with attribution ("Contains modified Copernicus Climate Change Service information") |
| Loeb et al. (2018), CERES EBAF | NASA open data, no restrictions; cite the products |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap Atmosphere
```
