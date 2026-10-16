# Your own gridded data

Any gridded dataset (geothermal heat flow, basal melt, surface velocity, ...) can be
put on the FesmData grids in two steps:

1. **Prepare**: write the data as a NetCDF file on its own (native) grid, in a simple
   standard form. This is specific to each source and lives in the source's folder.
2. **Remap**: one command puts that file onto any domains and grids, in the usual
   layout `$FESMDATA_PRODUCTS/<Domain>/<GRID>/`, including global lon-lat grids.

```bash
julia --project=Lucazeau2019_ghf Lucazeau2019_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_PREPARED/Lucazeau2019_ghf/Lucazeau2019_GHF.nc Antarctica Global --name=GHF-Lucazeau2019
```

This writes, e.g., `$FESMDATA_PRODUCTS/Antarctica/ANT-8KM/ANT-8KM_GHF-Lucazeau2019.nc` and
`$FESMDATA_PRODUCTS/Global/GLOBAL-1DEG/GLOBAL-1DEG_GHF-Lucazeau2019.nc`, on every grid of
Antarctica and of the global lon-lat grids. The grid files of a grid, if missing, are
downloaded from the dataset [Grids](https://fesmc.github.io/FesmData/domains.html#grid-files)
when the grid is released there, else written.

To release it with FesmData, make it a product of a thematic dataset, e.g. GHF (see
[Adding a dataset](https://fesmc.github.io/FesmData/adding.html#thematic-datasets)).
Non-gridded data (time series, sites, profiles) are not remapped: see
[Records format](https://fesmc.github.io/FesmData/records.html).

## 1. Prepare a source

Make a folder for the source, named after it (e.g. `Lucazeau2019_ghf/`), with:

- `README.md`: what the data are, where they come from, how to cite them, and their
  licence (check that it allows redistributing derived products before releasing
  them);
- `prepare.jl` (with its own `Project.toml`): get the original files and write the
  prepared file(s) to `$FESMDATA_PREPARED/<source folder>/` (in Julia:
  `prepared_dir("<source folder>")` from `shared/provenance.jl`).

A prepared file is a NetCDF file with:

- **a regular grid**, given by 1D coordinate variables, either
  - `lon`, `lat` in degrees (`units = "degrees_east"`, `"degrees_north"`): global or
    regional, with longitudes in -180:180 (preferred) or 0:360, in any order, and
    latitudes ascending or descending, evenly spaced or not (e.g. a Gaussian grid,
    with its cell edges from a CF `bounds` variable such as `lat_bnds` if there is
    one, else halfway between the latitudes); or
  - `x`, `y` in m or km, with the fields pointing to a grid-mapping variable
    (`grid_mapping` attribute) that holds a PROJ string in `proj_params` or `proj4`;
- **fields** on that grid, each with `units` and `long_name`, and missing values
  as `_FillValue` or NaN. A field may have more dimensions than the grid (e.g.
  `month`, `time`, `depth`), each with a 1D coordinate variable; they are kept as they
  are. Variables off the grid are copied as they are, with their dimensions: on these
  dimensions (e.g. `label(time)`) or on dimensions of their own (e.g. an annual time
  series next to fields every 10 years, a section of the overturning streamfunction).
  Integer fields (e.g. masks, classes) stay integer, with `flag_values` and
  `flag_meanings` if they are classes. Vectors are given by their eastward and
  northward components, marked by the standard names `eastward_<name>` and
  `northward_<name>` (e.g. `eastward_land_ice_surface_velocity`), never by their
  components along the axes of a projected source grid;
- optionally, **fields given by region**, one value per region of a Regions product
  (e.g. melt rates averaged over each drainage basin): a float variable on one
  dimension whose coordinate variable holds the region numbers, with `units`,
  `long_name` and the attribute `regions`, the Regions product (e.g.
  `bmelt_basin(basin)`, `regions = "BASINS-Zwally2012"`, `basin` = 1, ..., 27). On each
  grid, every cell gets the value of its region, the field named as the dimension
  (`basin`) in `<GRID>_<regions>.nc` (Regions must be made first); the cells outside the
  regions (e.g. the open ocean beyond the shelf break, where the basins end) get the
  nearest region (FesmUtils `extend_labels`), so the field covers the whole grid and is
  constant over each region. They have no `f_valid` and are not filled or smoothed. A
  prepared file needs at least one field on its grid;
- **global attributes** `title`, `references`, `license` and, where there is one,
  `doi` (copied to the remapped files).

Prepare the data at their own resolution: no smoothing or regridding, that is left to
the remapping. Keep names and units simple (e.g. `ghf` in mW m-2).

## 2. Remap a file

```bash
julia fesmdata.jl remap <file.nc> <Domain> | <GRID> | all ... [options]
```

- Targets are domains (e.g. `Antarctica`, all of its grids; `Global`, the global
  lon-lat grids), grids (e.g. `GRL-4KM`, `GLOBAL-0.5DEG`), or `all`. The names are
  listed under [Domains](https://fesmc.github.io/FesmData/domains.html).
- `--vars=a,b` remaps only these fields (default: all fields of the file).
- `--name=NAME` names the output `<GRID>_<NAME>.nc` (default: the file name). Use
  `<Dataset>-<Source>`, e.g. `GHF-Lucazeau2019`.
- `--method=con|bilinear` (default `con`) and `--smooth=auto|<km>` (default `auto`), see
  below.
- Existing files are kept unless `--overwrite`.

**Methods.** `con` (conservative) gives every cell the area-weighted mean of the
source over the cell: it keeps means and totals, and is right for any grid coarser
than the source. A source on the same projection as the grid, or a lon-lat source on
a lon-lat grid, is remapped exactly; otherwise each cell is sampled at points spaced
at most half the source spacing. `bilinear` interpolates the source at the cell
centres. Fields with more dimensions are remapped one 2D slice at a time. Integer
fields are remapped as classes, whatever the method: each cell gets the class that
covers most of it (from the conservatively remapped area fraction of each class), or
is missing where the source has no data. Vectors are remapped component by
component and then rotated to the axes of a projected grid (attribute
`vector_component`); on lon-lat grids they stay eastward and northward.

**Smoothing.** After remapping, the field can be smoothed with a Gaussian of standard
deviation `--smooth` (km; `0` for none). With `auto` (the default), a source coarser
than the grid that is remapped conservatively is smoothed with half the source
spacing (e.g. about 28 km for a 0.5° source), the least that removes the steps
between its cells; a source finer than the grid is not smoothed. Smoothing leaves out
missing cells and does not spread data into them. The global attribute
`remap_method` records what was done on each grid.

Each output file also has `f_valid`, the fraction of each cell covered by source data
(`f_valid_<field>` per field when the fields have different coverage, with the extra
dimensions of the field when its coverage differs between them, e.g. ocean data at
depth). Cells without
data are missing. Grids that the source does not cover at all are skipped, so a
regional source (e.g. velocities of Greenland) can be remapped onto `all`. The grid
files of each grid are written too if they are missing.

Run with threads for large grids: `julia -t 8 fesmdata.jl remap ...` (or set
`JULIA_NUM_THREADS`).

## Global grids

The `Global` domain has global lon-lat grids at 0.1°, 0.25°, 0.5°, 1°, 2° and 5°
(`GLOBAL-0.1DEG`, ...), with cell edges at -180° and -90°. Global sources are best
remapped onto these rather than released on their own grid, so that all global
products share the same grids. Other domains, projected or lon-lat, can be added in
`shared/domains.toml` (see
[Overview and code](https://fesmc.github.io/FesmData/developers.html#domains)).

## Not supported yet

- Files that are parts of one product along an extra dimension (e.g. a time series
  from yearly files, or a climatology): prepare them into one file first. (A product of
  a thematic dataset can combine several files in space only, see
  [Several files](https://fesmc.github.io/FesmData/adding.html#several-files).)
- Projected grids described only by CF grid-mapping parameters or WKT (add a PROJ
  string as `proj_params`).
