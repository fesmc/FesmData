# Topo: high-resolution topography (v2)

Bed topography, surface elevation, ice thickness and ice/ocean fractions for each
model domain, from the best available sources, at resolutions from the base grid
down to 32 km.

The processing has two stages:

1. **Sources → base grid.** Each source is remapped once onto the base grid of a
   domain (ANT-1KM, GRL-PAL-500M, NH-2KM), and the sources are then merged in
   order of priority (e.g. BedMachine over GEBCO).
2. **Base → all other grids.** Every coarser grid, and the crops of a domain (GRL,
   LIS, EIS), is remapped from the merged base product.

Remapping is conservative: exact for sources on the same projection as the domain
(BedMachine, Bedmap3), and from sub-cell sampling for lon-lat sources (GEBCO). The
methods are in [FesmUtils.jl](https://github.com/fesmc/FesmUtils.jl) and are
threaded.

Domains, resolutions and products are defined in `domains.toml`. Grid extents
follow the v1 grids in `../maps`, so the v1 grids at 4-32 km are reproduced, except
GRL-32KM, which has 53 instead of 54 columns so that its extent matches the finer
GRL grids.

## Layout

| Location | Contents |
|---|---|
| `$DATAMANIFEST_DATASETS_DIR` | Original datasets (see `../datamanifest.toml`) |
| `$ICE_DATA/v2/<Domain>/<GRID>/` | Output: `grid_<GRID>.txt`, `<GRID>_grid.nc`, `<GRID>_TOPO-<product>.nc` |
| `$FESMDATA_WORK/topo/` | Intermediate files (sources on base grids) |

The environment variables are set per machine in `machines/<machine>.env`.

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
source Topo/machines/levante.env
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

GEBCO 2025 (surface and sub-ice, ~4 GB each zipped) and Bedmap3 (2.5 GB) are
downloaded automatically (Levante login node):

```bash
julia --project=Topo Topo/scripts/00_sources.jl --download
```

The other sources need a manual download into the path printed by the script:

- **BedMachine Greenland v6** and **BedMachine Antarctica v4** (NSIDC) need a free
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
sbatch --job-name=src-GRL-PAL-gebco Topo/jobs/run_step.sbatch 02_regrid_source.jl GRL-PAL gebco2025
```

Each writes `$FESMDATA_WORK/topo/<BASE>/<BASE>_<source>.nc` with `z_bed`, `z_srf`,
`H_ice`, `z_bed_sd` (sub-cell standard deviation of the bed), the area fractions
`f_ocn`, `f_land`, `f_grnd`, `f_flt`, and `f_valid` (fraction of the cell covered
by the source). Sources on the domain projection (BedMachine, Bedmap3) are remapped
exactly; GEBCO is sampled at about half its resolution within each cell.

Source notes (see `sources.jl`):

- Surface elevation is 0 over the ocean for all sources.
- BedMachine Antarctica: the surface includes firn air (`firn`), and the ice
  thickness does not. Lake Vostok is grounded ice.
- Bedmap3: the transiently grounded ice shelf is floating ice.
- GEBCO: ice thickness is surface minus sub-ice elevation, which is only non-zero
  on the Greenland and Antarctic ice sheets. Under ice shelves the sub-ice
  elevation is the sea floor, so GEBCO ice-shelf thickness is not usable.

### 3-5. Merge, all grids, checks

To come: merge the sources into each product, remap the product onto all grids,
and plot checks.
