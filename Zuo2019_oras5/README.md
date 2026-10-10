# Ocean temperature and salinity from ORAS5 (Zuo et al., 2019)

Potential temperature and salinity on depth levels from the ECMWF ocean reanalysis
ORAS5, as monthly climatologies and annual means, from:

Zuo, H., Balmaseda, M. A., Tietsche, S., Mogensen, K., and Mayer, M.: The ECMWF
operational ensemble reanalysis-analysis system for ocean and sea ice: a description of
the system and assessment, Ocean Sci., 15, 779-808, 2019,
[doi:10.5194/os-15-779-2019](https://doi.org/10.5194/os-15-779-2019).

ORAS5 replaces ORAS4 of the v1 products (`ERA-INT-ORAS4`).

## Licence

ORAS5 is distributed by the Copernicus Climate Change Service under CC BY 4.0 (CDS
dataset `reanalysis-oras5`). Cite the paper above and acknowledge ECMWF / Copernicus.

## Original data

The native grid of ORAS5 is ORCA025 (tripolar, 1/4°, 75 levels). We use the monthly
means regridded by ECMWF to a regular 1°x1° grid (`r1x1`), since remapping needs a
regular grid, from the ICDC collection on the DKRZ pool (Levante only):

```
/pool/data/ICDC/ocean_syntheses/oras5/r1x1/{votemper,vosaline}/opa0/<var>_ORAS5_1m_<YYYYMM>_r1x1.nc
/pool/data/ICDC/ocean_syntheses/oras5/r1x1/LSM_r1x1/tmask_r1x1.nc
```

These cover 1979-2018, for the five ensemble members `opa0`-`opa4`; we use `opa0`. The
entry `oras5_r1x1` in `datamanifest.toml` points to this folder (absolute path, not
downloaded). Elsewhere, ORAS5 is public on the Copernicus Climate Data Store
(https://cds.climate.copernicus.eu/datasets/reanalysis-oras5, free login), 1958 to
present but only on the native ORCA025 grid and for one member, so it would have to be
regridded before `prepare.jl` (not done here).

## Prepare and remap

```bash
julia --project=Zuo2019_oras5 Zuo2019_oras5/prepare.jl
julia -t 16 fesmdata.jl remap $FESMDATA_WORK/prepared/Zuo2019_oras5/ORAS5_1981-2010.nc Greenland --name=Ocean-ORAS5-1981-2010
```

`prepare.jl` reads each monthly file once (about 20 GB, a few minutes; run it on a
compute node) and writes to `$FESMDATA_WORK/prepared/Zuo2019_oras5/`:

- `ORAS5_1981-2010.nc`: monthly climatology 1981-2010, `to` (degC) and `so` (PSU),
  dimensions `(lon, lat, depth, month)`;
- `ORAS5_annual_1979-2018.nc`: annual means 1979-2018 (months weighted by their
  length), `to` and `so`, dimensions `(lon, lat, depth, time)`, `time` the year.

There is no 1991-2020 climatology yet, since the pool ends in 2018.

## Notes

- `to` is potential temperature (`votemper`), `so` salinity (`vosaline`) in PSU, as in
  the source; depth is that of the T levels (0.5-5902 m, 75 levels).
- The land-sea mask `tmask_r1x1.nc` is applied, as ECMWF recommends for the r1x1 files
  (without it, the regridded fields have values in some land cells along the coasts).
- Land and sea floor are missing; nothing is extrapolated. The v1 files had land cells
  filled.
- Longitudes are rotated from 0:359 to -180:179.
