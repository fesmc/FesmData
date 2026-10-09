#!/bin/bash
#SBATCH --job-name=regions
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=04:00:00
#SBATCH --output=Regions/logs/%x-%j.log
#
# Run one step of the regions pipeline on a full Levante compute node, using all of
# its cores as Julia threads. Submit from the FesmData root:
#
#     source Topo/machines/levante.env
#     sbatch --job-name=regions-NH Regions/jobs/run_step.sbatch 01_regions.jl NH
#
set -euo pipefail
source Topo/machines/levante.env
export JULIA_NUM_THREADS=$(nproc)

echo "$(date)  host=$(hostname)  threads=$JULIA_NUM_THREADS  step: $*"
julia --project=Regions Regions/scripts/"$@"
echo "$(date)  done"
