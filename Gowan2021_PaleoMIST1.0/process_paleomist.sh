#!/bin/bash

variables_folders=("deform" "thickness" "topo")

for region_dir in */; do
    region=${region_dir%/}
    echo "--------------------------------------------------"
    echo "Region: $region"
    echo "--------------------------------------------------"
    
    cd "$region" || continue

    processed_files=()
    for var in "${variables_folders[@]}"; do
        if [ -d "$var" ]; then
            echo "  -> Var: $var"
            cd "$var"
            for year_file in $(ls [0-9]*.nc | sort -n); do
                year=$(basename "$year_file" .nc)
                cdo -s settaxis,${year}-01-01,00:00:00,1year "$year_file" "tmp_${year}.nc"
            done
            
            cdo -s -chname,z,"$var" -mergetime tmp_*.nc "../${var}_series.nc"
            
            rm tmp_*.nc
            cd ..
            processed_files+=("${var}_series.nc")
        fi
    done

    if [ ${#processed_files[@]} -gt 0 ]; then
        echo "  -> Merging vars ${region}_paleomist.nc"
        cdo -s -merge "${processed_files[@]}" "${region}_paleomist.nc"
        rm "${processed_files[@]}"
    fi

    cd ..
done
