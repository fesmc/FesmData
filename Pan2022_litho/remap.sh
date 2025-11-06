# General information
mapfldr=../maps

# Source data location and name to call it
grid_name_src=lonlat-0.5deg
nc_src=isostasy_data/earth_structure/lithothickness/pan2022.nc
name_src="GEO-P22"

# TARGET domain and grid name
domain_tgt=Laurentide
grid_name_tgt=LIS-16KM

# Output filename to be produced
outfile=${grid_name_tgt}_${name_src}.nc

# Generate the weights file
cdo gencon,${mapfldr}/grid_${grid_name_tgt}.txt -setgrid,${mapfldr}/grid_${grid_name_src}.txt ${nc_src} scrip-con_${grid_name_src}_${grid_name_tgt}.nc

# Perform remapping using the weights file
cdo remap,${mapfldr}/grid_${grid_name_tgt}.txt,scrip-con_${grid_name_src}_${grid_name_tgt}.nc ${nc_src} ${outfile}

# Add attributes with reference information
ncatted -O -h -a reference,global,o,c,\
"Pan et al., The influence of lateral Earth structure on inferences of global ice volume during the Last Glacial Maximum, Quarternary Science Reviews, doi:10.1016/j.quascirev.2022.107644, 2022." \
${outfile}
