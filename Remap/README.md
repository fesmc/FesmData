# Bring your own data

Any gridded dataset (geothermal heat flow, basal melt, surface velocity, ...) can be
put on the FesmData grids in two steps:

1. **Prepare**: write the data as a NetCDF file on its own (native) grid, in a simple
   standard form. This is specific to each source and lives in the source's folder.
2. **Remap**: one command puts that file onto any domains and grids, in the usual
   layout `$ICE_DATA/v2/<Domain>/<GRID>/`, including global lon-lat grids.

```bash
julia --project=Lucazeau2019_ghf Lucazeau2019_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Lucazeau2019_ghf/Lucazeau2019_GHF.nc Antarctica Global --name=GHF-Lucazeau2019
```

This writes, e.g., `$ICE_DATA/v2/Antarctica/ANT-8KM/ANT-8KM_GHF-Lucazeau2019.nc` and
`$ICE_DATA/v2/Global/GLOBAL-1DEG/GLOBAL-1DEG_GHF-Lucazeau2019.nc`, on every grid of
Antarctica and of the global lon-lat grids.

To publish the result, make it part of a **thematic dataset** (step 3), e.g. GHF:
then `julia fesmdata.jl remap GHF` makes all of it, and it is released like Topo.

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
the remapping. Keep names and units simple (e.g. `ghf` in mW m-2).

## 2. Remap a file

```bash
julia fesmdata.jl remap <file.nc> <Domain> | <GRID> | all ... [options]
```

- Targets are domains (e.g. `Antarctica`, all of its grids; `Global`, the global
  lon-lat grids), grids (e.g. `GRL-4KM`, `GLOBAL-0.5DEG`), or `all`. The names are
  listed under Domains and grids (`shared/README.md`).
- `--vars=a,b` remaps only these fields (default: all 2D fields of the file).
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
centres.

**Smoothing.** After remapping, the field can be smoothed with a Gaussian of standard
deviation `--smooth` (km; `0` for none). With `auto` (the default), a source coarser
than the grid that is remapped conservatively is smoothed with half the source
spacing (e.g. about 28 km for a 0.5° source), the least that removes the steps
between its cells; a source finer than the grid is not smoothed. Smoothing leaves out
missing cells and does not spread data into them. The global attribute
`remap_method` records what was done on each grid.

Each output file also has `f_valid`, the fraction of each cell covered by source data
(`f_valid_<field>` per field when the fields have different coverage). Cells without
data are missing. Grids that the source does not cover at all are skipped, so a
regional source (e.g. velocities of Greenland) can be remapped onto `all`. The grid
files of each grid are written too if they are missing.

Run with threads for large grids: `julia -t 8 fesmdata.jl remap ...` (or set
`JULIA_NUM_THREADS`).

## 3. Make a thematic dataset

A thematic dataset (e.g. GHF, geothermal heat flow) gathers the products of several
sources on one theme, and is released like Topo, with its own versions (tags
`ghf-vX.Y.Z`). It is defined by `<Dataset>/remap.toml`, one table per product:

```toml
[products.Lucazeau2019]                      # → <GRID>_GHF-Lucazeau2019.nc
source = "Lucazeau2019_ghf"                  # source folder, with prepare.jl
file = "Lucazeau2019_GHF.nc"                 # prepared file of the source
variables = ["ghf", "ghf_sd"]                # optional, default all
domains = ["Antarctica", "Greenland", "Global"]
# method = "con"                             # optional, default "con"
# smooth = "auto"                            # optional, default "auto"
```

Domains are listed explicitly, so that the files of a release are fixed; each source
must cover every grid of its domains. Then:

1. Add the dataset to `Publish/datasets.toml` (its release tag, title, README,
   keywords, description), and write `<Dataset>/README.md` (the products and their
   sources), which becomes its page on the website (`docs/datasets/`).
2. Make it, after preparing the sources not prepared yet:
   ```bash
   julia -t 8 fesmdata.jl remap GHF                          # all products, all grids
   julia fesmdata.jl remap GHF Lucazeau2019 GLOBAL-0.5DEG    # one product, one grid
   ```
3. Release it (see Releasing): tag `ghf-vX.Y.Z`, make it at the tag, and
   `julia fesmdata.jl release GHF`.

## Global grids

The `Global` domain has global lon-lat grids at 0.1°, 0.25°, 0.5°, 1°, 2° and 5°
(`GLOBAL-0.1DEG`, ...), with cell edges at -180° and -90°. Global sources are best
remapped onto these rather than released on their own grid, so that all global
products share the same grids. Other domains, projected or lon-lat, can be added in
`shared/domains.toml` (see Domains and grids).

## Not supported yet

- Fields with more dimensions (e.g. time) and datasets split over several files.
- Integer or flag fields (masks); these need fractions or the dominant class rather
  than a mean.
- Projected grids described only by CF grid-mapping parameters or WKT (add a PROJ
  string as `proj_params`).
