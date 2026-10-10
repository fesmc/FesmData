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
| `GHF-Davies2013` | Davies (2013): 2° global map from observations, geology and young-ocean cooling, [doi:10.1002/ggge.20271](https://doi.org/10.1002/ggge.20271) | `ghf` (mean), `ghf_median`, `ghf_err` (error estimate) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `GHF-Shapiro2004` | Shapiro and Ritzwoller (2004): 1° global map extrapolated with a seismic model, [doi:10.1016/j.epsl.2004.04.011](https://doi.org/10.1016/j.epsl.2004.04.011) | `ghf`, `ghf_sd` (standard deviation) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `GHF-Loesing2021` | Lösing and Ebbing (2021): machine-learning map of Antarctica, about 55 km, [doi:10.1594/PANGAEA.930237](https://doi.org/10.1594/PANGAEA.930237) | `ghf`, `ghf_min`, `ghf_max` (range of alternative models) | Antarctica |
| `GHF-Stal2020` | Stål et al. (2021): Aq1, 20 km map of Antarctica, [doi:10.1594/PANGAEA.924857](https://doi.org/10.1594/PANGAEA.924857) | `ghf`, `ghf_unc` (uncertainty) | Antarctica |
| `GHF-Colgan2021` | Colgan and Wansing (2021): machine-learning map of Greenland, about 55 km, [doi:10.22008/FK2/F9P03L](https://doi.org/10.22008/FK2/F9P03L) | `ghf`, `ghf_min`, `ghf_max` (ensemble range) | Greenland |
| `GHF-FoxMaule2005` | Fox Maule et al. (2005): map from satellite magnetic data (Curie depth), updated with the MF7 model, about 170 km, land only, [doi:10.1126/science.1106888](https://doi.org/10.1126/science.1106888) | `ghf` | Antarctica (no data south of 87.75°S), GreenlandPaleo, Greenland |
| `GHF-Colgan2021-topocorr-GRL` | Colgan et al. (2021): relative topographic correction at 150 m (BedMachine), [doi:10.22008/FK2/BQGYYG](https://doi.org/10.22008/FK2/BQGYYG) | `ghf_corr`, `ghf_corr_unc` (dimensionless) | Greenland |
| `GHF-Colgan2021-topocorr-ANT` | Colgan et al. (2021): relative topographic correction at 500 m (BedMachine), [doi:10.22008/FK2/BQGYYG](https://doi.org/10.22008/FK2/BQGYYG) | `ghf_corr`, `ghf_corr_unc` (dimensionless) | Antarctica |

The topographic correction of Colgan et al. (2021) is not a heat flow but a
dimensionless relative correction (about 0 on average), to be applied to any heat flow
product as corrected heat flow = (1 + `ghf_corr`) × `ghf` (higher heat flow in
valleys, lower on ridges). It is made on all grids, as it resolves the bed topography
finer than any of them.

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
| Davies (2013) | Wiley standard terms (no open licence): permission from AGU or the author is needed before release |
| Shapiro and Ritzwoller (2004) | No licence stated; publishing assumed to be allowed |
| Lösing and Ebbing (2021) | CC BY 4.0 (PANGAEA) |
| Stål et al. (2021) | CC BY 4.0 (PANGAEA) |
| Colgan and Wansing (2021) | CC0 1.0 (GEUS Dataverse) |
| Fox Maule et al. (2005) | No licence stated (NASA GSFC web page, users asked to cite the paper); publishing assumed to be allowed |
| Colgan et al. (2021), topographic correction | CC0 1.0 (GEUS Dataverse) |

The licence of each source is in its README and in the `license` attribute of its
files. A source can be released under the FesmData licence (CC BY 4.0) only if its own
licence allows it.

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap GHF
# on Levante, on a compute node:
# sbatch --job-name=remap-GHF Remap/jobs/remap_dataset.sbatch GHF
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
