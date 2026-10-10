# Stratigraphy: age structure of the ice

The age structure of the ice from radar stratigraphy, remapped onto the grids of the
domains. Stratigraphy is a thematic dataset made by remapping (see Bring your own data,
`Remap/README.md`): its products are defined in `Stratigraphy/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `Stratigraphy-MacGregor2025` | MacGregor et al. (2025): RRRAG4 v2, 5 km age structure of the Greenland Ice Sheet from radar stratigraphy 1993-2019, [doi:10.5067/SZSVA3CWV3U4](https://doi.org/10.5067/SZSVA3CWV3U4) | `ice_age`, `ice_age_sd` (ka) on `depth_norm` (fraction of the ice thickness); `depth_iso`, `depth_iso_sd` (m) on `age` (ka) | Greenland, GreenlandPaleo |

Each file also has `f_valid` (with the extra dimension where the coverage differs
between levels), the fraction of each cell covered by the source. Fields are remapped
conservatively, level by level, and smoothed on grids finer than the source.

## Licences

| Source | Licence |
|---|---|
| MacGregor et al. (2025), RRRAG4 v2 | CC BY 4.0 (NASA open data, cite the data set) |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap Stratigraphy
```
