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

Processing is split into two scripts: building the regular lon-lat dataset
from the shapefiles, and resampling it onto a projected target grid. The
lon-lat dataset is a prerequisite for the projected one.

### Step 1: lon-lat dataset

1. Download the shapefiles into the source directory (default:
   `Batchelor2019_NHextent`). To change the directory or resolution, edit the
   constants at the top of `build_lonlat_dataset.jl`.
2. Run:

        julia --project=. build_lonlat_dataset.jl

    This rasterizes the shapefiles onto a regular lon-lat grid (0.5deg by
    default) and writes `Batchelor2019_ice_masks.nc`, which can be used
    directly as an input dataset.

### Step 2: projected dataset

With `Batchelor2019_ice_masks.nc` in place, resample it onto a projected
target grid:

        julia --project=. build_projected_dataset.jl --grid LIS-32KM

This writes e.g. `LIS-32KM_Batchelor2019_ice_masks.nc`. The target grid is
described by `../maps/grid_<grid>.txt`, which must exist beforehand (generate
with `cdo griddes`).

Options:

| Option | Default | Description |
| --- | --- | --- |
| `--grid NAME` | `NH-32KM` | Projected target grid, matching `../maps/grid_NAME.txt` |
| `--lonlat-nc PATH` | `Batchelor2019_ice_masks.nc` | Source lon-lat NetCDF file |
| `-h`, `--help` | | Show usage |

## Notes

- The dataset is supposed to be defined on a projected grid. And this is
for true in all cases, except for the LGM, which is defined on a lon-lat grid.
- In the original dataset, each snapshot has a subfolder "hypothesised ice-sheet reconstructions", except, again, in the case of LGM, the subfolder is "hypothesised ice-sheet reconstruction". This should be changed by hand to match the other subfolders, in order to make the script work properly.
