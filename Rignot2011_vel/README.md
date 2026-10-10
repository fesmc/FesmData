# Antarctic ice surface velocity (Rignot et al., 2011)

Surface velocity of the Antarctic Ice Sheet and its ice shelves, a mosaic of InSAR
(and, in version 2, Landsat-8) data of 1995-2016, at 450 m on the Antarctic polar
stereographic grid (EPSG:3031):

Rignot, E., Mouginot, J. and Scheuchl, B.: MEaSUREs InSAR-Based Antarctica Ice Velocity
Map, Version 2, NASA NSIDC DAAC, 2017,
[doi:10.5067/D7GK8F5J8M8R](https://doi.org/10.5067/D7GK8F5J8M8R).

Rignot, E., Mouginot, J. and Scheuchl, B.: Ice flow of the Antarctic Ice Sheet,
Science, 333(6048), 1427-1430, 2011,
[doi:10.1126/science.1208336](https://doi.org/10.1126/science.1208336).

Mouginot, J., Rignot, E., Scheuchl, B. and Millan, R.: Comprehensive annual ice sheet
velocity mapping using Landsat-8, Sentinel-1, and RADARSAT-2 data, Remote Sens., 9(4),
364, 2017, [doi:10.3390/rs9040364](https://doi.org/10.3390/rs9040364).

## Licence

NASA Earth science data (NSIDC DAAC): open, with no restrictions on use or
redistribution (the file says "No restrictions on access or use"). NSIDC asks to cite
the data set and the articles.

## Original data

NSIDC-0484 v2, https://nsidc.org/data/nsidc-0484/versions/2, needs a NASA Earthdata
login. The file `antarctica_ice_velocity_450m_v2.nc` (6.8 GB) goes to
`$DATAMANIFEST_DATASETS_DIR/nsidc0484_v2_antarctica_vel/` (datamanifest key
`nsidc0484_v2_antarctica_vel`). With a `~/.netrc` for urs.earthdata.nasa.gov:

```bash
cd $DATAMANIFEST_DATASETS_DIR/nsidc0484_v2_antarctica_vel
curl -n -L -c ~/.urs_cookies -b ~/.urs_cookies -O \
    https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/MEASURES/NSIDC-0484/2/1996/01/01/antarctica_ice_velocity_450m_v2.nc
```

## Prepare and remap

```bash
julia -t 8 --project=Rignot2011_vel Rignot2011_vel/prepare.jl
julia -t 8 fesmdata.jl remap $FESMDATA_WORK/prepared/Rignot2011_vel/Rignot2011_VEL.nc Antarctica --name=VEL-Rignot2011
```

`prepare.jl` (4 min, 8 GB: use a compute node) writes
`$FESMDATA_WORK/prepared/Rignot2011_vel/Rignot2011_VEL.nc` on the 450 m grid of the map,
in m/yr:

- `ux_srf`, `uy_srf`: eastward and northward surface velocity, rotated from `VX`, `VY`
  (remapping rotates them back to the axes of the target grid);
- `uxy_srf`: surface speed, from `VX`, `VY` at 450 m (its cell means on coarser grids are
  larger than the speed of the mean velocity where the flow changes direction);
- `ux_srf_err`, `uy_srf_err`: the errors `ERRX`, `ERRY` of the components along the x and
  y axes of EPSG:3031, the axes of the Antarctica grids. Errors are not rotated, and their
  cell means are not the error of the cell mean.

No data (ocean, gaps; 0 in the original file) is missing. The standard deviations
`STDX`, `STDY` and the number of measurements `CNT` of the original file are left out.
