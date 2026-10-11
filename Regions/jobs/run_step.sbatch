#!/bin/bash
#SBATCH --job-name=regions
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=0
#SBATCH --time=04:00:00
#SBATCH --output=Regions/logs/%x-%j.log
#
# Run one step of the regions pipeline on Levante, using all allocated cores as Julia
# threads. Submit from the FesmData root; by default on a full compute node (the
# compute partition allocates whole nodes):
#
#     source shared/machines/levante.env
#     sbatch --job-name=regions-NH Regions/jobs/run_step.sbatch 01_regions.jl NH
#
# or on part of a node of the shared partition (at most 940 MB per core), e.g.
#
#     sbatch --job-name=basins-ANT -p shared -c 128 --mem=116G Regions/jobs/run_step.sbatch 03_basins.jl ANT Schmidt2025
#
set -euo pipefail
source shared/machines/levante.env
export JULIA_NUM_THREADS=$(nproc)

echo "$(date)  host=$(hostname)  threads=$JULIA_NUM_THREADS  step: $*"
julia --project=Regions Regions/scripts/"$@"
echo "$(date)  done"
