# Publish: releases of the processed products

All commands go through `fesmdata.jl` at the root of FesmData: `julia fesmdata.jl
help` lists them. Finding and downloading (`list`, `fetch`) needs only Julia; the
release commands install the packages of `Publish/` themselves when needed.

The processed products of the v2 pipelines (Topo, Regions, ...) are released on the
package registry of the GitLab project
[fesmc/fesmdata-products](https://codebase.helmholtz.cloud/fesmc/fesmdata-products/-/packages)
(Helmholtz Codebase), and listed on the [website](https://fesmc.github.io/FesmData/). A
release of a dataset (tag `<dataset>-vX.Y.Z`, e.g. `topo-v2.0.0`) covers all its
domains, with one package per domain, dataset and grid, e.g. `Antarctica_Topo_ANT-32KM`
version `2.0.0`, with the files of that grid (grid description, grid file and products).
Domains are named by their output folder (`folder` in `../shared/domains.toml`, e.g.
Antarctica, Greenland, Patagonia; all are listed on the
[Domains](https://fesmc.github.io/FesmData/domains.html) page). Records datasets
(non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)) have no grids: they
are released on the domain `Records`, with one package per dataset, e.g. `Records_IceCores`,
with its files in `$FESMDATA_PRODUCTS/Records/<Dataset>/`.

A release can also be archived on [Zenodo](https://zenodo.org/communities/fesmc), in
the `fesmc` community, for a DOI: one Zenodo record per dataset and domain, with a DOI
per version.

## Registry

Every dataset on a domain has a registry file, `../registry/<Domain>/<Dataset>.toml`, with the
release (`[_RELEASE]`: version, tag, date, link to the packages), its DOIs if archived
on Zenodo (`[_ZENODO]`), and one entry per file:

```toml
["ANT-4KM_TOPO-Bedmap3.nc"]
uri = "https://codebase.helmholtz.cloud/api/v4/projects/22725/packages/generic/Antarctica_Topo_ANT-4KM/2.0.0/ANT-4KM_TOPO-Bedmap3.nc"
checksum = "sha256:<hex>"
size = 123456789
storage_path = "$datasets_dir/Antarctica/ANT-4KM/ANT-4KM_TOPO-Bedmap3.nc"
```

`$datasets_dir` stands for `$FESMDATA_PRODUCTS`, so the files land in the usual layout,
`$FESMDATA_PRODUCTS/<Domain>/<GRID>/`. A file that changed since an earlier release (if
only by the version stamped in it) also has `previous_checksums`, the checksums of
its earlier releases, so that copies of those are updated. The registry files are also
[DataManifest.jl](https://github.com/awi-esc/DataManifest.jl) databases.

## Download

Finding and downloading the products (`list`, `fetch`, `mirror`) is described on the
[Download](https://fesmc.github.io/FesmData/download.html) page.

## Release

The datasets, the GitLab project and the Zenodo metadata (creators, licence,
community) are set in `datasets.toml`. The files of a release on each grid are defined
by the pipeline of the dataset (`topo_release_files` in `../Topo/files.jl`: all
products of the domain, default and variants; `regions_release_files` in
`../Regions/files.jl`), and must all be present. A release of a dataset (here GHF,
version 2.0.0) is made on Levante, where the files are, from the files as they were
made and checked, and needs a GitLab token (see Access below). It takes four steps.

**1. Tag the release** (from any checkout, after the changes are on main):

```bash
git fetch origin
git tag -a ghf-v2.0.0 -m "GHF v2.0.0" origin/main
git push origin ghf-v2.0.0
```

**2. Stamp the files** with the tag, from the usual checkout at the tag (no
uncommitted changes):

```bash
cd ../FesmData && git pull
source shared/machines/levante.env
julia fesmdata.jl stamp GHF
```

`stamp` sets `fesmdata_version` of every file of the release to the tag, in place
(only the global attributes change). `fesmdata_commit` stays the commit that made the
file, and `history` records the stamp and the version the file was made at, so that
files made before the tag (whose code may differ in details from the tag) can be
recognised. The files are not made again: a product is made and checked once, and
released as it is. To make a release fully reproducible from its tag instead, make
the files again in a clean checkout of the tag (e.g. `git worktree add
../FesmData-ghf-v2.0.0 ghf-v2.0.0`, then the pipeline there with `--overwrite`); they
then have the tag already.

**3. Upload**:

```bash
julia fesmdata.jl release GHF --dry-run
julia fesmdata.jl release GHF
```

The dry run checks every domain (all files present, all at the release tag) and lists
the packages. `release` then uploads the files of each grid to its package, checks
them (sha256), and writes the registry file of each domain. Requests that fail because
the server is busy are tried again after a wait. If it still stops, run it again: files
already uploaded are kept, and domains already released are skipped.

**4. Commit and push the registry**, which also updates the website:

```bash
git add registry && git commit -m "registry: GHF v2.0.0" && git push
```

At any point, `status` shows each domain: its local files and their version, its
packages on GitLab, and its registered release (and DOI):

```bash
julia fesmdata.jl status Topo
```

All commands take domains after the dataset to work on some only (e.g. `upload Topo
Antarctica`). `--allow-untagged` skips the release checks, e.g. for a test.
`delete Topo <version>` removes the packages of a version (e.g. of a test), after one
confirmation; registered releases are not deleted.

To test, use `--sandbox`: the packages are named `test_<Domain>_<Dataset>_<GRID>` and
the registry files go to `registry/_sandbox/`, which is not tracked (`fetch.jl
--sandbox` downloads from them). Delete the test packages afterwards:

```bash
julia fesmdata.jl release Topo Eurasia --sandbox --allow-untagged
julia fesmdata.jl delete Topo <version> Eurasia --sandbox
```

## Archive on Zenodo (optional)

A release on GitLab (with its registry) can be archived on Zenodo for a DOI, with the
same local files, after step 3:

```bash
julia fesmdata.jl archive upload Topo
julia fesmdata.jl archive publish Topo
git add registry && git commit -m "registry: Topo v2.0.1 on Zenodo" && git push
```

`archive upload` puts the files of each domain into a draft of the next version of its Zenodo
record (a new record the first time); running it again continues the drafts.
`archive publish` checks the drafts, lists them, publishes them after one confirmation
(publishing cannot be undone), and adds their DOIs to the registry. Drafts published
on the Zenodo website instead are added with `archive register Topo`. `archive status
Topo` shows the drafts and archived versions; `archive discard Topo` deletes the
unpublished drafts of a dataset, `archive drafts` lists all unpublished drafts of your
account, and `archive discard <id> ...`
deletes drafts by id. The drafts are recorded in `registry/_drafts/` (not tracked).
With `--sandbox`, the [Zenodo sandbox](https://sandbox.zenodo.org) archives the test
releases (`registry/_sandbox/`).

## Access

**GitLab (Helmholtz Codebase):** uploads need a token of the project: on
[fesmdata-products](https://codebase.helmholtz.cloud/fesmc/fesmdata-products),
Settings > Access tokens > Add new token, with the role Developer and the scope `api` (or a personal
token with the scope `api`, for a member of the project). SSH keys do not work for the
package registry. Downloads need no token. Store the token in `~/.gitlab_token` on the
machine with the files (read without being shown or kept in the shell history):

```bash
read -s -p "GitLab token: " t && printf '%s' "$t" > ~/.gitlab_token && chmod 600 ~/.gitlab_token && unset t && echo
```

**Zenodo** (only to archive): a personal token, on Zenodo, Account > Applications >
Personal access tokens > New token, with the scopes `deposit:write` and
`deposit:actions`, stored the same way in `~/.zenodo_token` (and the sandbox one in
`~/.zenodo_sandbox_token`). A new version of a Zenodo record can only be made by its
owner, or by those the owner gives access (the record > Share > "Can manage").

The machine environments (`../shared/machines/*.env`) set `GITLAB_TOKEN`,
`ZENODO_TOKEN` and `ZENODO_SANDBOX_TOKEN` from these files; a new machine needs the same
lines as there. Check with:

```bash
source shared/machines/levante.env && [ -n "$GITLAB_TOKEN" ] && echo "token set"
```

## Website

The website and its generated pages are described under
[Website and figures](https://fesmc.github.io/FesmData/website.html).
