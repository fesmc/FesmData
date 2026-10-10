# Bring your own data

Any gridded dataset (geothermal heat flow, basal melt, surface velocity, ...) can be
put on the FesmData grids in two steps:

1. **Prepare**: write the data as a NetCDF file on its own (native) grid, in a simple
   standard form. This is specific to each source and lives in the source's folder.
2. **Remap**: one command puts that file onto any domains and grids, in the usual
   layout `$ICE_DATA/v2/<Domain>/<GRID>/`.

```bash
julia --project=Lucazeau2019_ghf Lucazeau2019_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Lucazeau2019_ghf/Lucazeau2019_GHF.nc Antarctica Greenland --name=GHF-Lucazeau2019
```

This writes, e.g., `$ICE_DATA/v2/Antarctica/ANT-8KM/ANT-8KM_GHF-Lucazeau2019.nc` for
every grid of Antarctica and Greenland.

## 1. Prepare a source

Make a folder for the source, named after it (e.g. `Lucazeau2019_ghf/`), with:

- `README.md`: what the data are, where they come from, how to cite them, and their
  licence;
- `prepare.jl` (with its own `Project.toml`): get the original files and write the
  prepared file(s) to `$FESMDATA_WORK/prepared/<source folder>/` (in Julia:
  `prepared_dir("<source folder>")` from `shared/provenance.jl`).

A prepared file is a NetCDF file with:

- **a regular grid**, given by 1D coordinate variables, either
  - `lon`, `lat` in degrees (`units = "degrees_east"`, `"degrees_north"`): global or
    regional, with longitudes in -180:180 (preferred) or 0:360, in any order, and
    latitudes ascending or descending; or
  - `x`, `y` in m or km, with the fields pointing to a grid-mapping variable
    (`grid_mapping` attribute) that holds a PROJ string in `proj_params` or `proj4`;
- **2D fields** on that grid, each with `units` and `long_name`, and missing values
  as `_FillValue` or NaN;
- **global attributes** `title`, `references` and, where there is one, `doi` (copied
  to the remapped files).

Prepare the data at their own resolution: no smoothing or regridding, that is left to
the remapping. Keep units and names close to the original (but in SI-like units with
plain names, e.g. `ghf` in mW m-2).

## 2. Remap

```bash
julia fesmdata.jl remap <file.nc> <Domain> | <GRID> | all ... [--vars=a,b] [--name=NAME] [--overwrite]
```

- Targets are domains (e.g. `Antarctica`, all of its grids), grids (e.g. `GRL-4KM`), or
  `all`. The names are listed under Domains and grids (`shared/README.md`).
- `--vars=a,b` remaps only these fields (default: all 2D fields of the file).
- `--name=NAME` names the output `<GRID>_<NAME>.nc` (default: the file name). Use
  `<THEME>-<Source>`, e.g. `GHF-Lucazeau2019`, `VEL-Joughin2018`.
- Existing files are kept unless `--overwrite`.

Each field is remapped **conservatively**: every cell gets the area-weighted mean of
the source over the cell. A source on the same projection as the grid is remapped
exactly; otherwise each cell is sampled at points spaced at most half the source
spacing. A coarse source on a fine grid therefore keeps the blocky look of its cells
(no interpolation).

Each output file also has `f_valid`, the fraction of each cell covered by source data
(`f_valid_<field>` per field when the fields have different coverage). Cells without
data are missing. Grids that the source does not cover at all are skipped, so a
regional source (e.g. velocities of Greenland) can be remapped onto `all`. The grid
files of each grid are written too if they are missing.

Run with threads for large grids: `julia -t 8 fesmdata.jl remap ...` (or set
`JULIA_NUM_THREADS`).

## Not supported yet

- Fields with more dimensions (e.g. time) and datasets split over several files.
- Integer or flag fields (masks); these need fractions or the dominant class rather
  than a mean.
- Projected grids described only by CF grid-mapping parameters or WKT (add a PROJ
  string as `proj_params`).
- Global lon-lat target grids (a `GLOBAL` domain), and publishing remapped datasets
  (thematic datasets such as GHF, with a release like Topo).
