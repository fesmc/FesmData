# Ocean: ocean temperature and salinity

Ocean temperature and salinity from observations and reanalyses, remapped onto the
grids of the domains. Ocean is a thematic dataset made by remapping (see Bring your own
data, `Remap/README.md`): its products are defined in `Ocean/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `Ocean-Schmidtko2014` | Schmidtko et al. (2014): Antarctic shelf bottom water (shallower than 1500 m), means 1975-2012, 0.25° x 0.125°, [doi:10.1126/science.1256117](https://doi.org/10.1126/science.1256117) | `ct_bottom` (conservative temperature), `sa_bottom` (absolute salinity), their standard deviations `*_std`, `z_bottom` (bottom depth) | Antarctica |
| `Ocean-ORAS5-1981-2010`, `Ocean-ORAS5-annual` | Zuo et al. (2019): ORAS5 ocean reanalysis (ECMWF), regridded to 1° by ECMWF, member opa0, [doi:10.5194/os-15-779-2019](https://doi.org/10.5194/os-15-779-2019) | `to` (potential temperature, degC), `so` (salinity, PSU) on `depth`: monthly climatology 1981-2010, annual means 1979-2018 | Antarctica, Greenland, GreenlandPaleo, North, Laurentide, Eurasia, Global |
| `Ocean-ISMIP7` | Zhou et al. (2026): OCEAN ICE climatology 1972-2024 as extrapolated by ISMIP7 (Reese et al., 2026) on its 8 km x 60 m grid, [doi:10.5194/essd-2025-727](https://doi.org/10.5194/essd-2025-727) | `to` (potential temperature, degC), `so` (practical salinity, PSU), `tf` (thermal forcing, degC) on `z` (30 layers of 60 m, to 1800 m depth), filled everywhere; `basin` (IMBIE2 basins extended into the ocean, 0-15) | Antarctica |

Each file also has `f_valid` (with the extra dimensions where the coverage differs
between them, e.g. depth levels), the fraction of each cell covered by the source.
Fields are remapped conservatively and smoothed on grids finer than the source.

## Licences

| Source | Licence |
|---|---|
| Schmidtko et al. (2014) | No licence stated; publishing assumed to be allowed |
| Zuo et al. (2019), ORAS5 | CC BY 4.0 (Copernicus, CDS reanalysis-oras5) |
| Zhou et al. (2026), ISMIP7 | No licence stated for the ISMIP7 files; the OCEAN ICE climatology is CC BY 4.0 (SEANOE); publishing assumed to be allowed |

## Superseded

The ISMIP6 ocean climatology of Jourdain et al. (2020) is superseded by the ISMIP7
climatology (`Ocean-ISMIP7`) and not included: see `Jourdain2020_ismip6/README.md`.

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap Ocean
```
