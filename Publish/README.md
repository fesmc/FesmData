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

## Release

The datasets, their file patterns and the record metadata (creators, licence,
community, description) are set in `datasets.toml`. A release of a dataset on a domain
folder:

1. Tag the release, e.g. `topo-v2.0.0`, and push the tag.
2. Run the pipeline at the tag (clean checkout), so that every file has
   `fesmdata_version = "topo-v2.0.0"`.
3. Upload the files to a Zenodo draft (on Levante, where the files are):

   ```bash
   julia --project=Publish Publish/scripts/zenodo.jl upload Antarctica Topo --dry-run
   julia --project=Publish Publish/scripts/zenodo.jl upload Antarctica Topo
   ```

   The first release creates the record, later ones a new version of the record in
   the registry. Files that are unchanged on Zenodo are kept, the others uploaded.
4. Review the draft on Zenodo and publish it there. Publishing cannot be undone.
5. Register the published record and commit the registry file:

   ```bash
   julia --project=Publish Publish/scripts/zenodo.jl register Antarctica Topo <record id>
   ```

   This checks that the files on Zenodo are the local files (md5) and writes
   `registry/Antarctica/Topo.toml` with their sha256 checksums.

`upload` checks that all files of the dataset have the same version, an existing
release tag, and that the grid files were made at a commit. `--allow-untagged` skips
these checks (e.g. for a test). `--draft=<id>` continues an existing draft.

The token is read from `ZENODO_TOKEN` (scopes `deposit:write` and `deposit:actions`),
which the machine environments set from `~/.zenodo_token`. To test, use
[the sandbox](https://sandbox.zenodo.org) with `--sandbox` (token in
`~/.zenodo_sandbox_token`); its registry files go to `registry/_sandbox/`, which is not
tracked, and `fetch.jl --sandbox` downloads from them.

## Website

The website (GitHub Pages) lists the datasets of `datasets.toml` and the records,
grids and files of the registry, with download links. It is built by
`.github/workflows/site.yml` on every push to main that changes the registry or
Publish. To build it locally:

```bash
julia --project=Publish Publish/scripts/site.jl _site
```
