# Topo: high-resolution topography (v2)

Bed topography, surface elevation, ice thickness and ice/ocean fractions for each
model domain, from the best available sources, at resolutions from the base grid
down to 32 km (16 km for SRG). The domains are the ice sheets (ANT, GRL-PAL, NH)
and two mountain-glacier domains, the Pyrenees (PYR) and the San Rafael Glacier
in Patagonia (SRG).

The processing has two stages:

1. **Sources → base grid.** Each source is remapped once onto the base grid of a
   domain (ANT-1KM, GRL-PAL-500M, NH-2KM, PYR-500M, SRG-250M), and the sources are then merged in
   order of priority (e.g. BedMachine over GEBCO).
2. **Base → all other grids.** Every coarser grid, and the crops of a domain (GRL,
   LIS, EIS), is remapped from the merged base product.

Remapping is conservative: exact for sources on the same projection as the domain
(BedMachine, Bedmap3), and from sub-cell sampling for sources on other grids (GEBCO,
IceBoost glacier tiles). The
methods are in [FesmUtils.jl](https://github.com/fesmc/FesmUtils.jl) and are
threaded.

Domains and resolutions are defined in `../shared/domains.toml` (shared with the
other pipelines), and the products of each domain in `products.toml`. Grid extents
follow the v1 grids in `../maps`, so the v1 grids at 4-32 km are reproduced, except
GRL-32KM, which has 53 instead of 54 columns so that its extent matches the finer
GRL grids. The ice-sheet domains are on polar stereographic projections, PYR and SRG
on UTM (zones 31N and 18S). PYR has no v1 grid: it covers the whole range with
20-30 km of foreland (see `domains.toml`). SRG reproduces the v1 SRG-16KM grid (5 x 3
cells), and its base grid SRG-250M covers the same area; it is therefore larger than
the v1 SRG-250M grid (257 x 129 instead of 208 x 120 cells), whose cell centres are
offset by half a cell (125 m) in x and y from those of SRG-250M here.

Each domain has default products, from the latest sources, and variants, from
earlier versions of the ice-sheet datasets, made on request:

| Domain | Default products | Variants |
|---|---|---|
| ANT | BedMachine-v4, Bedmap3 | BedMachine-v3, BedMachine-v2, Bedmap2 |
| GRL-PAL | BedMachine-v6 | BedMachine-v5, BedMachine-v4 |
| NH | GEBCO2026 | |
| PYR | GEBCO2026 | |
| SRG | GEBCO2026 | |

All products use GEBCO 2026 outside the ice-sheet datasets, and the NH, PYR and
SRG products add the IceBoost glaciers onto it. A new variant is a new
entry under `[<domain>.variants]` in `products.toml` (with its sources in
`../datamanifest.toml` and `sources.jl`).

## Layout

| Location | Contents |
|---|---|
| `$DATAMANIFEST_DATASETS_DIR` | Original datasets (see `../datamanifest.toml`) |
| `$ICE_DATA/v2/<Domain>/<GRID>/` | Output: `grid_<GRID>.txt`, `<GRID>_grid.nc`, `<GRID>_TOPO-<product>.nc` |
| `$FESMDATA_WORK/topo/` | Intermediate files (sources on base grids, IceBoost tile index) |

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

GEBCO 2026 (4 GB zipped), Bedmap3 (2.5 GB) and IceBoost v2.0 (1.3 GB zipped, one
zip per RGI region) are downloaded automatically (Levante login node):

```bash
julia --project=Topo Topo/scripts/00_sources.jl --download
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
exactly; GEBCO is sampled at about half its resolution within each cell.

Thickness sources (IceBoost) give only glacier ice thickness, as one tile per
glacier on its own projection (UTM). Each tile is sampled at about half its
resolution within the base cells it covers, and the file has `H_ice` (cell mean, 0
off the glaciers) and `f_ice` (glacier area fraction). The pixels touched by a
glacier outline count as glacier in the tiles, so the thickness and area of each
tile are scaled to the glacier volume and area given with it (the raw pixels give
2% more volume and 3-6% more area). Tiles still overlap along shared ice divides,
where `f_ice` is limited to 1. The job log compares the glacier area and volume with
those of the tiles.

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
  product, and of the glaciers of PYR (RGI region 11) and SRG (region 17). BedMachine
  Greenland v6 uses the same dataset for the peripheral glaciers of Greenland.

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
coverage to 1 at 20 km inside it. The ice fraction of each cell is then grounded or
floating as a whole, by flotation of its mean ice thickness and bed (densities in
`products.toml`). Surface elevation is kept as given by the sources (in Antarctica it
includes firn air). The file also has `mask` (dominant surface type: 0 ocean, 1
ice-free land, 2 grounded ice, 3 floating ice) and `src_id` (source with the largest
weight).

A thickness source adds its glaciers onto the ice-free land of the sources below it
(GEBCO, whose elevation is the ice surface): the glacier fraction, at most the
ice-free land fraction, becomes grounded ice, and the bed is lowered by the
cell-mean ice thickness. Glaciers on GEBCO ocean (e.g. retreated termini) are
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
the difference with a default product at 4 km), and prints
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

## Glaciers in the PYR and SRG products

IceBoost glaciers (RGI 7.0, 2000 outlines) on the base grids (GEBCO 2026, run of
2026-10-10):

| | Tiles | Area (km²) | Volume (km³) |
|---|---:|---:|---:|
| PYR-500M (RGI 11) | 45 | 4 | 0.08 |
| SRG-250M (RGI 17) | 134 | 1,261 | 483 |

On the extent of the v1 SRG-250M grid, the SRG product has 1,224 km² and 433 km³ of
ice, against 1,149 km² and 358 km³ in the v1 SRG-250M_TOPO.nc (from an inversion of
the Northern Patagonian Icefield thickness). Surface elevations agree (v2 - v1: mean
1 m, rmse 56 m); the ice thickness differs by 164 m rms (v2 thinner along the trunk of
the San Rafael Glacier, thicker on its sides).

The coarser SRG grids extend beyond the base grid (by half a coarse cell, as for all
domains), where their cells are means over the part the base grid covers. On a domain
this small the overhang is a large part of the coarse grids (SRG-16KM covers 1.85
times the area of SRG-250M), so their ice volume grows with the cell size, from 483
km³ on SRG-250M to 762 km³ on SRG-16KM.
