mapfldr=../maps
grid_name_src=lonlat-0.5deg

domain_tgt=Laurentide
grid_name_tgt=LIS-16KM

nc_src=isostasy_data/earth_structure/lithothickness/pan2022.nc

cdo gencon,${mapfldr}/grid_${grid_name_tgt}.txt -setgrid,${mapfldr}/grid_${grid_name_src}.txt ${nc_src} scrip-con_${grid_name_src}_${grid_name_tgt}.nc


