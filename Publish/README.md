# Publish: releases of the processed products

All commands go through `fesmdata.jl` at the root of FesmData: `julia fesmdata.jl
help` lists them. Finding and downloading (`list`, `fetch`) needs only Julia; the
release commands install the packages of `Publish/` themselves when needed.

The processed products of the v2 pipelines (Topo, Regions, ...) are released on the
package registry of the GitLab project
[fesmc/fesmdata-products](https://gitlab.dkrz.de/fesmc/fesmdata-products/-/packages)
(DKRZ), and listed on the [website](https://fesmc.github.io/FesmData/). A release of a
dataset (tag `<dataset>-vX.Y.Z`, e.g. `topo-v2.0.0`) has one record per domain, and
one package per domain, dataset and grid, e.g. `Antarctica_Topo_ANT-32KM` version
`2.0.0`, with the files of that grid (grid description, grid file and products).
Domains are named by their output folder (`folder` in `../shared/domains.toml`):
Antarctica, GreenlandPaleo (GRL-PAL), Greenland (GRL), North (NH), Laurentide (LIS),
Eurasia (EIS).

A release can also be archived on [Zenodo](https://zenodo.org/communities/fesmc), in
the `fesmc` community, for a DOI: one Zenodo record per dataset and domain, with a DOI
per version.

## Registry

Every record has a registry file, `../registry/<Domain>/<Dataset>.toml`, with the
release (`[_RELEASE]`: version, tag, date, link to the packages), its DOIs if archived
on Zenodo (`[_ZENODO]`), and one entry per file:

```toml
["ANT-4KM_TOPO-Bedmap3.nc"]
uri = "https://gitlab.dkrz.de/api/v4/projects/142484/packages/generic/Antarctica_Topo_ANT-4KM/2.0.0/ANT-4KM_TOPO-Bedmap3.nc"
checksum = "sha256:<hex>"
size = 123456789
storage_path = "$datasets_dir/Antarctica/ANT-4KM/ANT-4KM_TOPO-Bedmap3.nc"
```

`$datasets_dir` stands for `$ICE_DATA/v2`, so the files land in the usual layout,
`$ICE_DATA/v2/<Domain>/<GRID>/`. The registry files are also
[DataManifest.jl](https://github.com/awi-esc/DataManifest.jl) databases.

## Download

With Julia (it needs no packages) and `ICE_DATA` set (e.g. `source
shared/machines/<machine>.env`), from the FesmData
root:

```bash
julia fesmdata.jl list                                     # all records
julia fesmdata.jl list Topo                                # the records of a dataset (or a domain)
julia fesmdata.jl list Antarctica Topo                     # a record: grids, files, sizes, local files
julia fesmdata.jl fetch Antarctica Topo                    # download all grids
julia fesmdata.jl fetch Antarctica Topo ANT-8KM ANT-16KM   # some grids
```

Files already present are kept if their checksum matches the registry. A file that
differs (another version, or changed locally) stops the download, unless
`--overwrite` is given. Single files can also be downloaded from the website or the
packages page, without a token.

## Release

The datasets, the GitLab project and the Zenodo metadata (creators, licence,
community) are set in `datasets.toml`. The files of a release on each grid are defined
by the pipeline of the dataset (`topo_release_files` in `../Topo/files.jl`: all
products of the domain, default and variants; `regions_release_files` in
`../Regions/files.jl`), and must all be present. A release of a dataset (here Topo,
version 2.0.1) on Levante, where the files are, needs a GitLab token (see Access
below) and takes four steps.

**1. Tag the release** (from any checkout, after the changes are on main):

```bash
git fetch origin
git tag -a topo-v2.0.1 -m "Topo v2.0.1" origin/main
git push origin topo-v2.0.1
```

**2. Run the pipeline at the tag**, in a clean checkout of it next to the usual one, so
that every file gets `fesmdata_version = "topo-v2.0.1"` (uncommitted changes would make
it `-dirty`). For Topo, all steps and all products of the three domains:

```bash
git worktree add ../FesmData-topo-v2.0.1 topo-v2.0.1
cd ../FesmData-topo-v2.0.1
source shared/machines/levante.env
julia --project=Topo -e 'using Pkg; Pkg.instantiate()'
for d in ANT GRL-PAL NH; do Topo/jobs/submit_domain.sh $d 1 all; done
```

**3. Upload**, once the jobs have finished, from the usual checkout on main:

```bash
cd ../FesmData && git pull
source shared/machines/levante.env
julia fesmdata.jl release Topo --dry-run
julia fesmdata.jl release Topo
```

The dry run checks every domain (all files present, all at the release tag) and lists
the packages. `release` then uploads the files of each grid to its package, checks
them (sha256), and writes the registry file of each domain. Requests that fail because
the server is busy are tried again after a wait. If it still stops, run it again: files
already uploaded are kept, and domains already released are skipped.

**4. Commit and push the registry**, which also updates the website:

```bash
git add registry && git commit -m "registry: Topo v2.0.1" && git push
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

**GitLab:** uploads need a token of the project: on
[fesmdata-products](https://gitlab.dkrz.de/fesmc/fesmdata-products), Settings > Access
tokens > Add new token, with the role Developer and the scope `api` (or a personal
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

The website (GitHub Pages) lists the datasets of `datasets.toml` and the records,
grids and files of the registry, with download links. It is built by
`.github/workflows/site.yml` on every push to main that changes the registry or
Publish. To build it locally:

```bash
julia fesmdata.jl site _site
```
