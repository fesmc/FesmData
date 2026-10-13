# BasalMelt: ice-shelf basal melt rates

Basal melt rates of ice shelves from observations, remapped onto the grids of the
domains. BasalMelt is a thematic dataset made by remapping (see Bring your own data,
`Remap/README.md`): its products are defined in `BasalMelt/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `BasalMelt-Adusumilli2020` | Adusumilli et al. (2020): 500 m basal melt rates of the Antarctic ice shelves, mean 2010-2018, from CryoSat-2, [doi:10.6075/J04Q7SHT](https://doi.org/10.6075/J04Q7SHT) | `bmelt` (gaps filled with the mean rate at the same ice draft), `bmelt_cs2` (CryoSat-2 only), `bmelt_err` (uncertainty), m yr-1 ice equivalent, positive for melting | Antarctica |
| `BasalMelt-Adusumilli2020-heights` | Adusumilli et al. (2020): quarterly height changes of the Antarctic ice shelves 1992-2018 from radar altimetry, 10 km (not melt rates; grids of 8 km and coarser), [doi:10.6075/J04Q7SHT](https://doi.org/10.6075/J04Q7SHT) | `dh_alt` (surface height), `dh_firn` (firn air content), m, relative to 1994; `smb_discharge` (surface mass balance and discharge change, m yr-1 ice equivalent); on `time` (quarters); no uncertainties (inconsistent in the source file) | Antarctica |
| `BasalMelt-Rignot2013` | Rignot et al. (2013): 1 km basal melt rates of the Antarctic ice shelves in 2007-2008, [doi:10.5061/dryad.5hqbzkhg2](https://doi.org/10.5061/dryad.5hqbzkhg2) | `bmelt` (actual), `bmelt_ss` (steady state), m yr-1 ice equivalent, positive for melting; their means over the drainage basins (Zwally et al., 2012) `bmelt_basin`, `bmelt_eq_basin`, and `bmelt_reese`, `bmelt_eq_reese` over groups of them (as `bm_ac_reese`, `bm_eq_reese` of v1) | Antarctica |

Each file also has `f_valid`, the fraction of each cell covered by the source (the ice
shelves). Fields are remapped conservatively. The basin means of `BasalMelt-Rignot2013`
are one value per basin, taken on the source grid over the ice shelves of the basin
(basin 25, without data, over those of basins 24 and 26), and set on every cell of the
basin on each grid, the cells outside the basins (open ocean, outer cells) taking the
nearest basin: they cover the whole grid (see `Rignot2013_bmelt/README.md`).

`BasalMelt-Adusumilli2020-heights` has the height changes from which Adusumilli et al.
(2020) derive time series of melt rates (relative to the 2010-2018 mean, their Eq. S7),
not melt rates: see `Adusumilli2020_bmelt/README.md`.

## Precision

The float fields are rounded on output to a tolerance by kind (see [Data volume and
precision](https://fesmc.github.io/FesmData/data_volume.html)): melt rates (`bmelt*`,
`smb_discharge`) to 1%; the height changes `dh_alt` and `dh_firn` to 0.01 m; `f_valid` to
0.001.

## Licences

| Source | Licence |
|---|---|
| Adusumilli et al. (2020) | CC BY 4.0 (UC San Diego Library) |
| Rignot et al. (2013) | CC0 1.0 (Dryad) |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap BasalMelt
```
