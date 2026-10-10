# Greenland ice surface velocity (Joughin et al., 2018)

Multi-year mosaic of the surface velocity of the Greenland Ice Sheet and its periphery,
from SAR and Landsat data of 1995-2015, at 250 m on the NSIDC polar stereographic north
grid (EPSG:3413):

Joughin, I., Smith, B. and Howat, I.: MEaSUREs Multi-year Greenland Ice Sheet Velocity
Mosaic, Version 1, NASA NSIDC DAAC, 2016,
[doi:10.5067/QUA5Q9SVMSJG](https://doi.org/10.5067/QUA5Q9SVMSJG).

Joughin, I., Smith, B. and Howat, I.: A complete map of Greenland ice velocity derived
from satellite data collected over 20 years, J. Glaciol., 64(243), 1-11, 2018,
[doi:10.1017/jog.2017.73](https://doi.org/10.1017/jog.2017.73).

## Licence

NASA Earth science data (NSIDC DAAC): open, with no restrictions on use or
redistribution. NSIDC asks to cite the data set and the article.

## Original data

NSIDC-0670 v1, https://nsidc.org/data/nsidc-0670/versions/1, needs a NASA Earthdata
login. The four GeoTIFF files `greenland_vel_mosaic250_<c>_v1.tif`, `<c>` = `vx`, `vy`
(velocity along the x and y axes of the grid, m/yr) and `ex`, `ey` (their errors), go to
`$DATAMANIFEST_DATASETS_DIR/nsidc0670_v1_greenland_vel/` (datamanifest key
`nsidc0670_v1_greenland_vel`). With a `~/.netrc` for urs.earthdata.nasa.gov:

```bash
cd $DATAMANIFEST_DATASETS_DIR/nsidc0670_v1_greenland_vel
for c in vx vy ex ey; do
    curl -n -L -c ~/.urs_cookies -b ~/.urs_cookies -O \
        https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/MEASURES/NSIDC-0670/1/1995/12/01/greenland_vel_mosaic250_${c}_v1.tif
done
```

## Prepare and remap

```bash
julia -t 8 --project=Joughin2018 Joughin2018/prepare.jl
julia -t 8 fesmdata.jl remap $FESMDATA_WORK/prepared/Joughin2018/Joughin2018_VEL.nc Greenland --name=VEL-Joughin2018
```

`prepare.jl` (2 min, 4 GB) writes `$FESMDATA_WORK/prepared/Joughin2018/Joughin2018_VEL.nc`
on the 250 m grid of the mosaic, in m/yr:

- `ux_srf`, `uy_srf`: eastward and northward surface velocity, rotated from `vx`, `vy`
  (remapping rotates them back to the axes of the target grid);
- `uxy_srf`: surface speed, from `vx`, `vy` at 250 m (its cell means on coarser grids are
  larger than the speed of the mean velocity where the flow changes direction);
- `ux_srf_err`, `uy_srf_err`: the errors `ex`, `ey` of the components along the x and y
  axes of EPSG:3413, the axes of the Greenland grids. Errors are not rotated, and their
  cell means are not the error of the cell mean.

No data (ocean, outside the mosaic) is missing.

The earlier Python notebook of this folder (`process_data.ipynb`, in the git history)
regridded the mosaic to an 8 km grid and combined the mean error with the sub-grid
standard deviation of each component in quadrature (plus 3 % of the velocity as a
calibration error). Remapping gives the cell means only.
