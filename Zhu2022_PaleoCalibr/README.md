# CESM2 PaleoCalibr LGM and preindustrial climatologies (Zhu et al., 2022)

Monthly, annual and seasonal mean near-surface air temperature and precipitation, with
surface altitude and land fraction, of the Last Glacial Maximum (PMIP4 protocol, 21 ka) and
preindustrial simulations of the Paleoclimate-Calibrated CESM2 (CESM2.1.1 with the cloud
microphysics calibrated on the LGM; f19_g17, CAM 1.9° x 2.5°), in the form of PMIP4_cmip6
(files `PMIP4_CESM2-PaleoCalibr_{lgm,piControl}.nc`). The climatologies are the means over
years 401-500, the last 100 years of each run.

The ESGF CMIP6 run CESM2-FV2 lgm (r1i2p2f1, in PMIP4_cmip6) is indistinguishable from this
one (global annual cooling -6.81 K against -6.82 K here, the same cooling of the Laurentide
ice sheet): it appears to be the PaleoCalibr LGM simulation as published on ESGF.

- Zhu, J., Otto-Bliesner, B. L., Brady, E. C., et al.: LGM paleoclimate constraints inform
  cloud parameterizations and equilibrium climate sensitivity in CESM2, J. Adv. Model. Earth
  Syst., 14, e2021MS002776, 2022, [doi:10.1029/2021MS002776](https://doi.org/10.1029/2021MS002776).
- Zhu, J.: Simulation data of the DECK, CMIP6 historical, and PMIP4 LGM simulations using the
  Paleoclimate-Calibrated CESM2, NSF NCAR Geoscience Data Exchange, 2021,
  [doi:10.5065/bdr7-wt42](https://doi.org/10.5065/bdr7-wt42).

## Licence

Creative Commons Attribution 4.0 International (CC BY 4.0): cite the paper and the dataset.

## Original data

NCAR GDEX dataset d583116 (https://gdex.ucar.edu/datasets/d583116/, open download, no
account needed): the CAM and POP monthly history time series of the PaleoCalibr runs, in
50-year chunks. FesmData uses the cases `b.e21.B1850.f19_g17.PaleoCalibr.21ka.02` (lgm) and
`b.e21.B1850.f19_g17.PaleoCalibr.PI.02` (piControl), years 401-500 (chunks `040101-045012`
and `045101-050012`):

| Files | Variables | Size |
|---|---|---|
| `<case>.cam.h0.<var>.<chunk>.nc` | `TREFHT`, `PRECC`, `PRECL`, `PHIS`, `LANDFRAC` | 0.4 GB |
| `<case>.pop.h.<var>.<chunk>.nc` | `IFRAC`, `MOC` | 0.9 GB |
| `<case>.pop.h.TEMP_top.<chunk>.nc` | `TEMP`, top level (5 m), years 401-500 | 0.7 GB |
| `<case>.pop.h.TEMP_0-2200m.047101-050012.nc` | `TEMP`, levels down to 2200 m, years 471-500 | 9.4 GB |

On Albedo they are in the AWI pool, `/albedo/work/projects/p_pool_clim_data/PaleoCalibr`
(`PALEOCALIBR_DIR`), beside the surface temperature `TS` of the 21ka, PI and historical runs
(years 1-300). `fetch.sh` downloads them into `PALEOCALIBR_DIR`, skipping the files present.
The `TEMP` files (7.4 GB per chunk) are downloaded to `SCRATCH_DIR`, cut with NCO to the two
subsets above and deleted:

```bash
module load nco; bash Zhu2022_PaleoCalibr/fetch.sh
```

The full dataset holds more: 38 CAM and 10 POP variables of all 500 years of these runs (in
10 chunks), and the other PaleoCalibr runs (historical, abrupt-4xCO2, 1pctCO2). The list of all files, with their sizes, is at
https://gdex.ucar.edu/datasets/d583116/filelist/; each file downloads from
`https://osdf-director.osg-htc.org/ncar/gdex/d583116/<file>`, e.g. into the pool:

```bash
cd /albedo/work/projects/p_pool_clim_data/PaleoCalibr
wget -nc https://osdf-director.osg-htc.org/ncar/gdex/d583116/b.e21.B1850.f19_g17.PaleoCalibr.21ka.02.cam.h0.PSL.045101-050012.nc
```

## Prepare

```bash
julia --project=Zhu2022_PaleoCalibr Zhu2022_PaleoCalibr/prepare.jl
```

`prepare.jl` writes `t2m_ann`, `t2m_djf`, `t2m_jja`, `t2m_mon` (degC, from TREFHT), `pr_ann`,
`pr_djf`, `pr_jja`, `pr_mon` (mm d-1, PRECC + PRECL), `z_srf` (m, PHIS / g) and `f_land`
(LANDFRAC); no land-ice fraction is published. CAM stamps a monthly mean at the end of its
month, so the month of each record is taken from the middle of its time bounds.

## Ocean and sea ice

```bash
module load cdo; julia --project=Zhu2022_PaleoCalibr Zhu2022_PaleoCalibr/prepare_ocean.jl
```

`prepare_ocean.jl` writes `PMIP4_CESM2-PaleoCalibr_{lgm,piControl}_ocean.nc` in the form of
the ocean files of PMIP4_cmip6 (regular 1° grid, shared/cmip_ocean.jl; variables in
PMIP4_cmip6/README.md), from the POP monthly history time series of the same cases:
`sst_mon` from the top level of `TEMP` (5 m), `sic_mon`, `siext_mon` and the hemispheric
extents from `IFRAC` (ice fraction from the coupler, on the ocean grid; extent with the POP
cell areas `TAREA`), `to_ann` from `TEMP` of years 471-500, and `amoc`, `amoc_max` from `MOC`
(region "Atlantic Ocean + Mediterranean Sea + Labrador Sea + GIN Sea + Arctic Ocean", the sum
of the Eulerian mean, eddy-induced (bolus) and submesoscale components; on `lat_aux_grid` and
`moc_z`). The POP grid has no cell bounds in the files: the fields are remapped bilinearly
(cdo `remapbil`).
