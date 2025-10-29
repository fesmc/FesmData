# Northern Hemisphere ice masks

The script(s) provided here will process the shapefiles
into masks on regular grids and save the snapshots to
a common NetCDF file.

## Source

Batchelor et al. (2019) produced ice-coverage masks
for the Northern Hemisphere for various paleo time slices.
These are originally provided in shapefiles here:

[https://osf.io/7jen3/](https://osf.io/7jen3/)

Original reference:
[https://www.nature.com/articles/s41467-019-11601-2](https://www.nature.com/articles/s41467-019-11601-2)

## Processing steps

1. Download the data to a directory.
2. Modify map_batchelor.jl to use that source directory. Adjust resolution of output NetCDF file(s).
3. Run the script. This will produce the NetCDF file:

        Batchelor2019_ice_masks.nc

    which is on a standard lon-lat grid (e.g. 0.5deg). This can be used as an input dataset.

Then if an additional dataset is desired on a projected grid:

1. Generate grid description file from file created above by running:

        ```
        ./define_latlon_grid.sh
        ```

2. Run the second part of map_batchelor.jl that relates to generating a projected dataset, like:

        NH-32KM_Batchelor2019_ice_masks.nc

## Notes

- The dataset is supposed to be defined on a projected grid. And this is
for true in all cases, except for the LGM, which is defined on a lon-lat grid.
- In the original dataset, each snapshot has a subfolder "hypothesised ice-sheet reconstructions", except, again, in the case of LGM, the subfolder is "hypothesised ice-sheet reconstruction". This should be changed by hand to match the other subfolders, in order to make the script work properly.
