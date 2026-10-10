# Domains and grids

All v2 pipelines (Topo, Regions, ...) produce their datasets on the same model
domains and grids, defined in `domains.toml`, and share the code in this folder:

| File | Contents |
|---|---|
| `domains.toml` | The domains, their grids and output folders |
| `domains.jl` | `Domain(key)`: the base grid and all grids of a domain |
| `io.jl` | NetCDF output (`write_fields`, `write_grid_files`) with the provenance attributes |
| `provenance.jl` | Repository paths, machine environment, provenance attributes |
| `manifest.jl` | The original datasets of all pipelines (`../datamanifest.toml`) |
| `machines/<machine>.env` | Environment variables of each machine |

## Domains

A domain is a region on a map projection (polar stereographic, or transverse Mercator
such as UTM) with a **base grid**, its finest resolution. All other grids of the domain
are derived from the base grid: coarser grids by merging whole cells, and **crops**
(smaller regions inside the domain) by cutting it, at the same resolutions. All grids
of a domain are therefore nested: every coarse cell is made of whole base cells, and
the datasets on them are exact conservative means of the base grid.

| Domain | Base grid | Crops | Projection |
|---|---|---|---|
| ANT | ANT-1KM | | polar stereographic, south |
| GRL-PAL | GRL-PAL-500M | GRL | polar stereographic, north |
| NH | NH-2KM | LIS, EIS | polar stereographic, north |
| PYR | PYR-500M | | UTM 31N |
| SRG | SRG-250M | | UTM 18S |

Grids are named after their domain (or crop) and resolution: `ANT-8KM`, `GRL-500M`.
Each domain and crop has an output **folder** under `$ICE_DATA/v2`, which is also its
name in the released records (Antarctica, GreenlandPaleo, Greenland, North,
Laurentide, Eurasia, Pyrenees, SRG). Every grid has its own folder there, with all
datasets on that grid:

```
$ICE_DATA/v2/<folder>/<GRID>/
    grid_<GRID>.txt         grid description (cdo)
    <GRID>_grid.nc          x, y, lon, lat and area of the cells
    <GRID>_TOPO-<product>.nc, <GRID>_REGIONS.nc, ...
```

The grid files are written by Topo step 1 (`Topo/scripts/01_grids.jl`).

## Adding a domain, a crop or a resolution

A domain is a table in `domains.toml`:

```toml
[PYR]
folder = "Pyrenees"
proj = "+proj=tmerc +lat_0=0 +lon_0=3 +k=0.9996 +x_0=500000 +y_0=0 +a=6378137 +rf=298.257223563 +units=km"
xlim = [80, 560]                       # first and last cell centres of the base grid (km)
ylim = [4620, 4860]
resolutions = [0.5, 1, 2, 4, 8, 16, 32]  # km; the first is the base grid
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
- `folder` must be unique among all domains and crops.

A crop is a table below its domain, with its own folder and extent (on the cell
centres of the base grid):

```toml
[NH.crops.LIS]
folder = "Laurentide"
xlim = [-4900, -36]
ylim = [-5400, 1576]
```

A new resolution is a new entry in `resolutions`. Then, for each dataset:

- **Topo**: add the products of the domain to `Topo/products.toml` (see the Topo
  README), and run its steps for the domain, from step 1 (the grid files).
- **Regions**: add the topography product for the zones of the domain to
  `Regions/regions.toml` (`[zone] products`), and basin sets if any to
  `Regions/basins.toml` (see the Regions README), and run its steps.

The domain is released as a new record with the next release of each dataset.

## Machines

Each machine has an environment file, sourced from the FesmData root before running
anything:

```bash
source shared/machines/levante.env
```

It sets `DATAMANIFEST_DATASETS_DIR` (the original datasets), `ICE_DATA` (the output),
`FESMDATA_WORK` (intermediate files), the Julia version, and the tokens for releases.
A new machine is a new file with the same variables.

## Adding a dataset

A new dataset (e.g. geothermal heat flux) is a new pipeline folder, built like Topo and
Regions, so that it can be released in the same way:

1. **Folder** `<Dataset>/` with a `README.md` (what it is, its sources, the steps to
   produce it), `Project.toml`, `common.jl`, `scripts/` (numbered steps) and `jobs/`.
2. **Original datasets** in `../datamanifest.toml`, with their DOI (used in the
   records), read through `manifest()` (`manifest.jl`).
3. **`common.jl`** includes `../shared/io.jl` and `../shared/domains.jl`, and sets
   `const DATASET = "<name>"` (lower case), the name of its provenance attributes and
   release tags (`<name>-vX.Y.Z`).
4. **Output** with `write_fields(path, grid, fields; dataset=DATASET, ...)`, into
   `$ICE_DATA/v2/<folder>/<GRID>/<GRID>_<NAME>[-<product>].nc` on every grid of a
   domain (`outdir(og)` for each `og in dom.grids`). Add a `sources` attribute with the
   `datamanifest.toml` keys of the original datasets, so that the records cite them.
5. **`files.jl`** with the output file names and a function
   `<name>_release_files(dom, og)` giving the files of a release on a grid. It must
   need only `../shared/domains.jl` (no other packages), since Publish reads it.
6. **Release**: add the dataset to `Publish/datasets.toml` (tag, title, README,
   keywords, description) and its function to `RELEASE_FILES` in `Publish/release.jl`
   (and include its `files.jl` there). It can then be released with
   `julia fesmdata.jl release <Dataset>` (see `Publish/README.md`), and appears on the
   website.
7. **Documentation**: add its README to the website (`docs/datasets/`, see
   `docs/_quarto.yml`).
