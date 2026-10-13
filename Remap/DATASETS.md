# Adding a dataset

A dataset is one of three kinds, by how it is made from its sources:

- a **thematic dataset made by remapping** (e.g. GHF, Velocity, SMB): fields from
  published maps, each source prepared once and remapped onto the grids of the domains.
  Most new datasets are of this kind. It is defined by `<Dataset>/remap.toml`.
- a **records dataset** (e.g. IceCores, RSL): non-gridded data (time series, sites,
  profiles), whose prepared files are the products. It is defined by
  `<Dataset>/records.toml`.
- a **dataset with its own pipeline** (Topo, Regions): processing beyond remapping
  (merging sources on the base grids, deriving fields), in a pipeline folder of its own.

All start from prepared sources, and end with the same steps to publish them (see
[Publishing a new dataset](#publishing-a-new-dataset)).

## Sources

Each source has a folder named after it (`<Author><Year>_<topic>`, e.g.
`Lucazeau2019_ghf/`) with a `README.md` (the data, where they come from, how to cite
them, and their licence: check that it allows redistributing derived products before
releasing them) and a `prepare.jl` (with its own `Project.toml`), which gets the original
files through `../datamanifest.toml` (with their DOI) and writes the prepared file(s) to
`$FESMDATA_PREPARED/<source>/`. The form of a prepared file is described under
[Gridded data](https://fesmc.github.io/FesmData/remap.html#prepare-a-source) and
[Records format](https://fesmc.github.io/FesmData/records.html#file-form). The commands
that make a dataset prepare its missing sources first.

## Thematic datasets

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

### Grids

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
[Nests and crops](https://fesmc.github.io/FesmData/download.html#nests-and-crops)), and
it is stored once.

### Gap filling

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

### Several files

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

### Products not released

`release = false` makes a product locally but leaves it out of the releases, e.g. data
obtained by personal communication whose redistribution the authors have not agreed to
yet (say so in the README of the dataset).

### Precision

`precision` sets the precision of some float fields instead of the default of their kind
(see [Precision and file sizes](https://fesmc.github.io/FesmData/precision.html);
`../shared/precision.jl`), for fields that need more (or allow less): by field, an absolute
tolerance in the units of the field (a number), a relative one (`"x%"`) or `"lossless"`,
e.g. `precision = { ghf = 0.1, smb = "1%", lat = "lossless" }`. Each float field records
its precision in the attributes `precision` and `bitround_keepbits`.

### Ensembles

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
must cover all its grids (one of its files, for a product of several files). The
methods of remapping and smoothing (`method`, `smooth`) are described under
[Gridded data](https://fesmc.github.io/FesmData/remap.html#remap-a-file).

### Making it

```bash
julia -t 8 fesmdata.jl remap GHF                          # all products, all grids
julia fesmdata.jl remap GHF Lucazeau2019 GLOBAL-0.5DEG    # one product, one grid
sbatch --job-name=remap-GHF Remap/jobs/remap_dataset.sbatch GHF   # Levante compute node
sbatch --job-name=remap-Sediment -p shared -c 64 --mem=58G -t 02:00:00 \
    Remap/jobs/remap_dataset.sbatch Sediment                  # small dataset, shared partition
```

The sources not prepared yet are prepared first. Existing files are kept unless
`--overwrite`.

A new source of an existing thematic dataset is a new source folder and a new table
`[products.<Name>]` in its `remap.toml`; add it to the table of products of the README
of the dataset, run `julia fesmdata.jl remap <Dataset> <Name>`, and release a new
version of the dataset.

## Records datasets

A records dataset is defined by `<Dataset>/records.toml`, one table per product:

```toml
[products.Kindler2014]            # → IceCores-Kindler2014.nc
source = "Kindler2014"            # source folder
file = "Kindler2014_NGRIP.nc"     # prepared file
# figure = { variable = "acc" }   # optional: the variable of its figure on the website
```

The prepared files follow the [Records format](https://fesmc.github.io/FesmData/records.html),
with the provenance attributes (`provenance_attrib(<tag>)` of
`../shared/provenance.jl`). Then

```bash
julia fesmdata.jl record IceCores                 # all products
julia fesmdata.jl record IceCores Kindler2014     # one product
```

prepares the missing sources, checks each prepared file against the form and copies it
to `$FESMDATA_PRODUCTS/Records/<Dataset>/<Dataset>-<Product>.nc` (`--overwrite` to
replace). A records dataset is released on the domain `Records` (one package per
dataset, `Records_<Dataset>`, and `registry/Records/<Dataset>.toml`); `fesmdata.jl
list`, `fetch` and `release` work as for the gridded datasets.

## Datasets with their own pipeline

A dataset that needs its own processing (merging sources, deriving fields) is a new
pipeline folder, built like Topo and Regions, so that it can be released in the same
way:

1. **Folder** `<Dataset>/` with a `README.md`, `Project.toml`, `common.jl`, `scripts/`
   (numbered steps) and `jobs/`.
2. **Original datasets** in `../datamanifest.toml`, with their DOI, read through
   `manifest()` (`../shared/manifest.jl`).
3. **`common.jl`** includes `../shared/io.jl` and `../shared/domains.jl`, and sets
   `const DATASET = "<name>"` (lower case), the name of its provenance attributes and
   release tags (`<name>-vX.Y.Z`).
4. **Output** with `write_fields(path, grid, fields; dataset=DATASET, ...)`, into
   `$FESMDATA_PRODUCTS/<folder>/<GRID>/<GRID>_<NAME>[-<product>].nc` on every grid of a
   domain (`outdir(og)` for each `og in dom.grids`). Add a `sources` attribute with the
   `datamanifest.toml` keys of the original datasets.
5. **`files.jl`** with the output file names and a function
   `<name>_release_files(dom, og)` giving the files of a release on a grid. It must
   need only `../shared/domains.jl` (no other packages), since Publish reads it; add
   its functions to `dataset_pipeline` in `../Publish/release.jl` (and include its
   `files.jl` there).

## Publishing a new dataset

For every kind of dataset:

1. **Release settings**: add the dataset to `../Publish/datasets.toml` (its release tag,
   title, README, keywords and description), and to a topic of the website (`[_site]
   topics` there).
2. **README**: write `<Dataset>/README.md`, which becomes its page on the website, in
   the form of the other datasets:
   1. `# <Dataset>: <title>`, and 2-4 sentences: what it is, its kind, links to the
      Products and Domains pages;
   2. `## Products`: a table of the products, with their source (and DOI), fields
      (units) and domains (for records: sites, variables, time);
   3. notes on the fields and the method, in subsections where needed;
   4. `## Precision`: the precision of its fields (see
      [Precision and file sizes](https://fesmc.github.io/FesmData/precision.html));
   5. `## Licences` (or `## Sources and licences`): the licence of each source;
   6. `## Making the dataset`, last: the commands that make it, and how to add a source.
3. **Figures**: `julia fesmdata.jl figures <Dataset>` (see
   [Website and figures](https://fesmc.github.io/FesmData/website.html), also for the
   options of `figure`).
4. **Page**: add `docs/datasets/<name>.qmd`, which includes the README, the downloads
   and the figures (as `docs/datasets/ghf.qmd`), and add it to the menu in
   `docs/_quarto.yml`.
5. **Release** (see [Releasing](https://fesmc.github.io/FesmData/releasing.html)): tag
   `<tag>-vX.Y.Z`, `julia fesmdata.jl stamp <Dataset>` at the tag, and
   `julia fesmdata.jl release <Dataset>`. The products page and the downloads of the
   dataset on the website are made from the registry.
