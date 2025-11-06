domain=Laurentide
grid_name_src=lonlat-0.5deg
grid_name_tgt=LIS-32KM

nc_src=pan2022.nc

cdo gencon,grid_${grid_name_tgt}.txt -setgrid,grid_${grid_name_src}.txt ${nc_src} scrip-con_${grid_name_src}_${grid_name_tgt}.nc


