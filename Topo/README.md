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
juliaup default 1.13.1
```

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

GEBCO 2025 (surface and sub-ice, ~4 GB each zipped) is downloaded automatically
(Levante login node):

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
- **Bedmap3**: download `bedmap3.nc` (2.4 GB) from the
  [UK Polar Data Centre](https://doi.org/10.5285/2d0e4791-8e20-46a3-80e4-f5f6716025d2).

### 1. Grids

Write the grid description and grid file of every grid of a domain:

```bash
julia --project=Topo -t 8 Topo/scripts/01_grids.jl GRL-PAL
```

The script also reports which grids match the v1 definitions in `../maps`.

### 2-5. Sources, merge, all grids, checks

To come: remap each source onto the base grid, merge them into each product,
remap the product onto all grids, and plot checks.
