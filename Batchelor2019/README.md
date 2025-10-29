# Northern Hemisphere ice masks

Batchelor et al. (2019) produced ice-coverage masks
for the Northern Hemisphere for various paleo time slices.
These are originally provided in shapefiles here:

https://osf.io/7jen3/

Original reference:
https://www.nature.com/articles/s41467-019-11601-2

The script(s) provided here will process the shapefiles
into masks on regular grids and save the snapshots to
a common NetCDF file.

# Processing steps

1. Download the data to a directory.
2. Modify map_batchelor.jl to use that source directory. Adjust resolution of output NetCDF file.
3. Run the script.


This will produce the NetCDF file:

Batchelor2019_ice_masks.nc
 
