# Topo: high-resolution topography (v2)

Bed topography, surface elevation, ice thickness and ice/ocean fractions for each
model domain, from the best available sources, at resolutions from the base grid
down to 32 km for the ice sheets. The domains are the ice sheets (ANT, GRL-PAL, NH),
nests of single basins and ice shelves in ANT (500 m) and GRL-PAL (250 m), and the
mountain-glacier domains at 25-500 m: the Pyrenees (PYR), Patagonia (PAT) with its
icefields (crops NPI, SPI; nests SRG, GCN, CDI), the Himalaya (HIM) with the Drang Drung
Glacier (nest DDG, 25 m), and, inactive until needed, the Alps (ALP), Svalbard (SVB) and New
Zealand (NZ) (see
`../shared/README.md`).

The processing has two stages:

1. **Sources → base grid.** Each source is remapped once onto the base grid of a
   domain (e.g. ANT-1KM, GRL-PAL-500M, NH-2KM, PAT-250M, SRG-50M), and the sources are
   then merged in order of priority (e.g. BedMachine over GEBCO).
2. **Base → all other grids.** Every coarser grid, and the crops of a domain (GRL,
   LIS, EIS, NPI, SPI), is remapped from the merged base product.

Remapping is conservative: exact for sources on the same projection as the domain
(BedMachine, Bedmap3), and from sub-cell sampling for sources on other grids (GEBCO,
Copernicus DEM tiles, IceBoost glacier tiles, the Drang Drung data in UTM). The
methods are in [FesmUtils.jl](https://github.com/fesmc/FesmUtils.jl) and are
threaded.

Domains and resolutions are defined in `../shared/domains.toml` (shared with the
other pipelines), and the products of each domain in `products.toml`. Grid extents
follow the v1 grids in `../maps`, so the v1 grids at 4-32 km are reproduced, except
GRL-32KM, which has 53 instead of 54 columns so that its extent matches the finer
GRL grids, and the EIS grids, which are shifted by 16 km in y and extended so that they
lie on the NH grids at all resolutions (crops are cut from them on demand); the 250 m
grid of the SRG nest reproduces the v1 SRG-250M grid. The
ice-sheet domains are on polar stereographic projections, the mountain-glacier domains
on the projection used for glacier modelling in each region (UTM, NZTM2000, and the
Albers equal-area projection of High Mountain Asia).

Each domain has default products, from the latest sources, and variants, from
earlier versions of the ice-sheet datasets or other sources, made on request:

| Domain | Default products | Variants |
|---|---|---|
| ANT | BedMachine-v4, Bedmap3 | BedMachine-v3, BedMachine-v2, Bedmap2 |
| THW, PIG, FRIS, ROSS, AMY, WSB (nests of ANT) | BedMachine-v4, Bedmap3 | |
| GRL-PAL | BedMachine-v6 | BedMachine-v5, BedMachine-v4 |
| JAK, NEGIS, PET, HEL (nests of GRL-PAL) | BedMachine-v6 | |
| NH | GEBCO2026 | |
| PYR, PAT, SRG, GCN, CDI, ALP, HIM, SVB, NZ | GLO90-GEBCO2026 | |
| DDG (nest of HIM) | GLO90-GEBCO2026 | Sommers2025 |

All products use GEBCO 2026 outside the ice-sheet datasets, and the NH product adds
the IceBoost glaciers onto it. The mountain-glacier products (GLO90-GEBCO2026) take the
land from the Copernicus DEM GLO-90 and the ocean from GEBCO 2026, and add the IceBoost
glaciers onto the land. The Sommers2025 variant of DDG replaces them by the surface DEM
and ice thickness of the model setup of Sommers (2025) within their box. A new variant
is a new
entry under `[<domain>.variants]` in `products.toml` (with its sources in
`../datamanifest.toml` and `sources.jl`).

## Precision

The float fields are rounded on output to a tolerance by kind (see [Data volume and
precision](https://fesmc.github.io/FesmData/data_volume.html)): `z_bed`, `z_srf`, `H_ice`
and `z_bed_sd` to 0.01 m (0.05 m on NH and its crops), the area fractions (`f_*`) to 0.001. `mask` and `src_id` are
exact. The coarser grids are remapped from the rounded base grid and rounded again. The
sources on the base grid (step 2) are intermediate files and are not rounded.

## Layout

| Location | Contents |
|---|---|
| `$DATAMANIFEST_DATASETS_DIR` | Original datasets (see `../datamanifest.toml`) |
| `$ICE_DATA/v2/<Domain>/<GRID>/` | Output: `grid_<GRID>.txt`, `<GRID>_grid.nc`, `<GRID>_TOPO-<product>.nc` |
| `$FESMDATA_WORK/topo/` | Intermediate files (sources on base grids, IceBoost tile index) |
| `$DATAMANIFEST_DATASETS_DIR/copernicus_glo90/` | Copernicus DEM GLO-90 tiles of the domains that use them |

The environment variables are set per machine in `../shared/machines/<machine>.env`.

## Setup on a new machine

Install Julia 1.13.1 with juliaup:

```bash
curl -fsSL https://install.julialang.org | sh
juliaup add 1.13.1
```

The machine environment selects this version (`JULIAUP_CHANNEL`).

From the FesmData root, set the environment and install the packages (on Levante,
on a login node, since compute nodes have no internet access):

```bash
source shared/machines/levante.env
julia --project=Topo -e 'using Pkg; Pkg.instantiate()'
```

## Steps

All commands are run from the FesmData root after sourcing the machine environment.
On Levante, every step can be submitted as a job on a full compute node:

```bash
sbatch --job-name=<name> Topo/jobs/run_step.sbatch <script> <args...>
```

Logs go to `Topo/logs/`.

### 0. Original datasets

List the datasets and whether they are present:

```bash
julia --project=Topo Topo/scripts/00_sources.jl
```

GEBCO 2026 (4 GB zipped), Bedmap3 (2.5 GB), IceBoost v2.0 (one zip per RGI region)
and the Copernicus DEM GLO-90 tiles of the active domains that use them (1-degree
tiles, a few MB each) are downloaded automatically (Levante login node):

```bash
julia --project=Topo Topo/scripts/00_sources.jl --download
julia --project=Topo Topo/scripts/00_sources.jl --download NZ    # the tiles of an inactive domain
```

The other sources need a manual download into the path printed by the script:

- **BedMachine Greenland** (v4-v6) and **BedMachine Antarctica** (v2-v4) (NSIDC),
  including the versions no longer listed by NSIDC, need a free
  [NASA Earthdata login](https://urs.earthdata.nasa.gov). With the login in
  `~/.netrc` (`machine urs.earthdata.nasa.gov login <user> password <password>`):

  ```bash
  wget --load-cookies ~/.urs_cookies --save-cookies ~/.urs_cookies \
       --keep-session-cookies -P <folder> <uri>
  ```

  with `<uri>` from `../datamanifest.toml`.

### 1. Grids

Write the grid description and grid file of every grid of a domain:

```bash
julia --project=Topo -t 8 Topo/scripts/01_grids.jl GRL-PAL
```

The script also reports which grids match the v1 definitions in `../maps`.

### 2. Sources on the base grid

Remap each source of a domain onto its base grid (one job per source, about a
minute each on a Levante node):

```bash
sbatch --job-name=src-GRL-PAL-bm Topo/jobs/run_step.sbatch 02_regrid_source.jl GRL-PAL bedmachine_greenland_v6
sbatch --job-name=src-GRL-PAL-gebco Topo/jobs/run_step.sbatch 02_regrid_source.jl GRL-PAL gebco2026
```

Each writes `$FESMDATA_WORK/topo/<BASE>/<BASE>_<source>.nc` with `z_bed`, `z_srf`,
`H_ice`, `z_bed_sd` (sub-cell standard deviation of the bed), the area fractions
`f_ocn`, `f_land`, `f_grnd`, `f_flt`, and `f_valid` (fraction of the cell covered
by the source). Sources on the domain projection (BedMachine, Bedmap3) are remapped
exactly; GEBCO, and projected sources on another projection (the Drang Drung data), are
sampled at about half their resolution within each cell.

Land sources (the Copernicus DEM GLO-90) give only the elevation of the land, as
1-degree lon-lat tiles. Each tile overlapping the base grid is sampled within the base
cells it covers, at about half its latitude spacing, and the file has `z_land` and
`z_land_sd` (mean and standard deviation of the land elevation), `f_land` (land
fraction; elevations at or below 0 m are ocean) and `f_valid` (fraction covered by the
tiles).

Thickness sources (IceBoost) give only glacier ice thickness, as one tile per
glacier on its own projection (UTM). Each tile is sampled at about half its
resolution within the base cells it covers, and the file has `H_ice` (cell mean, 0
off the glaciers) and `f_ice` (glacier area fraction). The pixels touched by a
glacier outline count as glacier in the tiles, so the thickness and area of each
tile are scaled to the glacier volume and area given with it (the raw pixels give
2% more volume and 3-6% more area). Tiles still overlap along shared ice divides:
where their glacier fractions add up to more than 1, the cell is shared, its glacier
fraction and thickness divided by that sum, so that the overlap is not counted twice
(this matters on grids of 50-250 m, where a boundary is a large part of a cell). The job
log compares the glacier area and volume with those of the tiles, before and after.

Only the tiles overlapping the base grid are read (threaded). Their grids and
latitude ranges, from the file headers, are kept in an index per RGI region
(`$FESMDATA_WORK/topo/tiles/iceboost_v2_rgiNN.tsv`), which the first IceBoost job
builds in about 5 min, and rebuilds when the files of a region change. With the
index, IceBoost takes under a minute for PYR and SRG and about 11 min for NH, mostly
for sampling the 74,000 tiles that overlap NH-2KM.

Source notes (see `sources.jl`):

- Surface elevation is 0 over the ocean for all sources.
- BedMachine Antarctica: the surface includes firn air (`firn`), and the ice
  thickness does not. Lake Vostok is grounded ice.
- BedMachine Greenland v4 and v5: non-Greenland land (Canadian Arctic) is ice-free
  land.
- Bedmap3: the transiently grounded ice shelf is floating ice.
- Bedmap2 (1 km, GeoTIFFs): rock outcrops are ice-free land, and Lake Vostok is
  grounded ice. Heights are relative to the GL04C geoid (EIGEN-6C4 for BedMachine).
- GEBCO is used as ice-free topography and bathymetry. Its sub-ice grid only has
  ice thickness for the Greenland and Antarctic ice sheets (covered by the regional
  sources), and differs from the main grid by a few metres elsewhere.
- IceBoost v2.0 (Maffezzoli et al., doi:10.5281/zenodo.17724512; RGI 7.0 outlines)
  gives the ice thickness of the glaciers and ice caps outside Greenland in the NH
  product, and of the glaciers of the mountain-glacier domains (RGI regions 07, 11,
  13-15, 17, 18). BedMachine Greenland v6 uses the same dataset for the peripheral
  glaciers of Greenland.
- Copernicus DEM GLO-90 (ESA, doi:10.5270/ESA-c5d3d65; the edited TanDEM-X DEM,
  acquisitions 2011-2015, heights above the EGM2008 geoid) gives the land surface of
  the mountain-glacier products. IceBoost v2.0 takes its surface features from the
  TanDEM-X EDEM, from the same acquisitions, so the surface and the glacier thickness
  are consistent. The ocean is 0 m in its tiles, and there are no tiles over the open
  ocean; land below sea level is taken as ocean. Products from it must credit
  "Copernicus WorldDEM-90 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH
  2014-2018 provided under COPERNICUS by the European Union and ESA".
- Drang Drung Glacier (`sommers2025_drangdrung`, DDG variant Sommers2025): the surface
  DEM and ice thickness of the ISSM setup of Sommers (2025, "Seasonal variability in ice
  velocity driven by subglacial hydrology of Drang Drung Glacier, Western Himalayas:
  Modeling scripts and data", doi:10.5281/zenodo.17593643, CC BY 4.0), MATLAB files on
  UTM zone 43N (EPSG:32643; not stated in the record, but the outline lies on the
  glacier, and the DEM matches GLO-90 to 12 m (s.d.) on ice-free land at 50 m). The
  surface is the 2 m DEM of LEGOS and OMP (2025), in heights above the WGS84 ellipsoid
  (21 m above GLO-90 on ice-free land, the EGM2008 geoid height there): it is converted
  to heights above the EGM2008 geoid at each point (PROJ, with the EGM2008 grid of the
  PROJ data, `egm2008_geoid`), and its voids (29% of the grid, mostly on ice-free
  slopes, 0.06 km² within the model domain) are filled with the GLO-90 surface
  (bilinear). The ice thickness is that of Millan et al. (2022,
  doi:10.1038/s41561-021-00885-z), 50 m, for all glaciers in a 25 x 25 km box (0 off
  the ice; RGI 6.0 outlines). The source is the DEM grid within that box (20.5 x 24 km),
  with bed = surface - thickness; it covers 77% of DDG, all but its edges (most of them
  in the south). Products from it must credit
  Sommers (2025), LEGOS and OMP (2025) for the DEM and Millan et al. (2022) for the ice
  thickness.

### 3. Merge

Merge the sources of the products of a domain:

```bash
sbatch --job-name=merge-ANT Topo/jobs/run_step.sbatch 03_merge.jl ANT [PRODUCTS]
```

`PRODUCTS` is `default` (the default products, if omitted), `variants`, `all`, or
the name of one product; the same holds for steps 4 and 5.

This writes `$ICE_DATA/v2/<folder>/<BASE>/<BASE>_TOPO-<product>.nc`. Sources are
blended in order of increasing priority: a source replaces the fields below it where
it fully covers a cell, with a weight rising linearly from 0 at the edge of its
coverage to 1 at a taper width inside it, a property of the source (`taper_km` in
`sources.jl`, recorded in the file attribute `taper_km`): 20 km, so that the regional
datasets meet GEBCO smoothly, and 0 for the Drang Drung data, whose coverage is smaller
than that and whose edge lies on land of nearly the same surface, so that they replace
exactly the cells they fully cover. The ice fraction of each cell is then grounded or
floating as a whole, by flotation of its mean ice thickness and bed (densities in
`products.toml`). Surface elevation is kept as given by the sources (in Antarctica it
includes firn air). The file also has `mask` (dominant surface type: 0 ocean, 1
ice-free land, 2 grounded ice, 3 floating ice) and `src_id` (source with the largest
weight).

A land source sets the land wherever its tiles reach (without taper, since it meets
GEBCO at sea level along the coast): its land fraction becomes ice-free land with its
elevation as bed and surface, and the rest of the cell ocean, with the GEBCO bed below
it (at most sea level). The bed standard deviation combines both parts.

A thickness source adds its glaciers onto the ice-free land of the sources below it
(GEBCO or the Copernicus DEM, whose elevation is the ice surface): the glacier fraction, at most the
ice-free land fraction, becomes grounded ice, and the bed is lowered by the
cell-mean ice thickness. Glaciers on ocean (e.g. retreated termini) are
dropped. Cells with glacier ice are always grounded. In the NH product, BedMachine
replaces the glaciers within its coverage.

### 4. All grids

Remap each product from the base grid onto all other grids of the domain, including
the crops (GRL from GRL-PAL, LIS and EIS from NH):

```bash
sbatch --job-name=grids-all-ANT Topo/jobs/run_step.sbatch 04_grids.jl ANT [PRODUCTS]
```

This writes `$ICE_DATA/v2/<folder>/<GRID>/<GRID>_TOPO-<product>.nc`. Fields and
fractions are conservative cell means, `z_bed_sd` combines the sub-cell variance of
the base grid with the variance of the base-grid means, `mask` is the dominant
surface type (ice where the ice fraction is at least one half), and `src_id` the
source covering most of the cell.

### 5. Checks

```bash
sbatch --job-name=plots-ANT Topo/jobs/run_step.sbatch 05_plots.jl ANT [PRODUCTS]
```

This writes plots to `$FESMDATA_WORK/topo/plots/` (the base product, ice thickness
on all grids, the difference with the v1 product at 16 or 32 km, and for a variant
the difference with a default product at 4 km, or on the base grid of DDG), with colour
ranges from the data (elevations centred on sea level where there is ocean), and prints
the ice area and volume on every grid in the job log as a conservation check.

## Running a whole domain

`jobs/submit_domain.sh` submits steps 1-5 of a domain as a chain of jobs (step 2
as one job per source), each starting when the previous step succeeded:

```bash
Topo/jobs/submit_domain.sh ANT                # all steps
Topo/jobs/submit_domain.sh ANT 3              # from step 3
Topo/jobs/submit_domain.sh ANT 2 variants     # the variants, from step 2
```

The third argument selects the products (as for steps 3-5), and step 2 then remaps
only their sources.

## Adding a source, a product or a domain

**A source** (a new topography dataset, or a new version of one):

1. Add it to `../datamanifest.toml`, with its `uri`, `doi` and, for a manual download
   (e.g. NSIDC), `skip_download = true`; `00_sources.jl` then lists and downloads it.
2. Add a reader to `sources.jl` and a branch for it in `read_source`. A topography
   source returns `(grid, z_bed, z_srf, H_ice, mask)` on its native grid, with
   ascending axes: `grid` a `ProjGrid` (any projection) or `LonLatGrid`, heights in m
   (surface 0 over the ocean), and `mask` with the classes `OCEAN`, `LAND`, `GRND`,
   `FLT`; all fields are `missing` where the source has no data (the part of a base
   cell with data is its `f_valid`).
   A source on the projection of a domain is remapped exactly; any other is sampled
   within each base cell. A source that only gives glacier thickness (like IceBoost)
   is a thickness source (`is_thickness_source`, `GlacierTiles`), and a source that
   only gives the elevation of the land in lon-lat tiles (like the Copernicus DEM) a
   land source (`is_land_source`, `DEMTiles`).
3. Use it in a product (below) and run the steps from step 2 for the domain (step 2
   only for the new source: `02_regrid_source.jl <DOMAIN> <source>`).

**A product or a variant** is an entry in `products.toml`: its name and its sources in
order of priority, highest first, under `[<domain>.products]` (default products,
released and made by default) or `[<domain>.variants]` (made on request with
`variants` or `all`):

```toml
[ANT.variants]
"BedMachine-v3" = ["bedmachine_antarctica_v3", "gebco2026"]
```

Then run steps 2-5 for it (`submit_domain.sh ANT 2 BedMachine-v3`). The lowest-priority
source must be a topography source covering the whole domain (GEBCO), and a land
source must come before it. Variants are
released with the default products.

**A domain**: define it in `../shared/domains.toml` (see `../shared/README.md`), add its
densities (`rho_ice`, `rho_sw`) and products to `products.toml`, and run all steps
(`submit_domain.sh <DOMAIN>`). For glaciers outside the IceBoost regions already listed
in `../datamanifest.toml` (`iceboost_v2_rgiNN`), add the RGI region there.

## Glaciers in the NH product

IceBoost glaciers in the NH product (GEBCO 2026, run of 2026-10-09):

| | Area (km²) | Volume (km³) |
|---|---:|---:|
| IceBoost tiles overlapping NH-2KM (73,841 of 80,411, incl. parts outside the domain) | 348,853 | 74,614 |
| Raw tile pixels, before scaling to the glacier area and volume | 376,646 | 76,802 |
| Glaciers on NH-2KM (`f_ice` ≤ 1; max before limiting 1.16) | 348,134 | 74,656 |
| Within BedMachine Greenland coverage (replaced by BedMachine) | 49,679 | 11,384 |
| On GEBCO ocean (dropped) | 600 | 61 |
| NH product ice, without glaciers | 1,865,112 | 3,007,068 |
| NH product ice, with glaciers | 2,164,800 | 3,070,576 |

The GRL-PAL and ANT products are unchanged (bitwise identical before and after
adding thickness sources).

## Glaciers in the mountain-glacier products

The glacier area and volume of each mountain-glacier product, against those of the
IceBoost tiles, are printed by step 2 (IceBoost) and step 5 in the job logs; a table
follows with the first runs of the GLO90-GEBCO2026 products.

On DDG-25M (run of 2026-10-13), the Sommers2025 variant against the default product:

| | GLO90-GEBCO2026 area (km²) | volume (km³) | Sommers2025 area (km²) | volume (km³) |
|---|---:|---:|---:|---:|
| DDG | 271.7 | 27.03 | 269.9 | 31.26 |
| Coverage of the Sommers data (486.5 km²) | 221.1 | 22.55 | 219.2 | 26.77 |
| Model domain of Sommers (2025), DD.exp (27.0 km²) | 24.2 | 5.26 | 27.0 | 7.42 |

Within the model domain the ice is 275 m thick on average (max 507 m) in Millan et al.
(2022), against 218 m (max 398 m) in IceBoost; the surfaces differ by -4.9 m (rms 9.5
m), about the thinning since the GLO-90 acquisitions. Across the edge of the coverage
the surface steps by -1.8 m on average (rms 17.5 m, against 10 m between neighbouring
cells), and the ice thickness on glaciers by 10 m (rms 43 m, Millan against IceBoost).

