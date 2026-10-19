# Grids: the grid files of each grid

Every grid of FesmData has two grid files, in its folder
`$FESMDATA/<Domain>/<GRID>/`:

```
grid_<GRID>.txt         grid description for cdo (e.g. cdo remapcon,grid_ANT-8KM.txt)
<GRID>_grid.nc          x, y, lon, lat and area of the cells
```

They are released once per grid, in the dataset Grids, for all datasets on the grid: on
each domain, the grids with products of at least one dataset. `fetch` and `mirror` get
them with the products of any dataset on the grid; `fetch Grids <Domain>` gets those of
all grids of a domain. They are listed on the website under
[Domains and grids](https://fesmc.github.io/FesmData/domains.html#grid-files).

## Making the dataset

The grids are defined by `shared/domains.toml` (see
[Domains and grids](https://fesmc.github.io/FesmData/domains.html)). Their grid files are written
by Topo step 1 (`Topo/scripts/01_grids.jl`) on the projected grids of the domains, nests
and crops, and by `fesmdata.jl remap` on the global lon-lat grids (or on any grid whose
grid files are not released yet; those released are downloaded instead).

When grid files are written again (e.g. by Topo step 1 at a new commit), release Grids
before the datasets on these grids: a release of a gridded dataset checks that its grid
files are those of the release of Grids (see
[Releasing](https://fesmc.github.io/FesmData/releasing.html)).
