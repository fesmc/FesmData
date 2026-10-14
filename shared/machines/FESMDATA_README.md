# FesmData storage

This folder (`$FESMDATA`) holds the data of FesmData
(https://github.com/fesmc/FesmData, website https://fesmc.github.io/FesmData/):
processed datasets for ice-sheet and Earth-system models, on the grids of each model
domain. It is a copy of `shared/machines/FESMDATA_README.md` of the repository.

| Folder | Contents |
|---|---|
| `products/` | The released products: `<Domain>/<GRID>/<GRID>_<Dataset>-<product>.nc`, with the grid files `grid_<GRID>.txt` (cdo) and `<GRID>_grid.nc` (lon, lat, area) in each grid folder; the records (non-gridded data) in `Records/<Dataset>/` |
| `sources/` | The original datasets (downloads of `datamanifest.toml`), to make the products |
| `prepared/` | The sources prepared for remapping (`<source>/prepare.jl`) |

The intermediate files are per user on scratch (`$FESMDATA_WORK`), not here.

## Using the products

Read the files in `products/` directly: a grid folder holds everything a model needs on
that grid. The datasets, domains and grids, and the fields of each file, are described on
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
not edit or add files in `products/`: put your own files elsewhere, or remap your own
data with `julia fesmdata.jl remap` (website, Your own data).

## Where

| Machine | `$FESMDATA` | Group (write access) |
|---|---|---|
| DKRZ Levante | `/work/ba1442/fesmdata` | ba1442 |
| AWI Albedo | `/albedo/work/projects/p_forclima/fesmdata` | p_forclima |

Contact: Alexander Robinson.
