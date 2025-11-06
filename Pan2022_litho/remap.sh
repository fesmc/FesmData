# Perform remapping using cdo by defining the source and target grid_name values,
# as well as the source file infile and the target file outfile. This script
# assumes that the scrip map weights have already been generated, e.g. using genmap.sh.

# ./remap.sh lonlat-0.5deg LIS-32KM isostasy_data/earth_structure/lithothickness/pan2022.nc LIS-32KM_GEO_P22.nc

mapfldr=../maps

grid_name_src=$1
grid_name_tgt=$2
infile=$3
outfile=$4

# To perform remapping using the weights file
cdo remap,${mapfldr}/grid_${grid_name_tgt}.txt,scrip-con_${grid_name_src}_${grid_name_tgt}.nc ${infile} ${outfile}

# Add attributes with reference
ncatted -O -h -a reference,global,o,c,\
"Pan et al., The influence of lateral Earth structure on inferences of global ice volume during the Last Glacial Maximum, Quarternary Science Reviews, doi:10.1016/j.quascirev.2022.107644, 2022." \
${outfile}
