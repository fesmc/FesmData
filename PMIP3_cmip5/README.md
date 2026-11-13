# PMIP3 climatologies (CMIP5 lgm, midHolocene, piControl)

Monthly, annual and seasonal mean near-surface air temperature and precipitation, with
orography and land and land-ice fractions, of the PMIP3/CMIP5 Last Glacial Maximum (`lgm`,
21 ka), mid-Holocene (`midHolocene`, 6 ka) and preindustrial (`piControl`) simulations, on
each model's atmosphere grid: the same form as PMIP4_cmip6. With them, for each run, the
ocean and sea ice on a common regular 1° grid: monthly SST and sea-ice concentration, sea-ice
extent, annual mean potential temperature at standard depths and the Atlantic meridional
overturning streamfunction. The climatologies are the means over the last 100 years of each
run (temperature at depth: 30 years). Unlike PMIP3_cvdp (annual and seasonal means of the
CVDP output), this dataset is made from the CMIP5 monthly output itself.

- PMIP3: Braconnot, P., Harrison, S. P., Kageyama, M., et al.: Evaluation of climate models
  using palaeoclimatic data, Nat. Clim. Change, 2, 417-424, 2012,
  [doi:10.1038/nclimate1456](https://doi.org/10.1038/nclimate1456).
- CMIP5: Taylor, K. E., Stouffer, R. J., and Meehl, G. A.: An overview of CMIP5 and the
  experiment design, Bull. Amer. Meteor. Soc., 93, 485-498, 2012,
  [doi:10.1175/BAMS-D-11-00094.1](https://doi.org/10.1175/BAMS-D-11-00094.1).
- Model references: global attribute `references` of each file (from the CMIP5 files).

## Models

All CMIP5 models with a PMIP3 `lgm` or `midHolocene` run on ESGF (CEDA, DKRZ and NCI
indexes, November 2026), with their `piControl`: 8 with all three experiments and 5 with
midHolocene and piControl only. Member r1i1p1 (fx: r0i0p0), except GISS-E2-R lgm: r1i1p150
(fx r0i0p150; as PMIP3_cvdp).

| Model | Institute | Experiments |
|---|---|---|
| bcc-csm1-1 | BCC | midHolocene, piControl |
| CCSM4 | NCAR | lgm, midHolocene, piControl |
| CNRM-CM5 | CNRM-CERFACS | lgm, midHolocene, piControl |
| CSIRO-Mk3-6-0 | CSIRO-QCCCE | midHolocene, piControl |
| FGOALS-g2 | LASG-CESS | lgm, midHolocene, piControl |
| FGOALS-s2 | LASG-IAP | midHolocene, piControl |
| GISS-E2-R | NASA-GISS | lgm (p150), midHolocene, piControl |
| HadGEM2-CC | MOHC | midHolocene, piControl |
| HadGEM2-ES | MOHC | midHolocene, piControl |
| IPSL-CM5A-LR | IPSL | lgm, midHolocene, piControl |
| MIROC-ESM | MIROC | lgm, midHolocene, piControl |
| MPI-ESM-P | MPI-M | lgm, midHolocene, piControl |
| MRI-CGCM3 | MRI | lgm, midHolocene, piControl |

The years of each climatology are in the global attribute `years` (atmosphere) or the
attribute `years` of each variable (ocean); the variables not available in the global
attribute `missing`.

### Inventory

The CMIP5 variables of each run and member: x used (in the pools on Albedo), o on ESGF
but not obtainable (the files fail on all data nodes), (m) published for another member
only, - not published. Amon tas, pr; Omon tos, thetao, msftmyz (CMIP5 has no other
overturning streamfunction for these runs); OImon sic; fx orog, sftlf, sftgif, areacello.

| Model | Experiment | Member | tas | pr | tos | thetao | msftmyz | sic | orog | sftlf | sftgif | areacello |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bcc-csm1-1 | midHolocene | r1i1p1 | x | x | x | x | - | x | x | x | x | x |
| bcc-csm1-1 | piControl | r1i1p1 | x | x | x | x | - | x | x | x | x | x |
| CCSM4 | lgm | r1i1p1 | x | x | - | - | - | x | x | x | x | x |
| CCSM4 | midHolocene | r1i1p1 | x | x | - | - | - | x | x | x | x | x |
| CCSM4 | piControl | r1i1p1 | x | x | - | - | - | x | x | x | x | x |
| CNRM-CM5 | lgm | r1i1p1 | x | x | x | x | x | x | x | x | x | x |
| CNRM-CM5 | midHolocene | r1i1p1 | x | x | x | x | o | o | x | o | o | o |
| CNRM-CM5 | piControl | r1i1p1 | x | x | x | x | x | x | x | x | x | x |
| CSIRO-Mk3-6-0 | midHolocene | r1i1p1 | x | x | x | x | o | x | x | x | x | x |
| CSIRO-Mk3-6-0 | piControl | r1i1p1 | x | x | x | x | o | x | x | x | x | x |
| FGOALS-g2 | lgm | r1i1p1 | x | x | x | x | x | x | x | x | x | x |
| FGOALS-g2 | midHolocene | r1i1p1 | x | x | - | x | x | x | x | x | x | x |
| FGOALS-g2 | piControl | r1i1p1 | x | x | - | x | x | x | x | x | x | x |
| FGOALS-s2 | midHolocene | r1i1p1 | x | x | x | x | - | x | - | - | - | x |
| FGOALS-s2 | piControl | r1i1p1 | x | x | - | x | - | x | x | x | - | x |
| GISS-E2-R | lgm | r1i1p150 | x | x | x | x | - | x | x | x | x | x |
| GISS-E2-R | midHolocene | r1i1p1 | x | x | x | x | - | x | x | x | x | x |
| GISS-E2-R | piControl | r1i1p1 | x | x | x | x | x | x | x | x | x | x |
| HadGEM2-CC | midHolocene | r1i1p1 | x | x | x | x | - | x | x | x | - | x |
| HadGEM2-CC | piControl | r1i1p1 | x | x | x | x | - | x | x | x | - | x |
| HadGEM2-ES | midHolocene | r1i1p1 | x | x | x | x | - | x | x | x | - | x |
| HadGEM2-ES | piControl | r1i1p1 | x | x | x | x | - | x | x | x | - | x |
| IPSL-CM5A-LR | lgm | r1i1p1 | x | x | x | x | - | x | x | x | x | - |
| IPSL-CM5A-LR | midHolocene | r1i1p1 | x | x | x | x | - | x | x | x | x | x |
| IPSL-CM5A-LR | piControl | r1i1p1 | x | x | x | x | - | x | x | x | x | x |
| MIROC-ESM | lgm | r1i1p1 | x | x | x | x | - | x | x | x | x | x |
| MIROC-ESM | midHolocene | r1i1p1 | x | x | x | x | - | x | x | x | x | x |
| MIROC-ESM | piControl | r1i1p1 | x | x | x | x | - | x | x | x | x | x |
| MPI-ESM-P | lgm | r1i1p1 | x | x | x | x | x | x | x | x | x | x |
| MPI-ESM-P | midHolocene | r1i1p1 | x | x | x | x | x | x | x | x | x | x |
| MPI-ESM-P | piControl | r1i1p1 | x | x | x | x | x | x | x | x | x | x |
| MRI-CGCM3 | lgm | r1i1p1 | x | x | x | x | x | x | x | x | x | x |
| MRI-CGCM3 | midHolocene | r1i1p1 | x | x | x | x | x | x | x | x | x | x |
| MRI-CGCM3 | piControl | r1i1p1 | x | x | x | x | x | x | x | x | x | x |

Gaps: CCSM4 published no ocean fields (Omon) on the data nodes still online (NCAR's node is
gone), only sea ice; FGOALS-g2 no tos for midHolocene and piControl; no overturning
streamfunction for bcc-csm1-1, CCSM4, FGOALS-s2, GISS-E2-R (lgm, midHolocene), HadGEM2-CC,
HadGEM2-ES, IPSL-CM5A-LR and MIROC-ESM; CNRM-CM5 midHolocene msftmyz, sic, sftlf, sftgif and
areacello and CSIRO-Mk3-6-0 msftmyz are listed on ESGF but their files fail on all data
nodes (HTTP 404); HadGEM2-CC midHolocene covers only 35 years (1942-1976). The sea-ice
extent uses areacello of the run, else of another experiment of the model on the same grid
(IPSL-CM5A-LR lgm: of its midHolocene run), else the cell areas from the cell bounds (cdo
gridarea), else areas approximated from the cell centres (attribute `cell_area`).

## Licence

CMIP5 terms of use (https://pcmdi.llnl.gov/mips/cmip5/terms-of-use.html): cite the model
output and the PMIP3 and CMIP5 references above. Some models allow non-commercial research
and education only.

## Original data

Amon `tas`, `pr`, Omon `tos`, `thetao`, `msftmyz`, OImon `sic` and fx `orog`, `sftlf`,
`sftgif`, `areacello` (latest readable version) from pools laid out as the ESGF dataset ids,
`<pool>/<institute>/<model>/<experiment>/<frequency>/<realm>/<table>/<member>/<version>/`,
listed in `CMIP5_POOL` (':'-separated, searched in order; `models.jl`). On Albedo
(`shared/machines/albedo.env`): the AWI pool `/albedo/work/projects/p_pool_clim_data/cmip5/output1`,
to which the files it missed were added from ESGF (last 100 years; `thetao` by OPeNDAP, the
levels down to 3000 m of the last 30 years):

```bash
source shared/machines/albedo.env
python3 CMIP/esgf_fetch.py --root $CMIP_POOL_FETCH --skip-in /albedo/work/projects/p_pool_clim_data \
    CMIP5 CCSM4 piControl Amon pr --member r1i1p1 --last-years 100
python3 CMIP/esgf_fetch.py --root $CMIP_POOL_FETCH --skip-in /albedo/work/projects/p_pool_clim_data \
    CMIP5 CCSM4 lgm fx sftlf --member r0i0p0
python3 CMIP/esgf_fetch.py --root $CMIP_POOL_FETCH --skip-in /albedo/work/projects/p_pool_clim_data \
    CMIP5 MPI-ESM-P piControl Omon thetao --member r1i1p1 --last-years 30 --subset-depth 3000
```

## Prepare and remap

```bash
julia --project=PMIP3_cmip5 PMIP3_cmip5/prepare.jl [model ...]
module load cdo; julia --project=PMIP3_cmip5 PMIP3_cmip5/prepare_ocean.jl [model ...]
julia fesmdata.jl remap $FESMDATA_PREPARED/PMIP3_cmip5/PMIP3_MIROC-ESM_lgm.nc all --name=PMIP3-MIROC-ESM-lgm
```

`prepare.jl` writes one file per model and experiment, `PMIP3_<model>_<experiment>.nc`,
with `t2m_ann`, `t2m_djf`, `t2m_jja`, `t2m_mon` (degC), `pr_ann`, `pr_djf`, `pr_jja`,
`pr_mon` (mm d-1), `z_srf` (m, orography of the experiment), `f_land` and `f_ice` (land and
land-ice area fractions; fractions given in 0-1 rather than %, as GISS-E2-R lgm, are taken as
they are). The annual and seasonal means are the means of the monthly climatologies
weighted by month length (model calendar).

`prepare_ocean.jl` writes `PMIP3_<model>_<experiment>_ocean.nc` on the regular 1° grid
`lon` 0.5..359.5, `lat` -89.5..89.5 (shared/cmip_ocean.jl, as PMIP4_cmip6):

| Variable | Units | Contents |
|---|---|---|
| `sst_mon` | degC | monthly SST climatology (tos), NaN over land |
| `sic_mon` | 1 | monthly sea-ice concentration climatology (sic) |
| `siext_mon` | 1 | monthly sea-ice extent mask: 1 where `sic_mon` >= 0.15, else 0 |
| `siextent_nh`, `siextent_sh` | 1e6 km2 | monthly sea-ice extent of each hemisphere (attributes `march`, `september`) |
| `to_ann` | degC | annual mean potential temperature (thetao) at `depth` 5, 50, 100, 200, 300, 500, 700, 1000, 1500, 2000 m |
| `amoc` | Sv | annual mean Atlantic meridional overturning streamfunction (msftmyz, basin atlantic_arctic_ocean) on `lat` × `depth_moc` (0-6000 m every 100 m) |
| `amoc_max` | Sv | its maximum below 500 m between 20 and 60 N |

The time means are taken on the model's grid (SST, sea ice and overturning: the last 100
years; temperature at depth: the last 30 years), then remapped with cdo: conservatively
(`remapcon`) where the grid has cell bounds, else bilinearly (`remapbil`; attribute
`remapping`). The sea-ice extent is computed on the model's grid: the mean over the years of
the area (areacello, else cdo gridarea) of the cells with at least 15 % sea ice. The
temperature at depth is interpolated linearly in depth on the model's levels (nominal depths;
the top value above the first level; undefined below the last defined level) before
remapping. The overturning streamfunction is interpolated linearly from the model's own
latitudes and depths; `amoc_max` is taken on those. The source variable, years and files
of each field are in its attributes.
