# Machines and storage

The datasets are made on Levante (DKRZ), where the original datasets and the products
are; Albedo (AWI) holds a copy and can also run the pipelines. Users who only download
products need none of this (see [Download](https://fesmc.github.io/FesmData/download.html)).

## Environment files

Each machine has an environment file in this folder (`levante.env`, `albedo.env`,
`macbook.env`), sourced from the FesmData root before running anything:

```bash
source shared/machines/levante.env
```

It sets:

| Variable | Contents |
|---|---|
| `FESMDATA_MACHINE` | The name of the machine; the job scripts source `shared/machines/$FESMDATA_MACHINE.env` again on the compute node |
| `PATH`, `JULIAUP_CHANNEL` | Julia from juliaup, at the version of the pipelines (see below) |
| `FESMDATA`, `FESMDATA_SOURCES`, `FESMDATA_PREPARED`, `FESMDATA_PRODUCTS`, `FESMDATA_WORK` | The storage folders (see below) |
| `FESMDATA_V1` | The folder of the v1 products, which Topo step 5 compares with (optional) |
| `SBATCH_ACCOUNT`, `SBATCH_PARTITION`, `SBATCH_QOS` | The Slurm account, partition and QOS of the jobs |
| `GITLAB_TOKEN`, `ZENODO_TOKEN`, `ZENODO_SANDBOX_TOKEN` | The tokens for releases, read from files in the home folder (see [Access](https://fesmc.github.io/FesmData/releasing.html#access)) |

Each variable can be set before sourcing, and then keeps its value. A new machine is a
new file with the same variables.

## Julia

The pipelines use Julia 1.13.1, installed with juliaup:

```bash
curl -fsSL https://install.julialang.org | sh
juliaup add 1.13.1
```

The machine environment selects this version (`JULIAUP_CHANNEL`). Each pipeline has
its own environment (`Topo/`, `Regions/`, each source folder with a `prepare.jl`); install
its packages once, from the FesmData root after sourcing the machine environment (on
Levante on a login node, since compute nodes have no internet access):

```bash
julia --project=Topo -e 'using Pkg; Pkg.instantiate()'
julia --project=Regions -e 'using Pkg; Pkg.instantiate()'
```

`fesmdata.jl` installs the packages of `Remap/`, `Records/`, `Figures/` and `Publish/`
itself when a command needs them.

## Storage

All data lives in one folder, `$FESMDATA` (`fesmdata_dir` in `../provenance.jl`):

| Folder | Variable | Contents |
|---|---|---|
| `$FESMDATA/sources` | `FESMDATA_SOURCES` | Original datasets (`$datasets_dir` of `../../datamanifest.toml`) |
| `$FESMDATA/prepared` | `FESMDATA_PREPARED` | Prepared sources (`<source>/prepare.jl`), input of remapping and of the records datasets |
| `$FESMDATA/products` | `FESMDATA_PRODUCTS` | Products, as released: `<folder>/<GRID>/`, `Records/<Dataset>/` |
| `$FESMDATA/work` | `FESMDATA_WORK` | Intermediate files (Topo, Regions, ensemble members of Remap, plots) |

Each variable, if set, replaces the default folder. On a case-insensitive file system
(macOS, Windows), a folder `fesmdata` next to the FesmData checkout is the checkout
itself: choose another place.

| Machine | `FESMDATA` | `FESMDATA_WORK` |
|---|---|---|
| Levante | `/work/ba1442/fesmdata` | `/scratch/<u>/$USER/fesmdata` (deleted 14 days after the last access) |
| Albedo | `$FORCLIMA/fesmdata` | `/albedo/scratch/user/$USER/fesmdata` |
| Mac (`macbook.env`) | `$HOME/data/fesmdata` | `$FESMDATA/work` |

On the HPC machines the project folder is shared by the group, and the intermediate
files are per user on scratch, where they are deleted after a while without access (the
pipelines make them again).

The shared folders are writable by the group of the project through default ACLs,
which the files created in them inherit whatever the `umask`. To set them up on a new
machine, or to change who may write later (e.g. read-only products):

```bash
chmod -R g+w $FESMDATA && find $FESMDATA -type d -exec chmod g+s {} +
setfacl -R -m g::rwX -d -m g::rwX $FESMDATA
```

Each shared folder has a README for those who browse it, `$FESMDATA/README.md`, a copy of
[`FESMDATA_README.md`](https://github.com/fesmc/FesmData/blob/main/shared/machines/FESMDATA_README.md)
(copy it again when it changes, and on a new machine):

```bash
cp shared/machines/FESMDATA_README.md $FESMDATA/README.md
```

## Jobs

The pipelines run their steps as Slurm jobs on full compute nodes, with all cores as
Julia threads (`Topo/jobs/run_step.sbatch`, `Regions/jobs/run_step.sbatch`,
`Remap/jobs/remap_dataset.sbatch`), submitted from the FesmData root after sourcing the
machine environment, e.g.

```bash
sbatch --job-name=grids-ANT Topo/jobs/run_step.sbatch 01_grids.jl ANT
```

Logs go to `<Pipeline>/logs/`.
