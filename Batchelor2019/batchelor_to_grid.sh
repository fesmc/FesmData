#!/bin/bash

domain=North
grid_name_src=NH-lonlat-0.5deg
grid_name_tgt=NH-32KM
nc_src=Batchelor2019_ice_masks.nc 

# Generate source grid file, make sure to set grid type to latlon
cdo griddes Batchelor2019_ice_masks.nc > grid_NH-lonlat-0.5deg.txt
sed -i -e 's/generic/latlon/g' grid_NH-lonlat-0.5deg.txt
rm grid_NH-lonlat-0.5deg.txt-e

# Generate mapping weights
cdo gencon,../maps/grid_${grid_name_tgt}.txt -setgrid,grid_${grid_name_src}.txt ${nc_src} scrip-con_${grid_name_src}_${grid_name_tgt}.nc

# Perform remapping
nc_out=${grid_name_tgt}_${nc_src}
cdo remap,grid_${grid_name_tgt}.txt,scrip-con_${grid_name_src}_${grid_name_tgt}.nc ${nc_src} ${nc_out}
