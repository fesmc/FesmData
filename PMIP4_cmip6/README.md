# PMIP4 climatologies (CMIP6 lgm, midHolocene, piControl)

Monthly, annual and seasonal mean near-surface air temperature and precipitation, with
orography and land and land-ice fractions, of the PMIP4/CMIP6 Last Glacial Maximum (`lgm`,
21 ka), mid-Holocene (`midHolocene`, 6 ka) and preindustrial (`piControl`) simulations, on
each model's atmosphere grid. With them, for each run, the ocean and sea ice on a common
regular 1° grid: monthly SST and sea-ice concentration, sea-ice extent, annual mean potential
temperature at standard depths and the Atlantic meridional overturning streamfunction. The
climatologies are the means over the last 100 years of each run (temperature at depth: 30
years).

- PMIP4: Kageyama, M., Braconnot, P., Harrison, S. P., et al.: The PMIP4 contribution to
  CMIP6 - Part 1: Overview and over-arching analysis plan, Geosci. Model Dev., 11,
  1033-1057, 2018, [doi:10.5194/gmd-11-1033-2018](https://doi.org/10.5194/gmd-11-1033-2018).
- Model data: the ESGF data citation of each model and experiment
  (doi:10.22033/ESGF/CMIP6.\<n\>, WDCC citation service), in the global attributes
  `references` and `doi`.

## Models

All CMIP6 models with a PMIP4 `lgm` or `midHolocene` run on ESGF (CEDA, DKRZ and NCI
indexes, November 2026), with their `piControl`: 6 with lgm (4 of them also with
midHolocene) and 14 with midHolocene only. Data DOIs and the years of the atmosphere
climatologies:

| Model | Institution | Member | lgm | midHolocene | piControl |
|---|---|---|---|---|---|
| ACCESS-ESM1-5 | CSIRO | r1i1p1f1 |  | [13704](https://doi.org/10.22033/ESGF/CMIP6.13704) (701-800) | [4312](https://doi.org/10.22033/ESGF/CMIP6.4312) (1001-1100) |
| AWI-ESM-1-1-LR | AWI | r1i1p1f1 | [9330](https://doi.org/10.22033/ESGF/CMIP6.9330) (3901-4000) | [9332](https://doi.org/10.22033/ESGF/CMIP6.9332) (3106-3205) | [9335](https://doi.org/10.22033/ESGF/CMIP6.9335) (1855-1954) |
| CESM2 | NCAR | r1i1p1f1 |  | [7674](https://doi.org/10.22033/ESGF/CMIP6.7674) (601-700) | [7733](https://doi.org/10.22033/ESGF/CMIP6.7733) (1101-1200) |
| CESM2-FV2 | NCAR | r1i2p2f1 | [17642](https://doi.org/10.22033/ESGF/CMIP6.17642) (401-500) |  | [11301](https://doi.org/10.22033/ESGF/CMIP6.11301) (51-150) |
| CESM2-WACCM-FV2 | NCAR | r1i2p2f1 | [17643](https://doi.org/10.22033/ESGF/CMIP6.17643) (1-100) |  | [11302](https://doi.org/10.22033/ESGF/CMIP6.11302) (201-300) |
| EC-Earth3 | EC-Earth-Consortium | r1i1p1f1 |  | [11224](https://doi.org/10.22033/ESGF/CMIP6.11224) (3270-3369) | [4842](https://doi.org/10.22033/ESGF/CMIP6.4842) (2660-2759) |
| EC-Earth3-LR | EC-Earth-Consortium | r1i1p1f1 |  | [4801](https://doi.org/10.22033/ESGF/CMIP6.4801) (2348-2447) | [4847](https://doi.org/10.22033/ESGF/CMIP6.4847) (2320-2419) |
| EC-Earth3-Veg | EC-Earth-Consortium | r1i1p1f1 |  | [18105](https://doi.org/10.22033/ESGF/CMIP6.18105) (3439-3538) | [4848](https://doi.org/10.22033/ESGF/CMIP6.4848) (3750-3849) |
| FGOALS-f3-L | CAS | r1i1p1f1 |  | [12014](https://doi.org/10.22033/ESGF/CMIP6.12014) (1120-1219) | [3447](https://doi.org/10.22033/ESGF/CMIP6.3447) (1061-1160) |
| FGOALS-g3 | CAS | r1i1p1f1 |  | [3409](https://doi.org/10.22033/ESGF/CMIP6.3409) (1027-1126) | [3448](https://doi.org/10.22033/ESGF/CMIP6.3448) (800-899) |
| GISS-E2-1-G | NASA-GISS | r1i1p1f1 |  | [7225](https://doi.org/10.22033/ESGF/CMIP6.7225) (2900-2999) | [7380](https://doi.org/10.22033/ESGF/CMIP6.7380) (4901-5000) |
| HadGEM3-GC31-LL | NERC / MOHC | r1i1p1f1 |  | [12129](https://doi.org/10.22033/ESGF/CMIP6.12129) (2250-2349) | [6294](https://doi.org/10.22033/ESGF/CMIP6.6294) (3750-3849) |
| INM-CM4-8 | INM | r1i1p1f1 | [5075](https://doi.org/10.22033/ESGF/CMIP6.5075) (2000-2099) | [5077](https://doi.org/10.22033/ESGF/CMIP6.5077) (1980-2079) | [5080](https://doi.org/10.22033/ESGF/CMIP6.5080) (2281-2380) |
| IPSL-CM6A-LR | IPSL | r1i1p1f1 |  | [5229](https://doi.org/10.22033/ESGF/CMIP6.5229) (2300-2399) | [5251](https://doi.org/10.22033/ESGF/CMIP6.5251) (3750-3849) |
| MIROC-ES2L | MIROC | r1i1p1f2 | [5644](https://doi.org/10.22033/ESGF/CMIP6.5644) (3200-3299) | [5646](https://doi.org/10.22033/ESGF/CMIP6.5646) (8000-8099) | [5710](https://doi.org/10.22033/ESGF/CMIP6.5710) (2250-2349) |
| MPI-ESM1-2-LR | MPI-M | r1i1p1f1 | [6642](https://doi.org/10.22033/ESGF/CMIP6.6642) (2250-2349) | [6644](https://doi.org/10.22033/ESGF/CMIP6.6644) (1401-1500) | [6675](https://doi.org/10.22033/ESGF/CMIP6.6675) (2750-2849) |
| MRI-ESM2-0 | MRI | r1i1p1f1 |  | [6860](https://doi.org/10.22033/ESGF/CMIP6.6860) (2051-2150) | [6900](https://doi.org/10.22033/ESGF/CMIP6.6900) (2451-2550) |
| NESM3 | NUIST | r1i1p1f1 |  | [8773](https://doi.org/10.22033/ESGF/CMIP6.8773) (1798-1897) | [8776](https://doi.org/10.22033/ESGF/CMIP6.8776) (900-999) |
| NorESM1-F | NCC | r1i1p1f1 |  | [11591](https://doi.org/10.22033/ESGF/CMIP6.11591) (1601-1700) | [11595](https://doi.org/10.22033/ESGF/CMIP6.11595) (1601-1700) |
| NorESM2-LM | NCC | r1i1p1f1 |  | [8079](https://doi.org/10.22033/ESGF/CMIP6.8079) (2101-2200) | [8217](https://doi.org/10.22033/ESGF/CMIP6.8217) (2001-2100) |

CESM2-FV2 and CESM2-WACCM-FV2: lgm only, with the piControl of the same physics (r1i2p2f1,
in the AWI pool; ESGF now lists only r1i1p1f1). The CESM2-FV2 lgm run (physics p2) is
indistinguishable from the LGM run of the Paleoclimate-Calibrated CESM2 (Zhu et al., 2022;
global annual mean cooling -6.81 vs -6.82 K, the same cooling over the Laurentide ice sheet):
it appears to be that simulation published on ESGF (see Zhu2022_PaleoCalibr). HadGEM3-GC31-LL:
midHolocene published by NERC, piControl by MOHC. IPSL-CM6A-LR midHolocene: r1i1p1f1, the
standard forcing (thetao is published for r1i1p1f4 only, so `to_ann` is missing).

### Inventory

The CMIP6 variables of each run and member: x used (in the pools on Albedo), o on ESGF but
not obtainable, (m) published for another member only, - not published. Amon tas, pr; Omon
tos, thetao, msftmz (x (yz): msftyz, where msftmz is not published); SImon siconc (x (a):
siconca on the atmosphere grid, where siconc is not published); fx orog, sftlf, sftgif; Ofx
areacello.

| Model | Experiment | Member | tas | pr | tos | thetao | msftmz/yz | siconc(a) | orog | sftlf | sftgif | areacello |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ACCESS-ESM1-5 | midHolocene | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |
| ACCESS-ESM1-5 | piControl | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |
| AWI-ESM-1-1-LR | lgm | r1i1p1f1 | x | x | x | x | - | x | x | x | x | - |
| AWI-ESM-1-1-LR | midHolocene | r1i1p1f1 | x | x | - | - | - | x (a) | x | x | x | - |
| AWI-ESM-1-1-LR | piControl | r1i1p1f1 | x | x | x | x | - | x | x | x | x | - |
| CESM2 | midHolocene | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |
| CESM2 | piControl | r1i1p1f1 | x | x | x | x | - | x | x | x | x | x |
| CESM2-FV2 | lgm | r1i2p2f1 | x | - | x | x | x | x | x | - | - | x |
| CESM2-FV2 | piControl | r1i2p2f1 | x | (m) | x | (m) | x | x | x | (m) | (m) | (m) |
| CESM2-WACCM-FV2 | lgm | r1i2p2f1 | x | x | x | x | x | x | x | x | - | x |
| CESM2-WACCM-FV2 | piControl | r1i2p2f1 | x | (m) | x | (m) | x | x | x | (m) | (m) | (m) |
| EC-Earth3 | midHolocene | r1i1p1f1 | x | x | x | x | x (yz) | x | - | - | - | - |
| EC-Earth3 | piControl | r1i1p1f1 | x | x | x | x | x (yz) | x | - | x | - | x |
| EC-Earth3-LR | midHolocene | r1i1p1f1 | x | x | x | x | x (yz) | x | - | x | - | x |
| EC-Earth3-LR | piControl | r1i1p1f1 | x | x | x | x | x (yz) | x | - | x | - | x |
| EC-Earth3-Veg | midHolocene | r1i1p1f1 | x | x | x | x | x (yz) | x | - | - | - | - |
| EC-Earth3-Veg | piControl | r1i1p1f1 | x | x | x | x | x (yz) | x | - | x | - | x |
| FGOALS-f3-L | midHolocene | r1i1p1f1 | x | x | x | x | - | x | - | - | - | - |
| FGOALS-f3-L | piControl | r1i1p1f1 | x | x | x | x | - | - | - | - | - | - |
| FGOALS-g3 | midHolocene | r1i1p1f1 | x | x | x | x | - | x | - | x | - | - |
| FGOALS-g3 | piControl | r1i1p1f1 | x | x | x | x | x | x | - | x | - | - |
| GISS-E2-1-G | midHolocene | r1i1p1f1 | x | x | x | x | - | - | - | - | - | - |
| GISS-E2-1-G | piControl | r1i1p1f1 | x | x | x | x | (m) | x (a) | x | x | x | x |
| HadGEM3-GC31-LL | midHolocene | r1i1p1f1 | x | x | x | - | - | - | - | - | - | - |
| HadGEM3-GC31-LL | piControl | r1i1p1f1 | x | x | x | x | x (yz) | x | x | x | - | x |
| INM-CM4-8 | lgm | r1i1p1f1 | x | x | x | - | - | - | x | x | x | - |
| INM-CM4-8 | midHolocene | r1i1p1f1 | x | x | x | x | x | x | x | x | x | - |
| INM-CM4-8 | piControl | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |
| IPSL-CM6A-LR | midHolocene | r1i1p1f1 | x | x | x | (m) | x (yz) | x | x | x | - | x |
| IPSL-CM6A-LR | piControl | r1i1p1f1 | x | x | x | x | x (yz) | x | x | x | - | x |
| MIROC-ES2L | lgm | r1i1p1f2 | x | x | x | x | - | x | x | x | x | x |
| MIROC-ES2L | midHolocene | r1i1p1f2 | x | x | x | x | - | x | x | x | x | x |
| MIROC-ES2L | piControl | r1i1p1f2 | x | x | x | x | x | x | x | x | x | x |
| MPI-ESM1-2-LR | lgm | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |
| MPI-ESM1-2-LR | midHolocene | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |
| MPI-ESM1-2-LR | piControl | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |
| MRI-ESM2-0 | midHolocene | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |
| MRI-ESM2-0 | piControl | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |
| NESM3 | midHolocene | r1i1p1f1 | x | x | x | x | - | x | - | - | - | - |
| NESM3 | piControl | r1i1p1f1 | x | x | x | x | - | x | - | - | - | - |
| NorESM1-F | midHolocene | r1i1p1f1 | x | x | x | - | - | x | x | x | x | x |
| NorESM1-F | piControl | r1i1p1f1 | x | x | x | - | - | x | x | x | x | x |
| NorESM2-LM | midHolocene | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |
| NorESM2-LM | piControl | r1i1p1f1 | x | x | x | x | x | x | x | x | x | x |

Gaps: CESM2-FV2 published no `pr` for its lgm run, and neither CESM2-FV2 nor CESM2-WACCM-FV2
`pr`, `thetao` or fx fields for the r1i2p2f1 piControl. No ocean fields for AWI-ESM-1-1-LR
midHolocene (sea ice: siconca) and HadGEM3-GC31-LL midHolocene (tos only); no `thetao` for
INM-CM4-8 lgm, IPSL-CM6A-LR midHolocene (r1i1p1f4 only) and NorESM1-F; no sea ice for
INM-CM4-8 lgm, FGOALS-f3-L piControl, GISS-E2-1-G midHolocene and HadGEM3-GC31-LL
midHolocene; no overturning streamfunction for AWI-ESM-1-1-LR, CESM2 piControl, FGOALS-f3-L,
FGOALS-g3 midHolocene, GISS-E2-1-G (piControl: other members only), HadGEM3-GC31-LL
midHolocene, INM-CM4-8 lgm, MIROC-ES2L lgm and midHolocene, NESM3 and NorESM1-F; no fx
fields for FGOALS-f3-L, NESM3, GISS-E2-1-G and HadGEM3-GC31-LL midHolocene, and no orog for
the EC-Earth3 models and FGOALS-g3. The sea-ice extent uses areacello of the run, else of
another experiment of the model on the same grid, else the cell areas from the cell bounds
(cdo gridarea), else areas approximated from the cell centres (FGOALS-f3-L, FGOALS-g3: no
areacello and no cell bounds; attribute `cell_area`). CESM2-WACCM-FV2 piControl: the AWI
pool lacks years 201-250 of tos and 151-200 of siconc, so SST and sea ice cover the last 50
contiguous years (attribute `years`). EC-Earth3 and EC-Earth3-Veg midHolocene: the latitude
axis of msftyz (v20231010) is invalid; the latitudes of their piControl msftyz (the same
grid) are used (attribute `comment` of `amoc`).

## Licence

The data of all 20 models are under Creative Commons Attribution-ShareAlike 4.0 (CC BY-SA
4.0) in the global attribute `license` of their CMIP6 files (copied to the prepared files);
the WDCC data citations now list CC BY 4.0 (GISS-E2-1-G: CC0 1.0), the licences to which the
modelling groups later relaxed. With the CMIP6 terms of use
(https://pcmdi.llnl.gov/CMIP6/TermsOfUse): cite the model data (DOIs above) and the PMIP4
protocol; derived products of CC BY-SA data keep CC BY-SA 4.0.

## Original data

The CMIP6 data in pools laid out as the ESGF dataset ids,
`<pool>/<activity>/<institution>/<model>/<experiment>/<member>/<table>/<variable>/<grid>/<version>/`,
listed in `CMIP6_POOL` (':'-separated, searched in order; latest readable version of each
variable; `models.jl`): Amon `tas`, `pr`, Omon `tos`, `thetao`, `msftmz` (else `msftyz`),
SImon `siconc` (else `siconca`), fx `orog`, `sftlf`, `sftgif` (on the grid of tas) and Ofx
`areacello`. The atmosphere fields are on the only grid published; the ocean fields on the
native grid (gn) where published, else the first of gr, gr1, gr2, grz, gr1z, gr2z (thetao: the
first grid with depth levels; NorESM2-LM thetao gn is on density levels). On Levante the
DKRZ pool `/pool/data/CMIP6/data` (default). On Albedo (`shared/machines/albedo.env`): the AWI
pool `/albedo/work/projects/p_pool_clim_data/CMIP6`, to which the files it missed were added
from ESGF with `CMIP/esgf_fetch.py` (last 100 years; see PMIP3_cmip5/README.md).

## Prepare and remap

```bash
julia --project=PMIP4_cmip6 PMIP4_cmip6/prepare.jl [model ...]
module load cdo; julia --project=PMIP4_cmip6 PMIP4_cmip6/prepare_ocean.jl [model ...]
julia fesmdata.jl remap $FESMDATA_PREPARED/PMIP4_cmip6/PMIP4_INM-CM4-8_lgm.nc all --name=PMIP4-INM-CM4-8-lgm
```

`prepare.jl` writes one file per model and experiment, `PMIP4_<model>_<experiment>.nc`,
with `t2m_ann`, `t2m_djf`, `t2m_jja`, `t2m_mon` (degC), `pr_ann`, `pr_djf`, `pr_jja`,
`pr_mon` (mm d-1), `z_srf` (m, orography of the experiment, e.g. with the LGM ice sheets),
`f_land` and `f_ice` (land and land-ice area fractions). `t2m_mon` and `pr_mon` are the
monthly climatologies (dimension `month`); the annual and seasonal means are their means
weighted by month length. Months are those of the model calendar: the midHolocene
climatologies are not adjusted for the changed length of the seasons. MIROC-ES2L has no
`sftgif` over the ocean, where `f_ice` is set to 0.

Only regular lon-lat grids can be remapped: AWI-ESM-1-1-LR, MPI-ESM1-2-LR and MIROC-ES2L
(and other models with spectral atmospheres) are on Gaussian grids (latitude spacing
uneven); they are prepared on their own grids but cannot be remapped yet.

`prepare_ocean.jl` writes `PMIP4_<model>_<experiment>_ocean.nc` on the regular 1° grid
`lon` 0.5..359.5, `lat` -89.5..89.5 (shared/cmip_ocean.jl):

| Variable | Units | Contents |
|---|---|---|
| `sst_mon` | degC | monthly SST climatology (tos), NaN over land |
| `sic_mon` | 1 | monthly sea-ice concentration climatology (siconc, else siconca) |
| `siext_mon` | 1 | monthly sea-ice extent mask: 1 where `sic_mon` >= 0.15, else 0 |
| `siextent_nh`, `siextent_sh` | 1e6 km2 | monthly sea-ice extent of each hemisphere (attributes `march`, `september`) |
| `to_ann` | degC | annual mean potential temperature (thetao) at `depth` 5, 50, 100, 200, 300, 500, 700, 1000, 1500, 2000 m |
| `amoc` | Sv | annual mean Atlantic meridional overturning streamfunction (msftmz or msftyz, basin atlantic_arctic_ocean) on `lat` × `depth_moc` (0-6000 m every 100 m) |
| `amoc_max` | Sv | its maximum below 500 m between 20 and 60 N |

The time means are taken on the model's grid (SST, sea ice and overturning: the last 100
years; temperature at depth: the last 30 years, or the last 30 complete years in the pool
where it holds scattered years, attribute `years`), then remapped with cdo: conservatively
(`remapcon`) where the grid has cell bounds (all CMIP6 ocean grids), else bilinearly
(`remapbil`; attribute `remapping`). The sea-ice extent is computed on the model's grid: the
mean over the years of the area (areacello, else cdo gridarea) of the cells with at least 15 %
sea ice. The temperature at depth is interpolated linearly in depth on the model's levels
(nominal depths; the top value above the first level; undefined below the last defined
level) before remapping. The overturning streamfunction is interpolated linearly from the
model's own latitudes (msftyz: the nominal latitudes of its grid rows) and depths;
`amoc_max` is taken on those. The source variable, years and files of each field are in
its attributes; fields without data are named in the global attribute `missing`.
