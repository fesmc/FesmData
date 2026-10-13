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

Non-gridded data (time series, sites, profiles) are not remapped: see Records.

## 1. Prepare a source

Make a folder for the source, named after it (e.g. `Lucazeau2019_ghf/`), with:

- `README.md`: what the data are, where they come from, how to cite them, and their
  licence (check that it allows redistributing derived products before releasing
  them);
- `prepare.jl` (with its own `Project.toml`): get the original files and write the
  prepared file(s) to `$FESMDATA_WORK/prepared/<source folder>/` (in Julia:
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
  are, with the variables on these dimensions only (e.g. `label(time)`). Integer fields (e.g. masks, classes) stay integer, with `flag_values` and
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
  listed under Domains and grids (`shared/README.md`).
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

## 3. Make a thematic dataset

A thematic dataset (e.g. GHF, geothermal heat flow) gathers the products of several
sources on one theme, and is released like Topo, with its own versions (tags
`ghf-vX.Y.Z`). It is defined by `<Dataset>/remap.toml`, one table per product:

```toml
[products.Lucazeau2019]                      # → <GRID>_GHF-Lucazeau2019.nc
source = "Lucazeau2019_ghf"                  # source folder, with prepare.jl
file = "Lucazeau2019_GHF.nc"                 # prepared file of the source (or a list, see below)
variables = ["ghf", "ghf_sd"]                # optional, default all
grids = { Antarctica = 4, Greenland = 4, Global = 4 }   # by domain, see below
# method = "con"                             # optional, default "con"
# smooth = "auto"                            # optional, default "auto"
# release = false                            # optional: made, but not released
# figure = { variables = ["ghf"] }            # optional: its figure on the website
# fill = { variables = ["ux_srf", "uy_srf"], mask = "TOPO-BedMachine-v4" }   # optional: gaps over the ice (or "all") filled, see below
# precision = { ghf = 0.1 }                  # optional: precision of fields instead of the default, see below
```

`grids` lists the domains (output folders) of the product, each with the grids it is
made on; it is not made on other domains. For each domain:

- a number: the minimum grid spacing in km, i.e. all standard grids of the domain not
  finer than this (on lon-lat grids, 111 km per degree of latitude); 0 means all. Finer
  grids are left out where a coarse source adds no information and its files would only
  be large; models that need finer grids can remap online. As a rule, no grid is finer
  than about a quarter of the source spacing: 16 km and 0.5° (`Global = 50`) for
  sources at 1-2°, 8 km and 0.25° (`Global = 25`) for sources at 0.25-0.5°, 4 km for
  most others.
- a list of grid names: exactly these grids, e.g. `Global = ["GLOBAL-T170"]`. This also
  gives the grids made only on request, which no number selects: the Gaussian grids of
  the Global domain (`gaussian` in `../shared/domains.toml`, e.g. GLOBAL-T170, the T170
  grid of 512 x 256 used by VILMA).

For example, `grids = { Antarctica = 16, Global = ["GLOBAL-T170"] }` makes ANT-16KM,
ANT-32KM and GLOBAL-T170.

Crops (Greenland, Laurentide, Eurasia, ...) and nests are listed only for products their
parent domain does not have (e.g. a Greenland-only source on Greenland): their grids lie
on those of the parent, so `fetch` cuts a product of the parent to them on demand (see
`../Publish/README.md`), and it is stored once.

`fill` fills the gaps of a source over the ice on each grid, after remapping (and the
rotation of vectors): the cells of the fields `variables` with ice (`H_ice > 0`) in the
Topo product `mask` on the same grid (`<GRID>_TOPO-BedMachine-v4.nc` in the same folder)
but no source data (`f_valid = 0`) get the harmonic (Laplace) interpolation of the cells
around them (`laplace_fill` of FesmUtils). With `mask = "all"`, all the cells without
source data are filled, e.g. outside the domain of a regional climate model, for fields
used as model forcing over the whole grid. Gaps not connected to any data stay missing.
Both components of a vector must be filled; the speed of a filled vector (the field with
the standard name `<x>_speed`, for `eastward_<x>_velocity`) is the magnitude of the
filled components there. Other fields (e.g. errors) stay missing in the gaps. The file
has `mask_fill` (1: filled, 0: not; `mask_fill_<field>` when the fields differ) and the
global attribute `gap_fill`. The Topo product must be made first (thematic datasets
depend on Topo, and some on Regions).

`fill` can also be a list of tables, each with its `method` (each field in one of them):
`"harmonic"` (the default, as above), `"elevation_regression"`, for fields that depend
on the surface elevation (e.g. the surface mass balance or temperature of a regional
climate model, outside its ice mask or domain), or `"elevation"`, for the surface
elevation of the source itself (e.g. the orography of the regional climate model):

```toml
fill = [{ variables = ["pr", "sf"], mask = "all" },
        { method = "elevation_regression", variables = ["smb", "t2m", "T_srf"], mask = "all",
          cap = { smb = -91.7 } },       # optional: elevation, radius = 150.0, min_points = 20
        { method = "elevation", variables = ["z_srf"], mask = "all", gaps_of = "smb" }]   # optional: elevation, gaps_of
```

Each gap gets the linear regression of the field on the surface elevation, fitted over
the cells with source data (`f_valid > 0`) within `radius` km (a disk; grown by
`radius / 2` until it holds at least `min_points` of them), at the elevation of the cell
clamped to the range of the elevations of these cells (no extrapolation beyond the
lowest and highest of them). The elevation, for the cells with data as for the gaps, is
`max(z_srf, 0)` of the Topo product `elevation` on the same grid (default
`TOPO-BedMachine-v4`): the surface elevation, never below sea level. Where
the elevations of these cells hardly differ (variance below 1 m2), the gap gets their
mean. Fields with extra dimensions are filled slice by slice (e.g. each month). `cap`
gives upper bounds of the filled values, by field, in its units: of each value, or for a
monthly field (extra dimension `month` of 12 only) of the annual mean, the months
weighted by their mean length (February 28.25 days, as the `-annual-mean` products up to
the leap days of their period), all months of a cell shifted down by the same amount, so
that the seasonal cycle is kept. The log gives, for each field, the cells filled, the cell-slices whose radius was
grown and the median slope. Vectors are filled by harmonic interpolation only.

`"elevation"` fills the gaps with the elevation of the regression itself, `max(z_srf,
0)` of the Topo product `elevation` (default `TOPO-BedMachine-v4`), not clamped (the
clamp applies only within the regression). With `gaps_of`, it fills the cells (of
`mask`) where that field has no source data, in any of its slices (e.g. any month),
instead of the gaps of the variables themselves, and so also replaces source data there
(marked by `mask_fill`). Filling the orography of the source where the surface mass
balance is filled keeps it the reference elevation of the filled values, e.g. for an
elevation correction of the surface mass balance in a model, also where the source has
an orography of its own (e.g. 0 over its ocean).

`file` can be a list of prepared files of the source, each on its own grid, combined
into one product. The files are meant to cover separate areas, e.g. the grounded and the
floating ice of Antarctica on grids of their own (`file = ["Smith2020_ANT.nc",
"Smith2020_ANT_floating.nc"]` in `IceChange/remap.toml`); they are not suited to
alternative sources of the same quantity over the same area. Each file is remapped onto
each grid as above; a field in one file only is taken as it is, and a field in several
files (with the same units and extra dimensions) is the sum of their contributions, the
value of each times the fraction of the cell it covers, divided by the sum of these
fractions, with `f_valid` that sum. Where their remapped coverage overlaps (e.g. source
grids offset from each other at a boundary) and the fractions add up to more than 1,
`f_valid` is 1 and the value is the sum of the contributions, so that the total of each
file is kept (for integer fields, the class of the file covering most of the cell).
`variables` are taken from the files that have them, and `fill` applies to the combined
fields. The global attributes of the files are joined (their distinct values), and
`remapped_from` lists the files.

`release = false` makes a product locally but leaves it out of the releases, e.g. data
obtained by personal communication whose redistribution the authors have not agreed to
yet (say so in the README of the dataset).

`precision` sets the precision of some float fields instead of the default of their kind
(see [Data volume and precision](https://fesmc.github.io/FesmData/data_volume.html);
`shared/precision.jl`), for fields that need more (or allow less): by field, an absolute
tolerance in the units of the field (a number), a relative one (`"x%"`) or `"lossless"`,
e.g. `precision = { ghf = 0.1, smb = "1%", lat = "lossless" }`. Each float field records
its precision in the attributes `precision` and `bitround_keepbits`.

An **ensemble product** is the mean or the standard deviation of other products of the
dataset, its members, e.g. the models of a model intercomparison:

```toml
[products.PMIP3-lgm-mean]                    # → <GRID>_Paleoclimate-PMIP3-lgm-mean.nc
ensemble = ["PMIP3-CCSM4-lgm", "PMIP3-CNRM-CM5-lgm", ...]   # member products of the dataset
stat = "mean"                                # or "stdev"
grids = { Antarctica = 8, Global = 8 }       # members not made on some of these: intermediate there
# release = false, figure = { ... }, precision = { ... }   # optional, as above
```

It has no `source`, `file`, `variables`, `method`, `smooth` or `fill`: it is made on each
grid from the files of its members on that grid (those missing are remapped first),
after the other products. On a grid that is not one of a member's own `grids`, the
member is remapped as an intermediate file (`$FESMDATA_WORK/remap/members/`, full
precision, not released), so that the statistics can be released on grids where the
members are not, e.g. the 2 km grids of the mountain-glacier domains. Each of its fields is a field of any member (not `f_valid`,
`mask_fill` or integer fields), with the same name, units and extra dimensions, and
`, ensemble mean` or `, ensemble standard deviation` appended to its long name: in each
cell, the mean or the standard deviation (population, divided by n, as `cdo ensstd`) of
the members with a value there. `n_<field>` (a byte field) is the number of these
members, e.g. 0 for a sea surface temperature over land. The global attributes of the
members are joined, and `ensemble_members` lists them.

Domains are listed explicitly, so that the files of a release are fixed; each source
must cover all its grids (one of its files, for a product of several files). Then:

1. Add the dataset to `Publish/datasets.toml` (its release tag, title, README,
   keywords, description), and write `<Dataset>/README.md` (the products and their
   sources), which becomes its page on the website (`docs/datasets/`).
2. Make it, after preparing the sources not prepared yet:
   ```bash
   julia -t 8 fesmdata.jl remap GHF                          # all products, all grids
   julia fesmdata.jl remap GHF Lucazeau2019 GLOBAL-0.5DEG    # one product, one grid
   sbatch --job-name=remap-GHF Remap/jobs/remap_dataset.sbatch GHF   # Levante compute node
   sbatch --job-name=remap-Sediment -p shared -c 64 --mem=58G -t 02:00:00 \
       Remap/jobs/remap_dataset.sbatch Sediment                  # small dataset, shared partition
   ```
3. Make its figures for the website, `julia fesmdata.jl figures GHF` (see
   `../Figures/README.md`, also for the options of `figure`), and add its page
   `docs/datasets/ghf.qmd`, which includes the README and the figures.
4. Release it (see Releasing): tag `ghf-vX.Y.Z`, `julia fesmdata.jl stamp GHF` at the
   tag, and `julia fesmdata.jl release GHF`.

## Global grids

The `Global` domain has global lon-lat grids at 0.1°, 0.25°, 0.5°, 1°, 2° and 5°
(`GLOBAL-0.1DEG`, ...), with cell edges at -180° and -90°. Global sources are best
remapped onto these rather than released on their own grid, so that all global
products share the same grids. Other domains, projected or lon-lat, can be added in
`shared/domains.toml` (see Domains and grids).

## Not supported yet

- Files that are parts of one product along an extra dimension (e.g. a time series
  from yearly files, or a climatology): prepare them into one file first. (Several
  files of one product are combined in space only, see `file` above.)
- Projected grids described only by CF grid-mapping parameters or WKT (add a PROJ
  string as `proj_params`).
