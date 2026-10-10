#!/bin/bash
#SBATCH --job-name=era5-prepare
#SBATCH --partition=shared
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --output=Hersbach2020_era5/prepare-%j.log
#
# Run Hersbach2020_era5/prepare.jl on Levante (shared partition, 16 cores: up to 16 cdo
# processes, reading ~150 GB of GRIB from the DKRZ ERA5 pool). Submit from the FesmData root:
#
#     source shared/machines/levante.env
#     sbatch Hersbach2020_era5/prepare.sbatch
#
set -euo pipefail
source shared/machines/levante.env
module load cdo

echo "$(date)  host=$(hostname)  $(cdo -V 2>&1 | head -1)"
julia --project=Hersbach2020_era5 Hersbach2020_era5/prepare.jl
echo "$(date)  done"
