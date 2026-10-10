#!/bin/bash
#SBATCH --job-name=remap
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=08:00:00
#SBATCH --output=Remap/logs/%x-%j.log
#
# Make a thematic dataset on a full Levante compute node (all cores as Julia threads):
# prepare its sources not prepared yet, then remap its products onto their grids.
# Submit from the FesmData root, with the arguments of `fesmdata.jl remap <Dataset>`:
#
#     source shared/machines/levante.env
#     sbatch --job-name=remap-GHF Remap/jobs/remap_dataset.sbatch GHF
#
set -euo pipefail
source shared/machines/levante.env
module load cdo                      # used by some prepare.jl (e.g. Hersbach2020_era5)
export JULIA_NUM_THREADS=$(nproc)

echo "$(date)  host=$(hostname)  threads=$JULIA_NUM_THREADS  remap $*"
julia fesmdata.jl remap "$@"
echo "$(date)  done"
