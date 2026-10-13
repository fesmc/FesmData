# Domains and grids

All v2 pipelines (Topo, Regions, ...) produce their datasets on the same model
domains and grids, defined in `domains.toml`, and share the code in this folder:

| File | Contents |
|---|---|
| `domains.toml` | The domains, their grids and output folders |
| `domains.jl` | `Domain(key)`: the base grid and all grids of a domain |
| `io.jl` | NetCDF output (`write_fields`, `write_grid_files`) with the provenance attributes |
| `precision.jl` | Default precision of the float fields by kind, and their bit rounding (see Data volume and precision on the website) |
| `provenance.jl` | Repository paths, machine environment, provenance attributes |
| `manifest.jl` | The original datasets of all pipelines (`../datamanifest.toml`) |
| `machines/<machine>.env` | Environment variables of each machine (levante, macbook; albedo for downloads only) |

## Domains

A domain is a region on a map projection (polar stereographic, transverse Mercator
such as UTM, or Albers equal-area) with a **base grid**, its finest resolution. All
other grids of the domain are derived from the base grid: coarser grids by merging whole
cells, and **crops** (smaller regions inside the domain) by cutting it, at the same
resolutions or some of them. All grids of a domain are therefore nested: every coarse
cell is made of whole base cells, and the datasets on them are exact conservative means
of the base grid.

A **nest** is a smaller domain inside a domain, on the same projection, with a finer
base grid of its own (made from the sources, like any domain). At the resolutions it
shares with its parent, its grids lie on those of the parent: same cell centres, so
that its coarsest grid is a part of the parent grid at that resolution.

| Domain | Base grid | Other grids | Crops | Nests | Projection | Active |
|---|---|---|---|---|---|---|
| ANT | ANT-1KM | 2-32 km | ASE (1 km) | THW, PIG; FRIS, ROSS, AMY, WSB inactive (500 m, 1 km) | polar stereographic, south | yes |
| GRL-PAL | GRL-PAL-500M | 1-32 km | GRL | JAK, NEGIS; PET, HEL inactive (250 m, 500 m, 1 km) | polar stereographic, north | yes |
| NH | NH-2KM | 4-32 km | LIS, EIS | | polar stereographic, north | yes |
| PYR | PYR-250M | 500 m, 2 km | | | UTM 31N | yes |
| PAT | PAT-250M | 500 m, 2 km | NPI, SPI (250 m) | SRG, GCN, CDI (50, 100, 250 m) | UTM 18S | yes |
| ALP | ALP-250M | 500 m, 2 km | | | UTM 32N | no |
| HIM | HIM-250M | 500 m, 2 km | | | Albers equal-area (High Mountain Asia) | no |
| SVB | SVB-500M | 1 km, 2 km | | | UTM 33N | no |
| NZ | NZ-250M | 500 m, 2 km | | | NZTM2000 | no |
| GLOBAL | GLOBAL-0.1DEG | 0.25-5° | | | lon-lat | yes |

The nests of the ice sheets cover single drainage basins, with their ice shelves or
fjords and 50 km around them (see `domains.toml`): in Antarctica the Thwaites (THW) and
Pine Island (PIG) glaciers, and, inactive, the Filchner-Ronne (FRIS), Ross (ROSS) and
Amery (AMY) ice shelves with the grounded ice within 300 km upstream of them, and the
Wilkes Subglacial Basin (WSB); in Greenland Jakobshavn Isbrae (JAK), the Northeast
Greenland Ice Stream (NEGIS), and, inactive, the Petermann (PET) and Helheim (HEL)
glaciers. The crop ASE of ANT is the Amundsen Sea Embayment at 1 km.

The mountain-glacier domains (PYR to NZ) cover the extent of their glaciers at the Last
Glacial Maximum, each on the projection used for glacier modelling in its region (see
`domains.toml`). PAT covers Patagonia from 38°S to Cape Horn, with crops of the Northern
and Southern Patagonian Icefields (NPI, SPI), and nests of single icefields: the San
Rafael Glacier (SRG, whose 250 m grid is the v1 SRG-250M grid), Gran Campo Nevado (GCN)
and the Cordillera Darwin Icefield (CDI).

An **inactive** domain (`active = false`) is defined, but left out of the releases, the
website figures and the products made for all domains. Its grids and products are made
when it is named (e.g. `Topo/jobs/submit_domain.sh HIM`); set it active to release it.

The **GLOBAL** domain has global lon-lat grids at 0.1°, 0.25°, 0.5°, 1°, 2° and 5°,
each with cell edges at -180° and -90° (so they are not nested: 0.25° is not a
multiple of 0.1°). Its data are made by remapping (see Bring your own data).

Grids are named after their domain (or crop) and resolution: `ANT-8KM`, `GRL-500M`,
`GLOBAL-0.5DEG`. Each domain and crop has an output **folder** under `$ICE_DATA/v2`,
which is also its name in the released records (Antarctica, Amundsen, Thwaites,
PineIsland, FilchnerRonne, Ross, Amery, WilkesBasin, GreenlandPaleo, Greenland,
Jakobshavn, NEGIS, Petermann, Helheim, North, Laurentide, Eurasia, Pyrenees, Patagonia,
NorthPatagonianIcefield, SouthPatagonianIcefield, SRG, GranCampoNevado, CordilleraDarwin,
Alps, Himalaya, Svalbard, NewZealand, Global). Every grid has its own folder there, with all datasets on that grid:

```
$ICE_DATA/v2/<folder>/<GRID>/
    grid_<GRID>.txt         grid description (cdo)
    <GRID>_grid.nc          x, y, lon, lat and area of the cells
    <GRID>_TOPO-<product>.nc, <GRID>_REGIONS.nc, <GRID>_GHF-<source>.nc, ...
```

The grid files are written by Topo step 1 (`Topo/scripts/01_grids.jl`), or by
`fesmdata.jl remap` if they are missing.

## Adding a domain, a crop, a nest or a resolution

A domain is a table in `domains.toml`:

```toml
[PYR]
folder = "Pyrenees"
proj = "+proj=tmerc +lat_0=0 +lon_0=3 +k=0.9996 +x_0=500000 +y_0=0 +a=6378137 +rf=298.257223563 +units=km"
xlim = [107.875, 487.625]     # first and last cell centres of the base grid (km)
ylim = [4639.875, 4811.625]
resolutions = [0.25, 0.5]     # km; the first is the base grid
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
- `folder` must be unique among all domains and crops.

A lon-lat domain has `type = "lonlat"` and its resolutions in degrees, each dividing
180°; it needs no projection or extent:

```toml
[GLOBAL]
folder = "Global"
type = "lonlat"
resolutions = [0.1, 0.25, 0.5, 1, 2, 5]
```

A crop is a table below its domain, with its own folder and extent (on the cell
centres of the base grid), and optionally only some of the resolutions of its domain:

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

A new resolution is a new entry in `resolutions`. Then, for each dataset:

- **Topo**: add the products of the domain to `Topo/products.toml` (see the Topo
  README), and run its steps for the domain, from step 1 (the grid files).
- **Regions**: add the topography product for the zones of the domain to
  `Regions/regions.toml` (`[zone] products`), and basin sets if any to
  `Regions/basins.toml` (see the Regions README), and run its steps.

- **Thematic datasets** (e.g. GHF): add the domain to the `grids` of its products in
  `<Dataset>/remap.toml`, and run `julia fesmdata.jl remap <Dataset>`.

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

Most new datasets are fields from published maps (e.g. geothermal heat flow, surface
velocity, basal melt): these are **thematic datasets made by remapping**, defined by a
short `<Dataset>/remap.toml`, with one small `prepare.jl` per source (see Bring your
own data, `Remap/README.md`, and the GHF dataset).

A dataset that needs its own processing (merging sources, deriving fields) is a new
pipeline folder, built like Topo and Regions, so that it can be released in the same
way:

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
   keywords, description) and its functions to `dataset_pipeline` in
   `Publish/release.jl` (and include its `files.jl` there). It can then be released with
   `julia fesmdata.jl release <Dataset>` (see `Publish/README.md`), and appears on the
   website.
7. **Documentation**: add its README to the website (`docs/datasets/`, see
   `docs/_quarto.yml`).
