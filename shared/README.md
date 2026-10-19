# Overview and code

How the FesmData datasets are made, and the code shared by all of them. The domains and
grids as users see them are described on the
[Domains](https://fesmc.github.io/FesmData/domains.html) page.

## Method

Every dataset is made from the original sources, with each step in this repository:

1. **Prepare**: the folder of a source (e.g. `Lucazeau2019_ghf/`) has a `prepare.jl`
   that gets the original files (listed in `../datamanifest.toml`) and writes them as a
   NetCDF file on their own grid, in a simple standard form, to
   `$FESMDATA_PREPARED/<source>/`.
2. **Remap** or **pipeline**: a thematic dataset (e.g. `GHF/`) groups the products of
   several sources in its `remap.toml`, and `julia fesmdata.jl remap GHF` puts the
   prepared files onto the grids of the domains, as
   `$FESMDATA/<Domain>/<GRID>/<GRID>_<Dataset>-<Product>.nc`. Remapping is
   conservative (with smoothing where the grid is finer than the source), and handles
   extra dimensions (month, time, depth, ...), integer fields (dominant class) and
   vectors (rotated to the grid axes); see
   [Gridded data](https://fesmc.github.io/FesmData/remap.html). Topo and Regions, which
   merge high-resolution sources on the base grid of each domain, have pipelines of
   their own (`Topo/`, `Regions/`). A records dataset (e.g. `IceCores/`) copies the
   prepared files as they are (`records.toml`, `julia fesmdata.jl record IceCores`).
3. **Release**: the products are uploaded to Helmholtz Codebase and listed in
   `../registry/` (see [Releasing](https://fesmc.github.io/FesmData/releasing.html)).

[Adding a dataset](https://fesmc.github.io/FesmData/adding.html) describes the three
kinds of datasets and how to add one.

## Code

| Folder or file | Contents |
|---|---|
| `fesmdata.jl` | The command line of FesmData (`julia fesmdata.jl help`) |
| `<Source>/` | A source: `README.md` and `prepare.jl` (e.g. `Lucazeau2019_ghf/`) |
| `<Dataset>/` | A dataset: `README.md` and `remap.toml` (thematic) or `records.toml` (records) |
| `Topo/`, `Regions/` | The pipelines of Topo and Regions |
| `Remap/` | Remapping of prepared files and thematic datasets (`fesmdata.jl remap`) |
| `Records/` | Records datasets (`fesmdata.jl record`) |
| `Publish/` | Releases, downloads and the generated pages of the website (`fesmdata.jl list`, `fetch`, `release`, `docs`, ...) |
| `Figures/` | Figures of the products for the website (`fesmdata.jl figures`) |
| `registry/` | The released products, one file per dataset and domain |
| `docs/` | The website (Quarto) |
| `datamanifest.toml` | The original datasets of all sources, with their DOIs |
| `shared/domains.toml` | The domains, their grids and output folders |
| `shared/domains.jl` | `Domain(key)`: the base grid and all grids of a domain |
| `shared/io.jl` | NetCDF output (`write_fields`, `write_grid_files`) with the provenance attributes |
| `shared/precision.jl` | Default precision of the float fields by kind, and their bit rounding (see [Precision and file sizes](https://fesmc.github.io/FesmData/precision.html)) |
| `shared/provenance.jl` | Repository paths, storage folders, provenance attributes |
| `shared/manifest.jl` | The original datasets (`../datamanifest.toml`) |
| `shared/records_prepare.jl` | For the prepare.jl of records: readers of NOAA and PANGAEA tables, `write_series` (time series at sites), AICC2023 ages |
| `shared/ringgrid.jl` | Gridding of equal-area points |
| `shared/machines/` | The environment of each machine (see [Machines and storage](https://fesmc.github.io/FesmData/machines.html)) |
| `maps/`, `grid/` | Grid descriptions (cdo) of the v1 grids, and the tools that made them |

## Provenance

Every NetCDF file written by a v2 pipeline has the global attributes `source` (this
repository), `fesmdata_version` (`git describe` against the release tags of the dataset,
e.g. `topo-v2.0.0`, with `-dirty` for uncommitted changes), `fesmdata_commit` and
`history` (time, script and arguments) (`provenance_attrib` in `provenance.jl`). The
products of Topo also have `sources`, the keys of their original datasets in
`../datamanifest.toml`, and remapped products the `title`, `references`, `license` and
`doi` of their source.

## Domains

The domains are defined in `domains.toml` (see
[Domains](https://fesmc.github.io/FesmData/domains.html) for what they are). A domain is
a table:

```toml
[PYR]
folder = "Pyrenees"
proj = "+proj=tmerc +lat_0=0 +lon_0=3 +k=0.9996 +x_0=500000 +y_0=0 +a=6378137 +rf=298.257223563 +units=km"
xlim = [107.875, 487.625]     # first and last cell centres of the base grid (km)
ylim = [4639.875, 4811.625]
resolutions = [0.25, 0.5, 2]  # km; the first is the base grid
active = true                 # the default; false to leave it out of the releases
```

- `proj` is a PROJ string with `+units=km` (false easting and northing in metres, as
  in PROJ).
- Every resolution must be a whole multiple of the base resolution, and the extent a
  whole number of cells of each resolution (e.g. a multiple of the coarsest
  resolution), so that the grids are nested. Coarse grids extend half a coarse cell
  beyond the base grid, where their cells are means over the part the base grid
  covers.
- Where a v1 grid exists in `../maps`, take its extent, so that the v1 grids are
  reproduced (Topo step 1 reports which grids match).
- `folder` must be unique among all domains, crops and nests.
- `elevation_precision` (optional) is the tolerance (m) of the elevations and
  thicknesses on the grids of the domain, if not the default 0.01 m.

A lon-lat domain has `type = "lonlat"` and its resolutions in degrees, each dividing
180°; it needs no projection or extent. `gaussian` adds Gaussian grids, by spectral
truncation and number of latitudes, made only for the products that name them:

```toml
[GLOBAL]
folder = "Global"
type = "lonlat"
resolutions = [0.1, 0.25, 0.5, 1, 2, 5]
gaussian = { T170 = 256 }
```

A crop is a table below its domain, with its own folder and extent (on the cell
centres of the base grid), and optionally only some of the resolutions of its domain.
Its grids must lie on those of its domain at each resolution, i.e. its first cell
centres must be cell centres of the domain grid at its coarsest resolution (checked
when the domain is read), so that the products of the domain can be cut to them:

```toml
[NH.crops.LIS]
folder = "Laurentide"
xlim = [-4900, -36]
ylim = [-5400, 1576]

[PAT.crops.NPI]
folder = "NorthPatagonianIcefield"
xlim = [559.837171469987, 677.337171469987]
ylim = [4703.352314639904, 4872.352314639904]
resolutions = [0.25]
```

A nest is a table below its domain, with its own folder, extent and resolutions, on the
projection of its domain (and active if its domain is, unless set). Its first and last
cell centres at the resolutions it shares with its domain must be cell centres of the
domain grids at these resolutions (checked when the domain is read); in the pipelines
it is a domain like any other, named by its key (here SRG):

```toml
[PAT.nests.SRG]
folder = "SRG"
xlim = [583.087171469987, 634.837171469987]
ylim = [4811.102314639904, 4840.852314639904]
resolutions = [0.05, 0.1, 0.25]
```

An inactive domain (`active = false`) is left out of the releases, the website figures
and the products made for all domains. Its grids and products are made when it is named
(e.g. `Topo/jobs/submit_domain.sh ALP`); set it active to release it.

The grid files of each grid (`grid_<GRID>.txt`, `<GRID>_grid.nc`) are written by Topo
step 1 (`Topo/scripts/01_grids.jl`), or by `fesmdata.jl remap` if they are missing (it
downloads those released in Grids instead). They are released in the dataset
[Grids](https://fesmc.github.io/FesmData/domains.html#grid-files), once per grid.

## Adding a domain, a crop, a nest or a resolution

Add the domain, crop or nest to `domains.toml` (above), or a new entry to
`resolutions`. Then, for each dataset:

- **Topo**: add the products of the domain to `Topo/products.toml` (see
  [Topo](https://fesmc.github.io/FesmData/datasets/topo.html#making-the-dataset)), and
  run its steps for the domain, from step 1 (the grid files).
- **Regions**: add the topography product for the zones of the domain to
  `Regions/regions.toml` (`[zone] products`), and basin sets if any to
  `Regions/basins.toml` (see
  [Regions](https://fesmc.github.io/FesmData/datasets/regions.html#making-the-dataset)),
  and run its steps.
- **Thematic datasets** (e.g. GHF): add the domain to the `grids` of its products in
  `<Dataset>/remap.toml`, and run `julia fesmdata.jl remap <Dataset>`. A nest or crop
  needs none: `fetch` crops those of its domain.

The domain is released with the next release of each dataset.
