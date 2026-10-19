# FesmData storage

This folder (`$FESMDATA`) holds the products of FesmData
(https://github.com/fesmc/FesmData, website https://fesmc.github.io/FesmData/):
processed datasets for ice-sheet and Earth-system models, on the grids of each model
domain, as released: `<Domain>/<GRID>/<GRID>_<Dataset>-<product>.nc`, with the grid files
`grid_<GRID>.txt` (cdo) and `<GRID>_grid.nc` (lon, lat, area) in each grid folder; the
records (non-gridded data) in `Records/<Dataset>/`. It is a copy of
`shared/machines/FESMDATA_README.md` of the repository.

The data the products are made from are in the sibling folders `fesmdata-sources` (the
original datasets, downloads of `datamanifest.toml`) and `fesmdata-prepared` (the sources
prepared for remapping, `<source>/prepare.jl`), where processing is done. The
intermediate files are per user on scratch (`$FESMDATA_WORK`).

## Using the products

Read the files directly (or `ln -s $FESMDATA` where a model expects them): a grid
folder holds everything a model needs on that grid. The datasets, domains and grids, and the fields of each file, are described on
the website (Datasets, Domains). Each file records its version (`fesmdata_version`) and
the precision of its fields in its attributes.

The products of the nests and crops of a domain (e.g. Thwaites, Jakobshavn, Greenland)
that are not released for them are cut from those of the domain that contains them; they
carry a `cropped_from` attribute.

## Updating

The products are updated after each release from the repository, in a checkout of
FesmData (Julia 1.13 via juliaup):

```bash
source shared/machines/<machine>.env      # levante or albedo: sets FESMDATA
julia fesmdata.jl mirror --yes            # new releases, and the crops of the nests and crops
julia fesmdata.jl prune --yes             # files no release refers to any more
```

Only files that changed are downloaded; files changed locally stop `mirror`. Please do
not edit or add files here: put your own files elsewhere, or remap your own
data with `julia fesmdata.jl remap` (website, Your own data).

## Where

| Machine | `$FESMDATA` | Group (write access) |
|---|---|---|
| DKRZ Levante | `/work/ba1442/fesmdata` | ba1442 |
| AWI Albedo | `/albedo/work/projects/p_forclima/fesmdata` | p_forclima |

Contact: Alexander Robinson.
