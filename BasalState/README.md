# BasalState: basal thermal state of the ice sheets

Basal temperature and basal thermal state (frozen, thawable, thawed) of the ice sheets,
remapped onto the grids of the domains. BasalState is a thematic dataset made by
remapping (see Bring your own data, `Remap/README.md`): its products are defined in
`BasalState/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `BasalState-Dawson2022` | Dawson et al. (2022): thermal steady state of the ISSM initialization of Antarctica (mesh of 0.3-50 km, interpolated to 1 km), [doi:10.5281/zenodo.6870567](https://doi.org/10.5281/zenodo.6870567) | `T_b` (basal temperature, K), `T_b_pmp` (relative to the pressure melting point, K), `basal_state` (1 frozen, 2 thawable within 2 K of the pressure melting point, 3 thawed) | Antarctica |

The fields cover the grounded ice. Temperatures are remapped conservatively, the
classes as the dominant class of each cell. Each file also has `f_valid`, the fraction
of each cell covered by the source.

## Licences

| Source | Licence |
|---|---|
| Dawson et al. (2022) | CC BY 4.0 (Zenodo) |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap BasalState
```
