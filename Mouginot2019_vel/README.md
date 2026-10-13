# Antarctic ice surface velocity, phase-based (Mouginot et al., 2019)

Surface velocity of the Antarctic Ice Sheet and its ice shelves at 450 m on the Antarctic
polar stereographic grid (EPSG:3031): interferometric phase mapping over most of the
continent (mostly 2007-2018), completed by speckle and feature tracking along the coasts
(mostly 2013-2017), with data of 1996-2018 where needed. It supersedes the tracking-based
map NSIDC-0484 (`Rignot2011_vel`), with a precision about 10 times higher in the interior:

Mouginot, J., Rignot, E. and Scheuchl, B.: MEaSUREs Phase-Based Antarctica Ice Velocity
Map, Version 1, NASA NSIDC DAAC, 2019,
[doi:10.5067/PZ3NJ5RXRH10](https://doi.org/10.5067/PZ3NJ5RXRH10).

Mouginot, J., Rignot, E. and Scheuchl, B.: Continent-wide, interferometric SAR phase,
mapping of Antarctic ice velocity, Geophys. Res. Lett., 46, 9710-9718, 2019,
[doi:10.1029/2019GL083826](https://doi.org/10.1029/2019GL083826).

## Licence

NASA Earth science data (NSIDC DAAC): open, with no restrictions on use or
redistribution. NSIDC asks to cite the data set and the article.

## Original data

NSIDC-0754 v1, https://nsidc.org/data/nsidc-0754/versions/1, needs a NASA Earthdata
login. The file `antarctic_ice_vel_phase_map_v01.nc` (about 40 GB) goes to
`$FESMDATA_SOURCES/nsidc0754_v1_antarctica_vel/` (datamanifest key
`nsidc0754_v1_antarctica_vel`). With a `~/.netrc` for urs.earthdata.nasa.gov:

```bash
cd $FESMDATA_SOURCES/nsidc0754_v1_antarctica_vel
curl -n -L -c ~/.urs_cookies -b ~/.urs_cookies -O \
    https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/MEASURES/NSIDC-0754/1/1996/01/01/antarctic_ice_vel_phase_map_v01.nc
```

## Prepare and remap

```bash
julia -t 8 --project=Mouginot2019_vel Mouginot2019_vel/prepare.jl
julia -t 8 fesmdata.jl remap Velocity Mouginot2019
```

`prepare.jl` (use a compute node) writes
`$FESMDATA_PREPARED/Mouginot2019_vel/Mouginot2019_VEL.nc` on the 450 m grid of the
map, in m yr-1:

- `ux_srf`, `uy_srf`: eastward and northward surface velocity, rotated from `VX`, `VY`
  (remapping rotates them back to the axes of the target grid);
- `uxy_srf`: surface speed, from `VX`, `VY` at 450 m;
- `ux_srf_err`, `uy_srf_err`: the errors `ERRX`, `ERRY` of the components along the x and
  y axes of EPSG:3031, the axes of the Antarctica grids (an indication of the relative
  quality rather than an absolute error, says the user guide).

No data (ocean, gaps) is missing, as are the errors at about 1500 points where `ERRX`,
`ERRY` are Inf in the source (in Velocity v2.1.0 these made the errors Inf on the cells
around them). The standard deviations `STDX`, `STDY`, the number of
scenes `CNT` and the method of measurement `SOURCE` (phase, tracking, hybrid) of the
original file are left out. The few gaps over the ice are filled on the grids by the
remapping (`fill` in `Velocity/remap.toml`).
