# TARGET grid name
grid_name_tgt=${1}   # e.g., LIS-32KM

# General information
mapfldr=../maps

# Source data location and name to call it
grid_name_src="Gowan2019_EPSG:3979"
nc_src=Gowan2019_Sediments.nc
name_src="SED-G19"

# Output filename to be produced
outfile=${grid_name_tgt}_${name_src}.nc

# Generate the weights file
cdo gencon,${mapfldr}/grid_${grid_name_tgt}.txt -setgrid,${mapfldr}/grid_${grid_name_src}.txt ${nc_src} scrip-con_${grid_name_src}_${grid_name_tgt}.nc

# Perform remapping using the weights file
cdo remap,${mapfldr}/grid_${grid_name_tgt}.txt,scrip-con_${grid_name_src}_${grid_name_tgt}.nc ${nc_src} ${outfile}

