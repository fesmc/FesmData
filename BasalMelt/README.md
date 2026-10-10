# BasalMelt: ice-shelf basal melt rates

Basal melt rates of ice shelves from observations, remapped onto the grids of the
domains. BasalMelt is a thematic dataset made by remapping (see Bring your own data,
`Remap/README.md`): its products are defined in `BasalMelt/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `BasalMelt-Rignot2013` | Rignot et al. (2013): 1 km basal melt rates of the Antarctic ice shelves in 2007-2008, [doi:10.5061/dryad.5hqbzkhg2](https://doi.org/10.5061/dryad.5hqbzkhg2) | `bmelt` (actual), `bmelt_ss` (steady state), m/yr ice equivalent, positive for melting | Antarctica |

Each file also has `f_valid`, the fraction of each cell covered by the source (the ice
shelves). Fields are remapped conservatively.

## Licences

| Source | Licence |
|---|---|
| Rignot et al. (2013) | CC0 1.0 (Dryad) |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap BasalMelt
```
