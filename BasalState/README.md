# BasalState: basal thermal state of the ice sheets

Basal temperature and basal thermal state (frozen, thawable, thawed) of the ice sheets,
remapped onto the grids of the domains. BasalState is a thematic dataset made by
remapping (see [Gridded data](https://fesmc.github.io/FesmData/remap.html)): its
products are defined in `BasalState/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `BasalState-Dawson2022` | Dawson et al. (2022): thermal steady state of the ISSM initialization of Antarctica (mesh of 0.3-50 km, interpolated to 1 km), [doi:10.5281/zenodo.6870567](https://doi.org/10.5281/zenodo.6870567) | `T_b` (basal temperature, K), `T_b_pmp` (relative to the pressure melting point, K), `basal_state` (1 frozen, 2 thawable within 2 K of the pressure melting point, 3 thawed), `bmelt_grnd` (basal melt rate, m yr-1 ice equivalent), `beta` (friction coefficient of the linear sliding law tau_b = beta u_b, Pa yr m-1) | Antarctica |

The basal melt rate `bmelt_grnd` of Dawson et al. (2022) is the model's own result:
about 21 Gt yr-1 over the grounded ice of Antarctica in total, lower than published
estimates of about 65 Gt yr-1.

The fields cover the grounded ice. Continuous fields are remapped conservatively, the
classes as the dominant class of each cell. Each file also has `f_valid`, the fraction
of each cell covered by the source.

## Precision

The float fields are rounded on output to a tolerance by kind (see [Precision and file
sizes](https://fesmc.github.io/FesmData/precision.html)): `T_b` and `T_b_pmp` to
0.01 K; `bmelt_grnd` to 1%; `beta` to 3 significant digits; `f_valid` to 0.001.
`basal_state` (classes) is exact.

## Licences

| Source | Licence |
|---|---|
| Dawson et al. (2022) | CC BY 4.0 (Zenodo) |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap BasalState
```
