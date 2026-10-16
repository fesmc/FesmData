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
version `2.0.0`, with the products of that grid new or changed in that release. A file
unchanged since an earlier release stays in the package of the release it was first
uploaded at (`2.0.0`), so that a release uploads, and `fetch` downloads, only what is
new. The grid files of each grid (grid description and grid file) are released once, in
the dataset Grids (`Antarctica_Grids_ANT-32KM`), for all datasets on the grid; `fetch`
gets them with the products.
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
`$FESMDATA_PRODUCTS/<Domain>/<GRID>/`. The `uri` of a file unchanged since an earlier
release is that of the package where it was uploaded (e.g. `2.0.0` in the registry of
release `2.1.0`). A file that changed since an earlier release also has
`previous_checksums`, the checksums of its earlier releases, so that copies of those
are updated. The registry files are also
[DataManifest.jl](https://github.com/awi-esc/DataManifest.jl) databases.

## Download

Finding and downloading the products (`list`, `fetch`, `mirror`) is described on the
[Download](https://fesmc.github.io/FesmData/download.html) page.

## Release

The datasets, the GitLab project and the Zenodo metadata (creators, licence,
community) are set in `datasets.toml`. The files of a release on each grid are defined
by the pipeline of the dataset (`topo_release_files` in `../Topo/files.jl`: all
products of the domain, default and variants; `regions_release_files` in
`../Regions/files.jl`; the grid files of the grids with products of any dataset for
Grids, `grids_files` in `release.jl`), and must all be present. A release of a dataset
(here GHF, version 2.0.0) is made on Levante, where the files are, from the files as
they were made and checked, and needs a GitLab token (see Access below). It takes four
steps. The grid files of its grids must be released in Grids, as they are locally
(checksums): when grid files are written again (Topo step 1) or a dataset is released
on new grids, release Grids first, the same way.

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

`stamp` sets `fesmdata_version` of every file new or changed since the earlier release
to the tag, in place (only the global attributes change). The files unchanged since then
(the checksum of their entry in the registry, which must therefore be committed) keep
the version they were released at, and are not uploaded or downloaded again. `fesmdata_commit` stays the commit that made the
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

The release is that of the newest tag of the dataset. The dry run checks every domain
(all files present, the new and changed files at the release tag, the unchanged ones at
an earlier tag) and lists the files to upload by package. `release` then uploads the new
and changed files of each grid to its package, checks them (sha256), and writes the
registry file of each domain, with the entries of the unchanged files kept. A domain
without new or changed files gets only its registry, at the version of the release. Requests that fail because
the server is busy are tried again after a wait. If it still stops, run it again: files
already uploaded are kept, and domains already released are skipped.

**4. Commit and push the registry**, which also updates the website:

```bash
git add registry && git commit -m "registry: GHF v2.0.0" && git push
```

**5. Clean up** the files the release replaced, once the release is out (and mirrored,
`fesmdata.jl mirror`, on the other machines): products no longer made (e.g. copies on a
crop that now gets them by cropping, grids dropped by the resolution rule) stay in
`$FESMDATA_PRODUCTS` until pruned, and the files of earlier releases that were replaced
stay on the packages page until deleted:

```bash
julia fesmdata.jl prune               # or: prune <Dataset> [<Domain>]
julia fesmdata.jl delete GHF          # files of the packages no release refers to
```

`prune` lists the files that no record of the registry refers to, by domain and dataset
with their size, and deletes them after one confirmation (`--yes`: none), writing their
list to `$FESMDATA_WORK/prune-<date>.txt`. It keeps the products by cropping (files with
a `cropped_from` attribute, made by `fetch` and `mirror`), the products not released
(`release = false` in `<Dataset>/remap.toml`, e.g. SolidEarth Pan2022), the grid files
of grids still in use, and the records (`Records/`). Run it on every machine with a copy
(Levante, Albedo), after `mirror` there.

`delete <Dataset>` lists the files of the packages of the dataset, all versions, that
no entry of the registry refers to, and deletes them after one confirmation, with the
packages left without files. It reads the registry of the checkout, so it only cleans
the packages of versions up to the registered release of each domain: those of a later
version (an upload not finished, or a release not yet pulled) and of domains without a
registry are kept, and can be deleted by version.

At any point, `status` shows each domain: its local files and their version, its
packages on GitLab, and its registered release (and DOI):

```bash
julia fesmdata.jl status Topo
```

All commands take domains after the dataset to work on some only (e.g. `upload Topo
Antarctica`). `--allow-untagged` skips the release checks, e.g. for a test.
`delete Topo <version>` removes the packages of a version (e.g. of a test, or of a
domain no longer released), after one confirmation; packages with files of the registry
are not deleted.

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
