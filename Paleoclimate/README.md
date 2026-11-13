# Paleoclimate: simulations and reconstructions of past climates

Climatologies of past climates from the PMIP model intercomparisons, CLIMBER-3α and
CLIMBER-X (stadial and interstadial climates, with the transient output of their
simulation), and gridded reconstructions of the deglacial climate of Greenland, remapped onto the grids of the
domains. Paleoclimate is a thematic dataset made by remapping (see [Gridded
data](https://fesmc.github.io/FesmData/remap.html)): its products are defined in
`Paleoclimate/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `Paleoclimate-PMIP3-<model>-<experiment>` | PMIP3/CMIP5 (Braconnot et al., 2012, [doi:10.1038/nclimate1456](https://doi.org/10.1038/nclimate1456)): climatologies of the last 100 years of the CMIP5 monthly output (`../PMIP3_cmip5/README.md`), 13 models: lgm (8: CCSM4, CNRM-CM5, FGOALS-g2, GISS-E2-R, IPSL-CM5A-LR, MIROC-ESM, MPI-ESM-P, MRI-CGCM3), midHolocene and piControl (13, also bcc-csm1-1, CSIRO-Mk3-6-0, FGOALS-s2, HadGEM2-CC, HadGEM2-ES) | `t2m_ann`, `t2m_djf`, `t2m_jja`, `t2m_mon` (degC), `pr_ann`, `pr_djf`, `pr_jja`, `pr_mon` (mm d-1); `z_srf` (m), `f_land`, `f_ice` of the model and experiment (CMIP5 fixed fields, where published) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Paleoclimate-PMIP4-<model>-<experiment>` | PMIP4/CMIP6 (Kageyama et al., 2018, [doi:10.5194/gmd-11-1033-2018](https://doi.org/10.5194/gmd-11-1033-2018)): climatologies of the last 100 years (`../PMIP4_cmip6/README.md`), 21 models: lgm (7: AWI-ESM-1-1-LR, CESM2-FV2, CESM2-WACCM-FV2, INM-CM4-8, MIROC-ES2L, MPI-ESM1-2-LR, and CESM2-PaleoCalibr of Zhu et al., 2022, `../Zhu2022_PaleoCalibr/README.md`), midHolocene (18) and piControl (21) | `t2m_*`, `pr_*` (annual, DJF, JJA, monthly), `z_srf`, `f_land`, `f_ice` (where published; no `pr` in CESM2-FV2 lgm) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Paleoclimate-PMIP3-<model>-<experiment>-ocean`, `Paleoclimate-PMIP4-<model>-<experiment>-ocean` | The ocean and sea ice of the same runs, where published, from their 1° files (`*_ocean.nc` of the sources) | `sst_mon` (degC), `sic_mon` (sea-ice concentration), `siext_mon` (1 where `sic_mon` >= 0.15), `to_ann` (annual potential temperature, degC, at `depth` 5 to 2000 m), each with its `f_valid_<field>`; `siextent_nh`, `siextent_sh` (hemispheric sea-ice extent, 1e6 km2, as published) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Paleoclimate-PMIP3-<experiment>-mean`, `-stdev`, `Paleoclimate-PMIP4-<experiment>-mean`, `-stdev`, and `-ocean-mean`, `-ocean-stdev` | Ensemble mean and standard deviation of the PMIP3 and of the PMIP4 models of each experiment (PMIP4 lgm without CESM2-FV2, the PaleoCalibr LGM run as published on ESGF, without `pr`) | as the models, with `n_<field>`, the number of models with a value | as above |
| `Paleoclimate-PMIP-lgm-mean`, `Paleoclimate-PMIP-lgm-stdev` | Ensemble of 12 LGM runs of PMIP3 and PMIP4: CCSM4, FGOALS-g2, GISS-E2-R, IPSL-CM5A-LR, MIROC-ESM, MPI-ESM-P, MRI-CGCM3, AWI-ESM-1-1-LR, CESM2-PaleoCalibr, INM-CM4-8, MIROC-ES2L, MPI-ESM1-2-LR (not CNRM-CM5, whose LGM run has no ice surface, nor the CESM2-FV2 runs); the reference of the LGM bias correction of the PaleoEmulator climate in kryos | as the models, with `n_<field>` | as above |
| `Paleoclimate-PMIP3-lgm-boundary-conditions` | PMIP3 LGM boundary conditions (Abe-Ouchi et al., 2015, [doi:10.5194/gmd-8-3621-2015](https://doi.org/10.5194/gmd-8-3621-2015)) | `dz_srf` (m), `f_land`, `f_ice` | as above |
| `Paleoclimate-CLIMBER3a-<simulation>`, `Paleoclimate-CLIMBER3a-<simulation>-ocean` | CLIMBER-3α (Montoya and Levermann, 2008, [doi:10.1029/2007GL032560](https://doi.org/10.1029/2007GL032560)): present day (`present`) and LGM with wind stress x 1.7, weak and strong Atlantic overturning (`lgm_1p7weak`, `lgm_1p7strong`); atmosphere at 22.5° x 7.5°, ocean at 3.75° | atmosphere: `t2m_ann`, `t2m_jja` (degC), `pr_ann` (mm d-1), `z_srf` (m), `f_land` of the model; ocean: `to` (potential temperature, degC) on `depth`, `mask_ocn` | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Paleoclimate-CLIMBERX-Willeit2025-<state>`, `Paleoclimate-CLIMBERX-Willeit2025-<state>-ocean` | CLIMBER-X (Willeit et al., 2025, [doi:10.1038/s41561-025-01814-0](https://doi.org/10.1038/s41561-025-01814-0)), 5°: climate states of the reference simulation under mid-glacial (MIS3) conditions, `interstadial`, `stadial` and `heinrich` (Heinrich stadial), means of the model years of each state (classified by the Atlantic overturning, see `../Willeit2025_climberx/README.md`), and the preindustrial control `piControl` | `t2m_*`, `sst_*` (degC), `pr_*` (mm d-1), `f_sic_*`, monthly (`_mon`) and annual (`_ann`), with their anomalies relative to `piControl` (`*_anom`), `z_srf`, `f_land`, `f_ice` of the model; ocean: `to` (degC), `so` (psu) on `depth`, with `to_anom`, `so_anom`, `mask_ocn` | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Paleoclimate-CLIMBERX-Willeit2025-<run>-transient`, `...-<run>-transient-ocean` | The same simulations, `HS4` (40-32 ka of the model calendar) and `piControl`: their 2D output (one model year every 100 years, every 1000 years for `piControl`), on the model grid | `t2m_mon`, `pr_mon`, `sst_mon`, `f_sic_mon` on `month` and `time`, `state` of each record; annual series on `time_ann` (`amoc`, `t2m_glob`, `t2m_grl`, `co2`, `hosing`, `sic_ext_nh`, ...); ocean: `to`, `so` on `depth` and `time`, the Atlantic overturning streamfunction `moc_atl` | Global (GLOBAL-5DEG only) |
| `Paleoclimate-Buizert2018`, `Paleoclimate-Buizert2018-1981-2010` | Buizert et al. (2018): Greenland monthly temperature and precipitation, 22 ka to present, decadal, [doi:10.25921/psvs-yg80](https://doi.org/10.25921/psvs-yg80); and its 1981-2010 baseline | `tas` (K), `pr` (kg m-2 s-1) on `month` and `time` (years ago), `z_srf` | Greenland |
| `Paleoclimate-Badgeley2020` | Badgeley et al. (2020): Greenland temperature and precipitation from data assimilation, 20 ka to present, 50-year means, [doi:10.18739/A2599Z26M](https://doi.org/10.18739/A2599Z26M) | `tas_anom` (K), `pr_frac`, `pr_frac_low`, `pr_frac_high` (relative to 1850-2000 CE) on `time` (years ago) | Greenland |

On the mountain-glacier domains (Pyrenees, Patagonia, Himalaya), on their 2 km grid: the atmosphere ensemble means and standard deviations of PMIP3, PMIP4 and PMIP-lgm (`-mean`, `-stdev`; not the members or the ocean); their nests and crops get these by cropping (see [Nests and crops](https://fesmc.github.io/FesmData/download.html#nests-and-crops)).

On PatagoniaPaleo (the paleo domain of Patagonia, 26-57°S, 2-8 km), the products of GreenlandPaleo (PMIP3 and PMIP4 members and ensembles, the PMIP3 boundary conditions, CLIMBER-3α and CLIMBER-X), on its coarsest grid, PAT-PAL-8KM.

The model output is on the models' own grids (some Gaussian), remapped conservatively.
Products are made on grids of 8 km and coarser (16 km for the Buizert et al. time
series, 32 km for CLIMBER-3α and CLIMBER-X, which are also on global grids of 1° and
coarser): finer grids add no information to these sources, and models can remap them
online. Each file also has `f_valid`, the fraction of each cell covered by the source.
The ensemble products are made from the files of the models on each grid: in each
cell, the mean or the standard deviation (population) of the models with a value there
(e.g. `sst_mon` only over the ocean of each model), `n_<field>` models.

## Precision

The float fields are rounded on output to a tolerance by kind (see [Precision and file
sizes](https://fesmc.github.io/FesmData/precision.html)): temperatures to 0.01 K;
precipitation to 1%; `z_srf` and `dz_srf` to 0.01 m; fractions (`f_*`, `pr_frac*`) to
0.001. The ensemble products are computed from the rounded products of their members and
rounded again.

## Licences

| Source | Licence |
|---|---|
| PMIP3 (CMIP5) | CMIP5 terms of use (some models non-commercial research and education only): cite the model output and the PMIP3 and CMIP5 references |
| PMIP3 LGM boundary conditions | None stated |
| PMIP4 (CMIP6) | CC BY-SA 4.0 (in the CMIP6 files of all 20 models): releases must keep the ShareAlike terms |
| CESM2 PaleoCalibr (Zhu et al., 2022) | CC BY 4.0: cite the paper and the dataset (NCAR GDEX d583116) |
| Buizert et al. (2018) | NOAA NCEI open data, no licence stated; cite the paper and the data DOI |
| Badgeley et al. (2020) | CC0 1.0 (Arctic Data Center) |
| CLIMBER-3α (Montoya and Levermann, 2008) | CC BY 4.0 ([github.com/fesmc/Montoya2008-CLIMBER3a](https://github.com/fesmc/Montoya2008-CLIMBER3a)); cite Montoya and Levermann (2008) and Montoya et al. (2005) |
| CLIMBER-X (Willeit et al., 2025) | CC BY 4.0 (output provided by M. Willeit); cite Willeit et al. (2025) and Willeit et al. (2022) |

## Not included

Large model output, such as the transient TraCE-21ka simulation, is not remapped here:
models should read it with online remapping.

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap Paleoclimate
```
