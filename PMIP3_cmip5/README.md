# PMIP3 climatologies (CMIP5 lgm, midHolocene, piControl)

Monthly, annual and seasonal mean near-surface air temperature and precipitation, with
orography and land and land-ice fractions, of the PMIP3/CMIP5 Last Glacial Maximum (`lgm`,
21 ka), mid-Holocene (`midHolocene`, 6 ka) and preindustrial (`piControl`) simulations, on
each model's atmosphere grid: the same form as PMIP4_cmip6. The climatologies are the means
over the last 100 years of each run. Unlike PMIP3_cvdp (annual and seasonal means of the
CVDP output), this dataset is made from the CMIP5 monthly output itself.

- PMIP3: Braconnot, P., Harrison, S. P., Kageyama, M., et al.: Evaluation of climate models
  using palaeoclimatic data, Nat. Clim. Change, 2, 417-424, 2012,
  [doi:10.1038/nclimate1456](https://doi.org/10.1038/nclimate1456).
- CMIP5: Taylor, K. E., Stouffer, R. J., and Meehl, G. A.: An overview of CMIP5 and the
  experiment design, Bull. Amer. Meteor. Soc., 93, 485-498, 2012,
  [doi:10.1175/BAMS-D-11-00094.1](https://doi.org/10.1175/BAMS-D-11-00094.1).
- Model references: global attribute `references` of each file (from the CMIP5 files).

| Model | Institute | Member (lgm / midHolocene / piControl) |
|---|---|---|
| CCSM4 | NCAR | r1i1p1 |
| CNRM-CM5 | CNRM-CERFACS | r1i1p1 |
| FGOALS-g2 | LASG-CESS | r1i1p1 |
| GISS-E2-R | NASA-GISS | r1i1p150 / r1i1p1 / r1i1p1 |
| IPSL-CM5A-LR | IPSL | r1i1p1 |
| MIROC-ESM | MIROC | r1i1p1 |
| MPI-ESM-P | MPI-M | r1i1p1 |
| MRI-CGCM3 | MRI | r1i1p1 |

The years of each climatology are in the global attribute `years`, the variables or fx
fields not available in `missing` (e.g. the fx fields of CNRM-CM5 midHolocene, on no ESGF
data node).

## Licence

CMIP5 terms of use (https://pcmdi.llnl.gov/mips/cmip5/terms-of-use.html): cite the model
output and the PMIP3 and CMIP5 references above. Some models allow non-commercial research
and education only.

## Original data

Amon `tas`, `pr` and fx `orog`, `sftlf`, `sftgif` (latest readable version) from pools laid
out as the ESGF dataset ids,
`<pool>/<institute>/<model>/<experiment>/<frequency>/<realm>/<table>/<member>/<version>/`,
listed in `CMIP5_POOL` (':'-separated, searched in order). On Albedo
(`shared/machines/albedo.env`): the AWI pool `/albedo/work/projects/p_pool_clim_data/cmip5/output1`
and its tree `p_pool_clim_data/esgf/cmip5/output1`, where the files missing from the pool
(e.g. piControl `pr`) were fetched from ESGF (CEDA data node):

```bash
source shared/machines/albedo.env
python3 CMIP/esgf_fetch.py --root $CMIP_POOL_FETCH --skip-in /albedo/work/projects/p_pool_clim_data \
    CMIP5 CCSM4 piControl Amon pr --member r1i1p1 --last-years 100
python3 CMIP/esgf_fetch.py --root $CMIP_POOL_FETCH --skip-in /albedo/work/projects/p_pool_clim_data \
    CMIP5 CCSM4 lgm fx sftlf --member r0i0p0
```

## Prepare and remap

```bash
julia --project=PMIP3_cmip5 PMIP3_cmip5/prepare.jl [model ...]
julia fesmdata.jl remap $FESMDATA_PREPARED/PMIP3_cmip5/PMIP3_MIROC-ESM_lgm.nc all --name=PMIP3-MIROC-ESM-lgm
```

`prepare.jl` writes one file per model and experiment, `PMIP3_<model>_<experiment>.nc`,
with `t2m_ann`, `t2m_djf`, `t2m_jja`, `t2m_mon` (degC), `pr_ann`, `pr_djf`, `pr_jja`,
`pr_mon` (mm d-1), `z_srf` (m, orography of the experiment), `f_land` and `f_ice` (land and
land-ice area fractions; fractions given in 0-1 rather than %, as GISS-E2-R lgm, are taken as
they are). The annual and seasonal means are the means of the monthly climatologies
weighted by month length (model calendar).
