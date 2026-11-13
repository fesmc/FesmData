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

NCAR GDEX dataset d583116 (https://gdex.ucar.edu/datasets/d583116/, open download), CAM
monthly history time series of the cases `b.e21.B1850.f19_g17.PaleoCalibr.21ka.02` (lgm) and
`b.e21.B1850.f19_g17.PaleoCalibr.PI.02` (piControl): `cam.h0.{TREFHT,PRECC,PRECL,PHIS,LANDFRAC}`,
chunks `040101-045012` and `045101-050012`, kept on Albedo in
`/albedo/work/projects/p_pool_clim_data/gdex/d583116` (`PALEOCALIBR_DIR`):

```bash
cd /albedo/work/projects/p_pool_clim_data/gdex/d583116
wget -nc https://osdf-director.osg-htc.org/ncar/gdex/d583116/b.e21.B1850.f19_g17.PaleoCalibr.21ka.02.cam.h0.TREFHT.040101-045012.nc
```

## Prepare

```bash
julia --project=Zhu2022_PaleoCalibr Zhu2022_PaleoCalibr/prepare.jl
```

`prepare.jl` writes `t2m_ann`, `t2m_djf`, `t2m_jja`, `t2m_mon` (degC, from TREFHT), `pr_ann`,
`pr_djf`, `pr_jja`, `pr_mon` (mm d-1, PRECC + PRECL), `z_srf` (m, PHIS / g) and `f_land`
(LANDFRAC); no land-ice fraction is published. CAM stamps a monthly mean at the end of its
month, so the month of each record is taken from the middle of its time bounds.
