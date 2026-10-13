#!/bin/bash
#SBATCH --job-name=remap
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=0
#SBATCH --time=08:00:00
#SBATCH --output=Remap/logs/%x-%j.log
#
# Make a thematic dataset (all allocated cores as Julia threads): prepare its sources
# not prepared yet, then remap its products onto their grids. Submit from the FesmData
# root, with the arguments of `fesmdata.jl remap <Dataset>`. By default on a full
# compute node (partition and account from the machine environment):
#
#     source shared/machines/<machine>.env
#     sbatch --job-name=remap-GHF Remap/jobs/remap_dataset.sbatch GHF
#
# On Levante, small datasets on part of a node of the shared partition (at most 940 MB
# per core), which usually starts sooner:
#
#     sbatch --job-name=remap-Sediment -p shared -c 64 --mem=58G -t 02:00:00 Remap/jobs/remap_dataset.sbatch Sediment
#
set -euo pipefail
source shared/machines/$FESMDATA_MACHINE.env
module load cdo                      # used by some prepare.jl (e.g. Hersbach2020_era5)
export JULIA_NUM_THREADS=$(nproc)

echo "$(date)  host=$(hostname)  threads=$JULIA_NUM_THREADS  remap $*"
julia fesmdata.jl remap "$@"
echo "$(date)  done"
