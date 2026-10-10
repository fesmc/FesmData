# GHF: geothermal heat flow

Geothermal heat flow (mW m-2) from published maps, remapped onto the grids of the
domains and onto global lon-lat grids. GHF is a thematic dataset made by remapping
(see Bring your own data, `Remap/README.md`): its products are defined in
`GHF/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `GHF-Lucazeau2019` | Lucazeau (2019): 0.5° global map fitted to heat flow observations, [doi:10.1029/2019GC008389](https://doi.org/10.1029/2019GC008389) | `ghf`, `ghf_sd` (standard deviation) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |

Each file `<GRID>_GHF-<Source>.nc` also has `f_valid`, the fraction of each cell
covered by the source. The source is remapped conservatively; on grids finer than the
source it is then smoothed with a Gaussian of half the source spacing (about 28 km
for 0.5°), so that its cells do not show as steps. The global attribute
`remap_method` records what was done on each grid.

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
