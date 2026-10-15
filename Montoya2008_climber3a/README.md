# CLIMBER-3α present-day and LGM climatologies (Montoya and Levermann, 2008)

Climatologies of the present-day and Last Glacial Maximum (LGM) simulations of the Earth
system model of intermediate complexity CLIMBER-3α: surface air temperature (annual and
JJA means), annual precipitation and the surface height of the atmosphere model, and the
ocean potential temperature. At the LGM, with the surface wind stress over the ocean
scaled by 1.7, the Atlantic overturning has two stable states, weak (`lgm_1p7weak`) and
strong (`lgm_1p7strong`).

- Montoya, M. and Levermann, A.: Surface wind-stress threshold for glacial Atlantic
  overturning, Geophys. Res. Lett., 35, L03608, 2008,
  [doi:10.1029/2007GL032560](https://doi.org/10.1029/2007GL032560).
- Model: Montoya, M., Griesel, A., Levermann, A., Mignot, J., Hofmann, M., Ganopolski, A.,
  and Rahmstorf, S.: The earth system model of intermediate complexity CLIMBER-3α. Part I:
  description and performance for present-day conditions, Clim. Dyn., 25, 237-263, 2005,
  [doi:10.1007/s00382-005-0044-1](https://doi.org/10.1007/s00382-005-0044-1).

## Licence

CC BY 4.0: cite both papers.

## Original data

The original files (FERRET output by M. Montoya, 2009), kept in the old PIK archive
(`hpc:/data/sicopolis/data/CLIMBER3a/`, copy on Levante in `/work/ba1442/data/CLIMBER3a/`),
are published unchanged, with a description, in
[github.com/fesmc/Montoya2008-CLIMBER3a](https://github.com/fesmc/Montoya2008-CLIMBER3a).
`prepare.jl` downloads the release v1.0.0 (`datamanifest.toml`, entry
`montoya2008_climber3a`). There are no monthly fields.

The interpolated files in the archive (`Montoya2008hi/`, `Montoya2008_jorgebilin/`) and
the v1 products (`ice_data/<domain>/<grid>/Montoya2008_sig250km/`, `..._sig100km/`, made
by `gridding` with a lapse-rate reduction to sea level and Gaussian smoothing) are not
used.

## Prepare and remap

```bash
julia --project=Montoya2008_climber3a Montoya2008_climber3a/prepare.jl
julia fesmdata.jl remap Paleoclimate
```

`prepare.jl` writes two files per simulation (`present`, `lgm_1p7weak`,
`lgm_1p7strong`) to `$FESMDATA_PREPARED/Montoya2008_climber3a/`, each on its model grid
with longitudes shifted to -180:180:

- `CLIMBER3a_<simulation>.nc`, atmosphere grid (22.5° x 7.5°): `t2m_ann`, `t2m_jja`
  (degC), `pr_ann` (mm d-1), `z_srf` (m), the surface height of the atmosphere model
  (`horo.cdf`; the LGM one for both LGM states), and `f_land`, 1 where `z_srf` > 0. The
  model's surface height is 0 over the ocean, at least 1 m over land, and at most 1500 m
  (present) or 3000 m (LGM).
- `CLIMBER3a_<simulation>_ocean.nc`, ocean grid (3.75°, 24 levels to 5242.5 m): `to`
  (potential temperature, degC) on `depth`, missing over land and below the sea floor.
  The present-day file is `lgm_present_ocean.cdf` in the original data.

They are remapped as the products `Paleoclimate-CLIMBER3a-<simulation>` and
`Paleoclimate-CLIMBER3a-<simulation>-ocean` (`../Paleoclimate/remap.toml`). The fields
are remapped as they are, without a lapse-rate correction: use `z_srf` to correct the
temperatures for the surface height of the model.
