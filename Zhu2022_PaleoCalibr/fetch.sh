#!/bin/bash
# Fetch the CESM2 PaleoCalibr files used by prepare.jl and prepare_ocean.jl from NCAR GDEX
# d583116 (open download) into $PALEOCALIBR_DIR (default: the AWI pool's PaleoCalibr folder on
# Albedo): the LGM (21ka) and preindustrial (PI) cases, years 401-500 (chunks 040101-045012 and
# 045101-050012).
#   CAM (cam.h0): TREFHT, PRECC, PRECL, PHIS, LANDFRAC, whole (~0.4 GB)
#   POP (pop.h):  IFRAC, MOC, whole (~0.9 GB)
#   POP TEMP:     7.4 GB per file, downloaded to $SCRATCH_DIR and cut with NCO, then deleted:
#                 TEMP_top (top level, 5 m, of years 401-500, no level dimension) and
#                 TEMP_0-2200m (levels down to 2200 m of years 471-500) (~10 GB)
# Files already present are skipped. Needs wget and NCO (ncks, ncwa, nccopy).
#
# Usage (on Albedo: module load nco):
#     bash Zhu2022_PaleoCalibr/fetch.sh
set -euo pipefail

DIR=${PALEOCALIBR_DIR:-/albedo/work/projects/p_pool_clim_data/PaleoCalibr}
SCRATCH_DIR=${SCRATCH_DIR:-/albedo/scratch/user/$USER/paleocalibr-temp}
URL=https://osdf-director.osg-htc.org/ncar/gdex/d583116
CASES="b.e21.B1850.f19_g17.PaleoCalibr.21ka.02 b.e21.B1850.f19_g17.PaleoCalibr.PI.02"
CHUNKS="040101-045012 045101-050012"

mkdir -p "$DIR"
get() {   # get <file>: download into $DIR unless present
    if [ ! -s "$DIR/$1" ]; then
        wget -q --show-progress -O "$DIR/$1.part" "$URL/$1"
        mv "$DIR/$1.part" "$DIR/$1"
    fi
}

for case in $CASES; do
    for chunk in $CHUNKS; do
        for var in TREFHT PRECC PRECL PHIS LANDFRAC; do get "$case.cam.h0.$var.$chunk.nc"; done
        for var in IFRAC MOC; do get "$case.pop.h.$var.$chunk.nc"; done
    done

    # TEMP: subsets of the full files (netCDF-3 subsets, then compressed)
    need=0
    for chunk in $CHUNKS; do [ -s "$DIR/$case.pop.h.TEMP_top.$chunk.nc" ] || need=1; done
    [ -s "$DIR/$case.pop.h.TEMP_0-2200m.047101-050012.nc" ] || need=1
    [ $need = 1 ] || continue
    mkdir -p "$SCRATCH_DIR"
    for chunk in $CHUNKS; do
        full=$SCRATCH_DIR/$case.pop.h.TEMP.$chunk.nc
        top=$DIR/$case.pop.h.TEMP_top.$chunk.nc
        deep=$DIR/$case.pop.h.TEMP_0-2200m.047101-050012.nc
        [ -s "$top" ] && { [ $chunk != 045101-050012 ] || [ -s "$deep" ]; } && continue
        [ -s "$full" ] || wget -q --show-progress -O "$full" "$URL/$case.pop.h.TEMP.$chunk.nc"
        if [ ! -s "$top" ]; then
            ncks -O -6 -v TEMP -d z_t,0,0 "$full" "$SCRATCH_DIR/top.nc"
            ncwa -O -6 -a z_t "$SCRATCH_DIR/top.nc" "$SCRATCH_DIR/top2.nc"
            nccopy -d 1 "$SCRATCH_DIR/top2.nc" "$top"
        fi
        if [ $chunk = 045101-050012 ] && [ ! -s "$deep" ]; then      # years 471-500: months 240-599
            ncks -O -6 -v TEMP -d z_t,0.,220000. -d time,240,599 "$full" "$SCRATCH_DIR/deep.nc"
            nccopy -d 1 "$SCRATCH_DIR/deep.nc" "$deep"
        fi
        rm -f "$full" "$SCRATCH_DIR/top.nc" "$SCRATCH_DIR/top2.nc" "$SCRATCH_DIR/deep.nc"
    done
done
echo "PaleoCalibr files in $DIR"
