# Paleoclimate: simulations and reconstructions of past climates

Climatologies of past climates from the PMIP model intercomparisons and CLIMBER-3α, and gridded
reconstructions of the deglacial climate of Greenland, remapped onto the grids of the
domains. Paleoclimate is a thematic dataset made by remapping (see [Gridded
data](https://fesmc.github.io/FesmData/remap.html)): its products are defined in
`Paleoclimate/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `Paleoclimate-PMIP3-<model>-<experiment>` | PMIP3/CMIP5 (Braconnot et al., 2012, [doi:10.1038/nclimate1456](https://doi.org/10.1038/nclimate1456)): climatologies of the PMIP variability database (CVDP), 8 models, experiments lgm, midHolocene, piControl | `t2m_ann`, `t2m_djf`, `t2m_jja`, `sst_ann` (degC), `pr_ann`, `pr_djf`, `pr_jja` (mm d-1); `z_srf` (m), `f_land`, `f_ice` of the model and experiment (CMIP5 fixed fields; not `f_ice` of FGOALS-g2 lgm, `z_srf` and `f_land` of MPI-ESM-P lgm) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Paleoclimate-PMIP3-<experiment>-mean`, `Paleoclimate-PMIP3-<experiment>-stdev` | Ensemble mean and standard deviation of the 8 PMIP3 models, for each experiment | as the models, with `n_<field>`, the number of models with a value | as above |
| `Paleoclimate-PMIP3-lgm-boundary-conditions` | PMIP3 LGM boundary conditions (Abe-Ouchi et al., 2015, [doi:10.5194/gmd-8-3621-2015](https://doi.org/10.5194/gmd-8-3621-2015)) | `dz_srf` (m), `f_land`, `f_ice` | as above |
| `Paleoclimate-PMIP4-<model>-<experiment>` | PMIP4/CMIP6 (Kageyama et al., 2018, [doi:10.5194/gmd-11-1033-2018](https://doi.org/10.5194/gmd-11-1033-2018)): climatologies of the last 100 years, 4 models (AWI-ESM-1-1-LR, INM-CM4-8, MIROC-ES2L, MPI-ESM1-2-LR), experiments lgm, midHolocene, piControl | `t2m_*`, `pr_*` (annual, DJF, JJA, monthly), `z_srf`, `f_land`, `f_ice` | as above |
| `Paleoclimate-PMIP4-<experiment>-mean`, `Paleoclimate-PMIP4-<experiment>-stdev` | Ensemble mean and standard deviation of the 4 PMIP4 models, for each experiment | as the models, with `n_<field>` | as above |
| `Paleoclimate-CLIMBER3a-<simulation>`, `Paleoclimate-CLIMBER3a-<simulation>-ocean` | CLIMBER-3α (Montoya and Levermann, 2008, [doi:10.1029/2007GL032560](https://doi.org/10.1029/2007GL032560)): present day (`present`) and LGM with wind stress x 1.7, weak and strong Atlantic overturning (`lgm_1p7weak`, `lgm_1p7strong`); atmosphere at 22.5° x 7.5°, ocean at 3.75° | atmosphere: `t2m_ann`, `t2m_jja` (degC), `pr_ann` (mm d-1), `z_srf` (m), `f_land` of the model; ocean: `to` (potential temperature, degC) on `depth`, `mask_ocn` | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Paleoclimate-Buizert2018`, `Paleoclimate-Buizert2018-1981-2010` | Buizert et al. (2018): Greenland monthly temperature and precipitation, 22 ka to present, decadal, [doi:10.25921/psvs-yg80](https://doi.org/10.25921/psvs-yg80); and its 1981-2010 baseline | `tas` (K), `pr` (kg m-2 s-1) on `month` and `time` (years ago), `z_srf` | Greenland |
| `Paleoclimate-Badgeley2020` | Badgeley et al. (2020): Greenland temperature and precipitation from data assimilation, 20 ka to present, 50-year means, [doi:10.18739/A2599Z26M](https://doi.org/10.18739/A2599Z26M) | `tas_anom` (K), `pr_frac`, `pr_frac_low`, `pr_frac_high` (relative to 1850-2000 CE) on `time` (years ago) | Greenland |

On the mountain-glacier domains (Pyrenees, Patagonia, Himalaya), on their 2 km grid: the ensemble means and standard deviations of PMIP3 and PMIP4 (`-mean`, `-stdev`; not the members); their nests and crops get these by cropping (see [Nests and crops](https://fesmc.github.io/FesmData/download.html#nests-and-crops)).

The model output is on the models' own grids (some Gaussian), remapped conservatively.
Products are made on grids of 8 km and coarser (16 km for the Buizert et al. time
series, 32 km for CLIMBER-3α): finer grids add no information to these sources, and models can remap them
online. Each file also has `f_valid`, the fraction of each cell covered by the source.
The ensemble products are made from the files of the models on each grid: in each
cell, the mean or the standard deviation (population) of the models with a value there
(e.g. `sst_ann` only over the ocean of each model), `n_<field>` models.

## Precision

The float fields are rounded on output to a tolerance by kind (see [Precision and file
sizes](https://fesmc.github.io/FesmData/precision.html)): temperatures to 0.01 K;
precipitation to 1%; `z_srf` and `dz_srf` to 0.01 m; fractions (`f_*`, `pr_frac*`) to
0.001. The ensemble products are computed from the rounded products of their members and
rounded again.

## Licences

| Source | Licence |
|---|---|
| PMIP3 (CVDP) | CMIP5 terms of use (non-commercial) and NCAR CVDP (acknowledge the CVDP, cite the models) |
| PMIP3 LGM boundary conditions | None stated |
| PMIP4 (CMIP6) | CC BY-SA 4.0 (the four models): releases must keep the ShareAlike terms |
| Buizert et al. (2018) | NOAA NCEI open data, no licence stated; cite the paper and the data DOI |
| Badgeley et al. (2020) | CC0 1.0 (Arctic Data Center) |
| CLIMBER-3α (Montoya and Levermann, 2008) | CC BY 4.0 ([github.com/fesmc/Montoya2008-CLIMBER3a](https://github.com/fesmc/Montoya2008-CLIMBER3a)); cite Montoya and Levermann (2008) and Montoya et al. (2005) |

## Not included

Large model output, such as the transient TraCE-21ka simulation, is not remapped here:
models should read it with online remapping.

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap Paleoclimate
```
