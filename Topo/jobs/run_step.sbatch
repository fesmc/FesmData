#!/bin/bash
#SBATCH --job-name=topo
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --time=04:00:00
#SBATCH --output=Topo/logs/%x-%j.log
#
# Run one step of the topography pipeline on a full Levante compute node, using
# all of its cores as Julia threads. Submit from the FesmData root:
#
#     source Topo/machines/levante.env
#     sbatch --job-name=grids-ANT Topo/jobs/run_step.sbatch 01_grids.jl ANT
#
set -euo pipefail
source Topo/machines/levante.env
export JULIA_NUM_THREADS=$(nproc)

echo "$(date)  host=$(hostname)  threads=$JULIA_NUM_THREADS  step: $*"
julia --project=Topo Topo/scripts/"$@"
echo "$(date)  done"
