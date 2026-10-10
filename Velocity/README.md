# Velocity: ice surface velocity

Surface velocity of the ice sheets from satellite observations, remapped onto the grids
of the domains. Velocity is a thematic dataset made by remapping (see Bring your own
data, `Remap/README.md`): its products are defined in `Velocity/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `Velocity-Joughin2018` | Joughin et al. (2018): MEaSUREs multi-year Greenland velocity mosaic 1995-2015, 250 m (NSIDC-0670 v1), [doi:10.5067/QUA5Q9SVMSJG](https://doi.org/10.5067/QUA5Q9SVMSJG) | `ux_srf`, `uy_srf` (along the grid axes), `uxy_srf` (speed), `ux_srf_err`, `uy_srf_err` (m/yr) | Greenland |
| `Velocity-Rignot2011` | Rignot et al. (2011): MEaSUREs InSAR-based Antarctic velocity 1995-2016, 450 m (NSIDC-0484 v2), [doi:10.5067/D7GK8F5J8M8R](https://doi.org/10.5067/D7GK8F5J8M8R) | `ux_srf`, `uy_srf` (along the grid axes), `uxy_srf` (speed), `ux_srf_err`, `uy_srf_err` (m/yr) | Antarctica |

The velocity components are remapped conservatively as eastward and northward
components and then rotated to the axes of each grid. The speed `uxy_srf` is the
remapped speed of the source (the mean speed in each cell, not the speed of the mean
velocity). The errors are those of the source along the axes of its projection, which
is that of the grids. Each file also has `f_valid`, the fraction of each cell covered
by the source.

## Licences

| Source | Licence |
|---|---|
| Joughin et al. (2018) | NASA Earth science data (NSIDC), no restrictions on use; cite the data set and article |
| Rignot et al. (2011) | NASA Earth science data (NSIDC), no restrictions on use; cite the data set and articles |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap Velocity
```
