#!/bin/bash
#
# Submit the steps of the regions pipeline for one domain as a chain of jobs, each
# starting when the previous step has succeeded. Needs the topography product of the
# domain (Topo, step 3). Run from the FesmData root after sourcing the machine
# environment:
#
#     Regions/jobs/submit_domain.sh DOMAIN [FIRST_STEP]
#
# FIRST_STEP (1-5, default 1) skips the earlier steps.
#
set -euo pipefail
domain=$1
first=${2:-1}
run=Regions/jobs/run_step.sbatch

dep=""
submit() {  # submit NAME TIME SCRIPT ARGS...; prints the job id
    sbatch --parsable $dep --job-name="$1" --time="$2" $run "${@:3}"
}

if [ "$first" -le 1 ]; then
    id=$(submit "regions-$domain" 01:00:00 01_regions.jl "$domain"); dep="--dependency=afterok:$id"
fi
if [ "$first" -le 2 ]; then
    id=$(submit "zone-$domain" 00:30:00 02_zone.jl "$domain"); dep="--dependency=afterok:$id"
fi
if [ "$first" -le 3 ]; then
    id=$(submit "basins-$domain" 01:00:00 03_basins.jl "$domain"); dep="--dependency=afterok:$id"
fi
if [ "$first" -le 4 ]; then
    id=$(submit "grids-all-$domain" 01:00:00 04_grids.jl "$domain"); dep="--dependency=afterok:$id"
fi
if [ "$first" -le 5 ]; then
    id=$(submit "plots-$domain" 00:30:00 05_plots.jl "$domain")
fi
squeue -u "$USER" -o "%.10i %.28j %.10T %.12r"
