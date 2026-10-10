# SMB: surface mass balance and surface climate

Surface mass balance and surface climate of the ice sheets from regional climate
models, remapped onto the grids of the domains. SMB is a thematic dataset made by
remapping (see Bring your own data, `Remap/README.md`): its products are defined in
`SMB/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `SMB-RACMO2.4p1-1981-2010`, `SMB-RACMO2.4p1-1991-2020`, `SMB-RACMO2.4p1-annual` | van Dalum et al. (2025): RACMO2.4p1 forced by ERA5, 11 km, [doi:10.5194/tc-19-4061-2025](https://doi.org/10.5194/tc-19-4061-2025), data [doi:10.5281/zenodo.19255213](https://doi.org/10.5281/zenodo.19255213) | `smb`, `pr`, `sf`, `ru`, `me`, `su` (kg m-2 yr-1), `t2m`, `T_srf` (K): monthly climatologies, annual means 1979-2023; `z_srf`, `f_ice`, `mask_land`, `mask_icesheet` | Antarctica |

Fluxes are in kg m-2 yr-1 (mm water equivalent per year), also for the months of a
climatology. Each file also has `f_valid`, the fraction of each cell covered by the
source. Fields are remapped conservatively and smoothed on grids finer than the source;
the masks are remapped as classes.

## Licences

| Source | Licence |
|---|---|
| van Dalum et al. (2025), RACMO2.4p1 | CC BY 4.0 |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap SMB
```
