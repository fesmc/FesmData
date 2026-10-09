# Publish: processed products on Zenodo

The processed products of the v2 pipelines (Topo, Regions, ...) are published on
[Zenodo](https://zenodo.org/communities/fesmc), in the `fesmc` community, with one
record per dataset and domain folder (e.g. Antarctica / Topo). A record holds all grids
of that folder, from the base grid to 32 km, and the grid files. Each release of a
dataset (git tag `<dataset>-vX.Y.Z`, e.g. `topo-v2.0.0`) is a new version of its
record, with its own DOI; the concept DOI of the record always resolves to the latest
version.

## Registry

Every record has a registry file, `../registry/<Domain>/<Dataset>.toml`, with the
record metadata (`[_ZENODO]`: DOIs, version, git tag) and one entry per file:

```toml
["ANT-4KM_TOPO-Bedmap3.nc"]
uri = "https://zenodo.org/records/<id>/files/ANT-4KM_TOPO-Bedmap3.nc?download=1"
checksum = "sha256:<hex>"
size = 123456789
storage_path = "$datasets_dir/Antarctica/ANT-4KM/ANT-4KM_TOPO-Bedmap3.nc"
```

`$datasets_dir` stands for `$ICE_DATA/v2`, so the files land in the usual layout,
`$ICE_DATA/v2/<Domain>/<GRID>/`. The registry files are also
[DataManifest.jl](https://github.com/awi-esc/DataManifest.jl) databases.

## Download

Set `ICE_DATA` (e.g. `source shared/machines/<machine>.env`), then from the FesmData
root:

```bash
julia --project=Publish -e 'using Pkg; Pkg.instantiate()'
julia --project=Publish Publish/scripts/fetch.jl                                  # list the records
julia --project=Publish Publish/scripts/fetch.jl Antarctica Topo                  # all grids
julia --project=Publish Publish/scripts/fetch.jl Antarctica Topo ANT-8KM ANT-16KM # some grids
```

Files already present are kept if their checksum matches the registry. A file that
differs (another version, or changed locally) stops the download, unless
`--overwrite` is given.
