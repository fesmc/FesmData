# MEaSUREs Multi-year Greenland Ice Sheet Velocity Mosaic, Version 1

GrIS ice surface velocities

**Source:** https://nsidc.org/data/nsidc-0670/versions/1

**Citation:** Joughin, I., Smith, B. and Howat, I.: A complete map of Greenland ice velocity derived from satellite data collected over 20 years. Journal of Glaciology, 64(243), 1-11, doi:10.1017/jog.2017.73, 2018

## Steps

Download the `.tif` files with the tool Earthdata Download.

Run the script `process_data.ipynb` that:

1. **Loads the raw `.tif` files** — reads the four velocity and error components (`vx`, `vy`, `ex`, `ey`) from the original 250 m resolution GeoTIFF files using `rasterio`. And builds an xarray dataset that is saved to `./output/vel_J18.nc`.

2. **Reprojects to the target grid** (original grid EPSG:3413) and regrids from 250 m to 8 km. For each velocity component, both the mean and the sub-grid standard deviation are computed via:
   $$\sigma_\mathrm{sub} = \sqrt{E[X^2] - E[X]^2}$$

3. **Propagates errors** — the total error for each component combines the instrumental error (averaged over the 8 km cell) and the sub-grid variability in quadrature:
   $$\sigma_\mathrm{total} = \sqrt{\sigma_\mathrm{inst}^2 + \sigma_\mathrm{sub}^2}$$

4. **Builds the final dataset** and saves it to `./output/vel_J18_8km.nc`. The output variables are:

| Variable | Description |
|----------|-------------|
| `uxy_srf` | Total ice surface velocity (m/yr) |
| `uxy_err` | Total velocity error (m/yr) |
| `uxy_err_cor` | Total velocity error including an additional 3% calibration uncertainty (m/yr) |
| `u_x` | x velocity component (m/yr) |
| `u_y` | y velocity component (m/yr) |
| `ux_err_inst` | Instrumental error on `u_x` (m/yr) |
| `uy_err_inst` | Instrumental error on `u_y` (m/yr) |
| `ux_std` | Sub-grid standard deviation of `u_x` (m/yr) |
| `uy_std` | Sub-grid standard deviation of `u_y` (m/yr) |
| `ux_err` | Total error on `u_x` (m/yr) |
| `uy_err` | Total error on `u_y` (m/yr) |