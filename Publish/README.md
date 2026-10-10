# Publish: processed products on Zenodo

The processed products of the v2 pipelines (Topo, Regions, ...) are published on
[Zenodo](https://zenodo.org/communities/fesmc), in the `fesmc` community, with one
record per dataset and domain (e.g. Antarctica / Topo). Domains are named by their
output folder (`folder` in `../shared/domains.toml`): Antarctica, GreenlandPaleo
(GRL-PAL), Greenland (GRL), North (NH), Laurentide (LIS), Eurasia (EIS). A record holds
all grids of its domain, from the base grid to 32 km, with their grid files. Each release of a
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

The datasets and the record metadata (creators, licence, community, description) are
set in `datasets.toml`. The files of a release on each grid are defined by the pipeline
of the dataset (`topo_release_files` in `../Topo/files.jl`: all products of the domain,
default and variants; `regions_release_files` in `../Regions/files.jl`), and must all be
present. A release of a dataset (here Topo, version 2.0.1) on Levante, where the files
are, needs a Zenodo token (see Zenodo access below) and takes five steps.

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
julia --project=Publish -e 'using Pkg; Pkg.instantiate()'
julia --project=Publish Publish/scripts/zenodo.jl upload Topo --dry-run
julia --project=Publish Publish/scripts/zenodo.jl upload Topo
```

The dry run checks every domain: all files present, all at the release tag. `upload`
then puts the files of each domain into a draft of the next version of its record (a
new record the first time); files unchanged on Zenodo are kept. Requests that fail
because Zenodo is busy are tried again after a wait (up to about 7 min). If it still
stops, run it again: it continues the same drafts, also those of an upload from
another checkout (found by their title).

**4. Publish** the drafts and register them:

```bash
julia --project=Publish Publish/scripts/zenodo.jl publish Topo
```

`publish` checks each draft (its files are the local files of the release), lists
them, and publishes them all after one confirmation; publishing cannot be undone. The
drafts can also be looked at first on https://zenodo.org/me/uploads. It then registers
the records: it writes `registry/<Domain>/Topo.toml` for each. (Drafts published on
the website instead are registered with `register Topo`, which skips drafts not
published yet.)

**5. Commit and push the registry**, which also updates the website:

```bash
git add registry && git commit -m "registry: Topo v2.0.1" && git push
```

At any point, `status` shows each domain: its local files and their version, its draft
(and whether it is published), and its registered version:

```bash
julia --project=Publish Publish/scripts/zenodo.jl status Topo
```

All commands take domains after the dataset to work on some only (e.g. `upload Topo
Antarctica`). `--allow-untagged` skips the release checks, e.g. for a test. The drafts
of `upload` are recorded in `registry/_drafts/` (local, not tracked) until they are
registered.

To start over, `discard Topo` deletes the unpublished drafts of a dataset on Zenodo.
`drafts` lists all unpublished drafts of your account, and `discard <id> ...` deletes
drafts by id (e.g. left over from an interrupted upload). Published records are never
deleted.

## Zenodo access

Uploads need a Zenodo account and a personal token: on Zenodo, Account > Applications >
Personal access tokens > New token, with the scopes `deposit:write` and
`deposit:actions`. Store it in `~/.zenodo_token` on the machine with the files (it is
read without being shown or kept in the shell history):

```bash
read -s -p "Zenodo token: " t && printf '%s' "$t" > ~/.zenodo_token && chmod 600 ~/.zenodo_token && unset t && echo
```

The machine environments (`../shared/machines/*.env`) set `ZENODO_TOKEN` from this
file; a new machine needs the same two lines as there. Check with:

```bash
source shared/machines/levante.env && [ -n "$ZENODO_TOKEN" ] && echo "token set"
```

A new version of a record can only be made by the owner of the record, or by those the
owner gives access to it (on Zenodo, the record > Share > "Can manage"). To publish an
update of a dataset, ask the owner of its record (see the registry) for this access.
New records are owned by whoever uploads them and join the `fesmc` community.

To test, use [the sandbox](https://sandbox.zenodo.org) with `--sandbox`: it has its own
accounts and tokens (stored in `~/.zenodo_sandbox_token` the same way). Its registry
files go to `registry/_sandbox/`, which is not tracked, and `fetch.jl --sandbox`
downloads from them.

## Website

The website (GitHub Pages) lists the datasets of `datasets.toml` and the records,
grids and files of the registry, with download links. It is built by
`.github/workflows/site.yml` on every push to main that changes the registry or
Publish. To build it locally:

```bash
julia --project=Publish Publish/scripts/site.jl _site
```
