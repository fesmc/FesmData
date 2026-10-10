# PMIP3 climatologies (CMIP5 lgm, midHolocene, piControl)

Annual and seasonal mean near-surface air temperature, precipitation and sea surface
temperature of the PMIP3/CMIP5 Last Glacial Maximum (`lgm`, 21 ka), mid-Holocene
(`midHolocene`, 6 ka) and preindustrial (`piControl`) simulations of 8 models, on each
model's atmosphere grid, plus the PMIP3 LGM ice-sheet boundary conditions. The
climatologies are the means computed by the NCAR Climate Variability Diagnostics Package
(CVDP v4.1.0) for the PMIP variability database (past2future.org), the same files as
used for the v1 PMIP3 products.

- PMIP3: Braconnot, P., Harrison, S. P., Kageyama, M., et al.: Evaluation of climate
  models using palaeoclimatic data, Nat. Clim. Change, 2, 417-424, 2012,
  [doi:10.1038/nclimate1456](https://doi.org/10.1038/nclimate1456).
- CVDP: Phillips, A. S., Deser, C., and Fasullo, J.: Evaluating modes of variability in
  climate models, Eos, 95, 453-455, 2014,
  [doi:10.1002/2014EO490002](https://doi.org/10.1002/2014EO490002).
- CVDP output of PMIP3: Brierley, C. and Wainer, I.: Inter-annual variability in the
  tropical Atlantic from the Last Glacial Maximum into future climate projections
  simulated by CMIP5/PMIP3, Clim. Past, 14, 1377-1390, 2018,
  [doi:10.5194/cp-14-1377-2018](https://doi.org/10.5194/cp-14-1377-2018).
- LGM boundary conditions: Abe-Ouchi, A., Saito, F., Kageyama, M., et al.: Ice-sheet
  configuration in the CMIP5/PMIP3 Last Glacial Maximum experiments, Geosci. Model Dev.,
  8, 3621-3637, 2015, [doi:10.5194/gmd-8-3621-2015](https://doi.org/10.5194/gmd-8-3621-2015).

Each model should also be cited (see the CMIP5 model references).

## Licence

CMIP5 model output under the CMIP5 terms of use
(https://pcmdi.llnl.gov/mips/cmip5/terms-of-use.html): some models were released for
non-commercial research and education only. The CVDP output is distributed by NCAR
"for non-commercial purposes", acknowledging the NCAR Climate Analysis Section's Climate
Variability Diagnostics Package. So the products are for non-commercial use, with
acknowledgement of CVDP and citation of the models. The LGM boundary conditions state no
licence.

## Original data

- CVDP output (`cvdp_data` files, 625 MB): the PMIP variability database is no longer
  online, so the 24 files listed in `prepare.jl` are copied from the old PIK archive:
  ```bash
  mkdir -p /work/ba1442/data/pmip3_cvdp && cd /work/ba1442/data/pmip3_cvdp
  scp hpc:/data/sicopolis/data/PMIP3/all_PMIP_cvdp_data/data/<file> .   # each file of prepare.jl
  ```
  The NCAR CVDP data repository
  (http://webext.cgd.ucar.edu/Multi-Case/CVDP_repository/, `cmip5.lgm`, `cmip5.midHolocene`,
  `cmip5.piControl`, one tar file each) has CVDP output of the same simulations, but over
  other years and without GISS-E2-R lgm and midHolocene, FGOALS-g2 midHolocene and
  MPI-ESM-P piControl.
- LGM boundary conditions: `pmip3_21k_orog_diff_v0.nc`, `pmip3_21k_sftlf_v0.nc` and
  `pmip3_21k_sftgif_v0.nc` from https://pmip3.lsce.ipsl.fr/share/design/ice_bc/, downloaded
  by `prepare.jl` (`datamanifest.toml`).

## Prepare and remap

```bash
julia --project=PMIP3_cvdp PMIP3_cvdp/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/PMIP3_cvdp/PMIP3_CCSM4_lgm.nc all --name=PMIP3-CCSM4-lgm
```

`prepare.jl` writes one file per model and experiment, `PMIP3_<model>_<experiment>.nc`,
with `t2m_ann`, `t2m_djf`, `t2m_jja` (degC), `pr_ann`, `pr_djf`, `pr_jja` (mm d-1) and
`sst_ann` (degC; missing for GISS-E2-R piControl), and `PMIP3_lgm_boundary_conditions.nc`
with `dz_srf` (m, LGM - preindustrial surface elevation), `f_land` and `f_ice` (land and
land-ice area fractions at the LGM, 1° grid). The years of each climatology are in the
global attribute `years`. The CVDP files have neither orography nor land mask; v1 made
the LGM `z_srf` as present-day surface elevation + `dz_srf`, and its `mask` from these
land and ice fractions.

Only regular lon-lat grids can be remapped. The models on Gaussian grids (CNRM-CM5,
MIROC-ESM, MPI-ESM-P, MRI-CGCM3; latitude spacing uneven by 0.8 %) and FGOALS-g2 (finer
latitudes near the poles) are prepared on their own grids but cannot be remapped yet.

| Model | Grid (lon × lat) | Regular |
|---|---|---|
| CCSM4 | 288 × 192 (1.25° × 0.94°) | yes |
| CNRM-CM5 | 256 × 128 (T127 Gaussian) | no |
| FGOALS-g2 | 128 × 60 (2.8°, uneven lat) | no |
| GISS-E2-R | 144 × 90 (2.5° × 2°) | yes |
| IPSL-CM5A-LR | 96 × 96 (3.75° × 1.89°) | yes |
| MIROC-ESM | 128 × 64 (T42 Gaussian) | no |
| MPI-ESM-P | 192 × 96 (T63 Gaussian) | no |
| MRI-CGCM3 | 320 × 160 (TL159 Gaussian) | no |
