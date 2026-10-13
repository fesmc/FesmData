# SolidEarth: lithosphere thickness and mantle viscosity

Lithosphere thickness (m) and mantle viscosity (log10 of the viscosity in Pa s, on
depth) from published Earth structures for glacial isostatic adjustment (GIA) models,
remapped onto the grids of the domains and onto global lon-lat grids. SolidEarth is a
thematic dataset made by remapping (see Bring your own data, `Remap/README.md`): its
products are defined in `SolidEarth/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `SolidEarth-Pan2022-litho` (not released) | Pan et al. (2022): 0.5° global Earth structure of the GIA model Seakon, [doi:10.1016/j.quascirev.2022.107644](https://doi.org/10.1016/j.quascirev.2022.107644) | `z_litho` | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `SolidEarth-Pan2022-visc` (not released) | Pan et al. (2022), as above | `log10_visc` on `depth` (64 levels, 24-2841 km) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global (16 km and coarser) |
| `SolidEarth-Bagge2021` | Bagge et al. (2021): 8 of the 18 global 3D viscosity structures for VILMA (those the article uses with NAICE: all reduction factors with profile s16, and the reference factor 0.4 with sc06 and sc06b; reference structure `v_0.4_s16`), Gaussian grid about 0.7°, [doi:10.5880/GFZ.1.3.2020.004](https://doi.org/10.5880/GFZ.1.3.2020.004) | `log10_visc` on `depth` (164 layers, with bounds, to the core-mantle boundary) and `structure` (1-8, see `Bagge2021_visc/README.md`) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global (16 km and coarser) |
| `SolidEarth-Lloyd2024` | Lloyd et al. (2024): global 3D viscosity inferred from GLAD-M25, 0.5°, [doi:10.1093/gji/ggad455](https://doi.org/10.1093/gji/ggad455) | `log10_visc` on `depth` (201 levels, 0-2891 km) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global (16 km and coarser) |
| `SolidEarth-Wiens2022` (not released) | Wiens et al. (2022), Ivins et al. (2022): Antarctic upper-mantle viscosity from ANT-20, 40 km, [doi:10.1144/M56-2020-18](https://doi.org/10.1144/M56-2020-18) | `log10_visc` on `depth` (100, 200, 300 km) | Antarctica (16 km and coarser) |
| `SolidEarth-Hazzard2023-litho` | Hazzard et al. (2023): Antarctic lithosphere from ANT-20 (1200 °C isotherm), 0.5°, south of 60°S, [doi:10.1029/2023JB026653](https://doi.org/10.1029/2023JB026653) | `z_litho`, `z_litho_sd` (standard deviation) | Antarctica |
| `SolidEarth-Hazzard2023-visc` | Hazzard et al. (2023): Antarctic mantle viscosity from ANT-20, 0.5°, south of 45°S | `log10_visc`, `log10_visc_sd` (standard deviation) on `depth` (75-400 km every 25 km) | Antarctica (16 km and coarser) |

`log10_visc` is the log10 of the viscosity in Pa s (units `log10(Pa s)`); `depth` is
in m, positive down, from the surface (from the Earth radius of the model where the
source gives radii, see the README of each source). Each file
`<GRID>_SolidEarth-<Source>.nc` also has `f_valid`, the fraction of each cell covered by
the source. Fields are remapped conservatively and, on grids finer than the source,
smoothed with a Gaussian of half the source spacing. The viscosity products are made on
grids of 16 km and coarser only: their sources are 0.5° or coarser and the files are
large; models on finer grids can remap them online. Bagge2021, on the T170 Gaussian grid
of VILMA, is made on the Gaussian grid GLOBAL-T170 (the same grid, no interpolation)
instead of the regular global lon-lat grids.

**Not released yet**: the products of Pan et al. (2022) and Wiens et al. (2022), data
obtained by personal communication, are made but left out of the releases
(`release = false`) until their authors agree to their redistribution (to be asked),
although the isostasy_data archive on Zenodo already redistributes them under CC BY 4.0.

## Relation to isostasy_data

These products replace the Earth structure of the isostasy_data repository of J.
Swierczek-Jereczek (https://github.com/JanJereczek/isostasy_data), made again from the
original files where they are published:

| isostasy_data | Here |
|---|---|
| `lithothickness/pan2022.llz`, `.nc`, `viscosity/pan2022.nc` | `Pan2022_litho` (same files, through the isostasy_data archive: not published by the authors) |
| `viscosity/bagge2021.nc` | `Bagge2021_visc` (structure 6, `v_1.0_s16`, of the 8 prepared from the 18 of the GFZ data publication, identical) |
| `viscosity/wiens2022.nc` | `Wiens2022_visc` (same file, through the isostasy_data archive: not published by the authors) |
| `yelmo/ANT-*_GIA_HR24.nc`, `yelmo/ANT-*_stdvisc_Hazzard2024.nc` | `Hazzard2023_visc` (the published grids: the standard deviations are the same; the mean viscosity of `GIA_HR24` is the published mean capped at 10^30.7 Pa s (as here) on 44 GIA layers, and its lithosphere is about 11% thicker than the published 1200 °C isotherm) |
| `yelmo/ANT-*_Lloyd2024.nc` | none: it is the viscosity of `GIA_HR24` capped at 10^23 Pa s, not the published model of Lloyd et al. (2024), which is `Lloyd2024_visc` |

## Precision

The float fields are rounded on output to a tolerance by kind (see [Data volume and
precision](https://fesmc.github.io/FesmData/data_volume.html)): `z_litho` and
`z_litho_sd` to 0.1 m; `log10_visc` and `log10_visc_sd` to 3 significant digits (about
0.01, 2% in viscosity); `f_valid` to 0.001.

## Licences

| Source | Licence |
|---|---|
| Pan et al. (2022) | Not published by the authors, no licence stated (obtained by personal communication for isostasy_data, archived under CC BY 4.0): not released until the authors agree |
| Bagge et al. (2021) | CC BY 4.0 (GFZ Data Services) |
| Lloyd et al. (2024) | CC BY 4.0 (supporting information of the article) |
| Wiens et al. (2022) | Not published by the authors, no licence stated (provided by D. A. Wiens for isostasy_data, archived under CC BY 4.0): not released until the authors agree |
| Hazzard et al. (2023) | No licence set on OSF (article CC BY 4.0); publishing assumed to be allowed |

The licence of each source is in its README and in the `license` attribute of its
files. A source can be released under the FesmData licence (CC BY 4.0) only if its own
licence allows it.

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap SolidEarth
# on Levante, on part of a node of the shared partition:
# sbatch --job-name=remap-SolidEarth -p shared -c 32 --mem=29G -t 02:00:00 Remap/jobs/remap_dataset.sbatch SolidEarth
```

This makes all products on all their grids, after preparing the sources that are not
prepared yet (`<source>/prepare.jl`; `Lloyd2024_visc` needs a manual download first, see
its README). To make one product, or some domains or grids, name them, e.g.
`julia fesmdata.jl remap SolidEarth Bagge2021 Antarctica GLOBAL-1DEG`. Existing files
are kept unless `--overwrite`.

See `GHF/README.md` for adding a source.
