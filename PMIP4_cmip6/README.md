# PMIP4 climatologies (CMIP6 lgm, midHolocene, piControl)

Monthly, annual and seasonal mean near-surface air temperature and precipitation, with
orography and land and land-ice fractions, of the PMIP4/CMIP6 Last Glacial Maximum (`lgm`,
21 ka), mid-Holocene (`midHolocene`, 6 ka) and preindustrial (`piControl`) simulations,
for the four models with all three experiments in the DKRZ CMIP6 pool, on each model's
atmosphere grid. The climatologies are the means over the last 100 years of each run.

- PMIP4: Kageyama, M., Braconnot, P., Harrison, S. P., et al.: The PMIP4 contribution to
  CMIP6 - Part 1: Overview and over-arching analysis plan, Geosci. Model Dev., 11,
  1033-1057, 2018, [doi:10.5194/gmd-11-1033-2018](https://doi.org/10.5194/gmd-11-1033-2018).
- Model data (ESGF, doi:10.22033/ESGF/CMIP6.\<n\>, in the global attribute `doi`):

| Model | lgm | midHolocene | piControl | Years (lgm, midHolocene, piControl) |
|---|---|---|---|---|
| AWI-ESM-1-1-LR | [9330](https://doi.org/10.22033/ESGF/CMIP6.9330) | [9332](https://doi.org/10.22033/ESGF/CMIP6.9332) | [9335](https://doi.org/10.22033/ESGF/CMIP6.9335) | 3901-4000, 3106-3205, 1855-1954 |
| INM-CM4-8 | [5075](https://doi.org/10.22033/ESGF/CMIP6.5075) | [5077](https://doi.org/10.22033/ESGF/CMIP6.5077) | [5080](https://doi.org/10.22033/ESGF/CMIP6.5080) | 2000-2099, 1980-2079, 2281-2380 |
| MIROC-ES2L | [5644](https://doi.org/10.22033/ESGF/CMIP6.5644) | [5646](https://doi.org/10.22033/ESGF/CMIP6.5646) | [5710](https://doi.org/10.22033/ESGF/CMIP6.5710) | 3200-3299, 8000-8099, 2250-2349 |
| MPI-ESM1-2-LR | [6642](https://doi.org/10.22033/ESGF/CMIP6.6642) | [6644](https://doi.org/10.22033/ESGF/CMIP6.6644) | [6675](https://doi.org/10.22033/ESGF/CMIP6.6675) | 2250-2349, 1401-1500, 2750-2849 |

## Licence

The data of all four models are under Creative Commons Attribution-ShareAlike 4.0
(CC BY-SA 4.0, global attribute `license` of the CMIP6 files, copied to the prepared
files), with the CMIP6 terms of use (https://pcmdi.llnl.gov/CMIP6/TermsOfUse): cite the
model data (DOIs above) and the PMIP4 protocol. Derived products must keep CC BY-SA 4.0.

## Original data

The CMIP6 data in the DKRZ pool on Levante (no download):
`/pool/data/CMIP6/data/PMIP/<institution>/<model>/{lgm,midHolocene}/<member>/` and
`/pool/data/CMIP6/data/CMIP/<institution>/<model>/piControl/<member>/`, member r1i1p1f1
(r1i1p1f2 for MIROC-ES2L), variables Amon `tas`, `pr` and fx `orog`, `sftlf`, `sftgif`
(latest version). Elsewhere, set `CMIP6_POOL` to a copy of the same tree (e.g. from ESGF).

## Prepare and remap

```bash
julia --project=PMIP4_cmip6 PMIP4_cmip6/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/PMIP4_cmip6/PMIP4_INM-CM4-8_lgm.nc all --name=PMIP4-INM-CM4-8-lgm
```

`prepare.jl` writes one file per model and experiment, `PMIP4_<model>_<experiment>.nc`,
with `t2m_ann`, `t2m_djf`, `t2m_jja`, `t2m_mon` (degC), `pr_ann`, `pr_djf`, `pr_jja`,
`pr_mon` (mm d-1), `z_srf` (m, orography of the experiment, e.g. with the LGM ice sheets),
`f_land` and `f_ice` (land and land-ice area fractions). `t2m_mon` and `pr_mon` are the
monthly climatologies (dimension `month`); the annual and seasonal means are their means
weighted by month length. Months are those of the model calendar: the midHolocene
climatologies are not adjusted for the changed length of the seasons. MIROC-ES2L has no
`sftgif` over the ocean, where `f_ice` is set to 0.

Only regular lon-lat grids can be remapped: of the four models only INM-CM4-8 (2° × 1.5°)
is on one. AWI-ESM-1-1-LR and MPI-ESM1-2-LR (T63) and MIROC-ES2L (T42) are on Gaussian
grids (latitude spacing uneven by 0.8 %); they are prepared on their own grids but cannot
be remapped yet. The ocean temperature (`tos`) is left out: it is on the ocean grids
(unstructured for AWI-ESM, curvilinear or tripolar for MPI-ESM and MIROC).
