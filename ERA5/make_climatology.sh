#!/usr/bin/env bash
# Collapse the downloaded 1991-2020 monthly means (360 timesteps per file) to a
# 12-month climatology (one mean per calendar month) using `cdo ymonmean`.
#
# Writes *_clim.nc alongside each source file. Idempotent: skips files whose
# climatology already exists. Run after download_era5.py.
#
# Usage:
#   ./make_climatology.sh                 # both dataset subdirs
#   ./make_climatology.sh <dir> [<dir>..] # explicit directories

set -euo pipefail

ERA5_ROOT="${ERA5_ROOT:-$HOME/data/era5}"

if [[ $# -gt 0 ]]; then
    DIRS=("$@")
else
    DIRS=("$ERA5_ROOT/monthly-pressure-levels" "$ERA5_ROOT/monthly-single-levels")
fi

for dir in "${DIRS[@]}"; do
    [[ -d "$dir" ]] || { echo "skip (no dir): $dir"; continue; }
    for f in "$dir"/era5_*_1991-2020.nc; do
        [[ -e "$f" ]] || continue
        case "$f" in *_clim.nc) continue;; esac   # don't reprocess outputs
        out="${f%.nc}_clim.nc"
        if [[ -e "$out" ]]; then
            echo "skip (exists): $out"
            continue
        fi
        echo "ymonmean: $(basename "$f") -> $(basename "$out")"
        cdo ymonmean "$f" "$out"
    done
done

echo "Done."
