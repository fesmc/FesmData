# GHF: geothermal heat flow

Geothermal heat flow (mW m-2) from published maps, remapped onto the grids of the
domains and onto global lon-lat grids. GHF is a thematic dataset made by remapping
(see Bring your own data, `Remap/README.md`): its products are defined in
`GHF/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `GHF-Lucazeau2019` | Lucazeau (2019): 0.5° global map fitted to heat flow observations, [doi:10.1029/2019GC008389](https://doi.org/10.1029/2019GC008389) | `ghf`, `ghf_sd` (standard deviation) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `GHF-Martos2017` | Martos et al. (2017): 15 km map of Antarctica from airborne magnetic data (Curie depth), [doi:10.1594/PANGAEA.882503](https://doi.org/10.1594/PANGAEA.882503) | `ghf`, `ghf_sd` (uncertainty), `depth_curie`, `depth_curie_sd` (km) | Antarctica |
| `GHF-Martos2018` | Martos et al. (2018): 15 km map of Greenland (land only) from magnetic Curie depths, [doi:10.1594/PANGAEA.892973](https://doi.org/10.1594/PANGAEA.892973) | `ghf`, `ghf_sd` (uncertainty), `depth_curie`, `depth_curie_sd` (km) | Greenland |
| `GHF-HazzardRichards2024` | Hazzard and Richards (2024): 0.5° map of Antarctica inferred from seismic velocities, [doi:10.1029/2023GL106274](https://doi.org/10.1029/2023GL106274) | `ghf`, `ghf_sd` (standard deviation) | Antarctica |

Each file `<GRID>_GHF-<Source>.nc` also has `f_valid`, the fraction of each cell
covered by the source. Each source is remapped conservatively; on grids finer than the
source it is then smoothed with a Gaussian of half the source spacing (about 28 km
for 0.5°), so that its cells do not show as steps. The global attribute
`remap_method` records what was done on each grid.

## Licences

| Source | Licence |
|---|---|
| Lucazeau (2019) | Wiley standard terms (no open licence): permission from AGU or the author is needed before release |
| Martos et al. (2017) | CC BY 3.0 (PANGAEA) |
| Martos et al. (2018) | CC BY 3.0 (PANGAEA) |
| Hazzard and Richards (2024) | No licence set on OSF (article CC BY 4.0); publishing assumed to be allowed |

The licence of each source is in its README and in the `license` attribute of its
files. A source can be released under the FesmData licence (CC BY 4.0) only if its own
licence allows it.

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap GHF
```

This makes all products on all their grids, after preparing the sources that are not
prepared yet (`<source>/prepare.jl`). To make one product, or some domains or grids,
name them, e.g. `julia fesmdata.jl remap GHF Lucazeau2019 Antarctica GLOBAL-0.5DEG`.
Existing files are kept unless `--overwrite`.

## Adding a source

1. Make a folder for the source with a `prepare.jl` and a `README.md` (see Bring
   your own data), e.g. `Lucazeau2019_ghf/`.
2. Add a table `[products.<Name>]` to `GHF/remap.toml` with `source`, `file`,
   `variables` and `domains` (and `method` or `smooth` if the defaults do not fit).
3. Add it to the table of products above, and run `julia fesmdata.jl remap GHF <Name>`.
4. Release a new version of GHF (see Releasing, `Publish/README.md`).
