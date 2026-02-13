# NAHosMIP freshwater hosing

## Source

Jackson et al. (2022) create a mask for freshwater hosing along the Greenland coast. They provide a python script for creating this mask on a high resolution grid.
Their code and example outputs are provided here:

[https://zenodo.org/records/7225014](https://zenodo.org/records/7225014)

Original reference:

[https://gmd.copernicus.org/articles/16/1975/2023/gmd-16-1975-2023.html](https://gmd.copernicus.org/articles/16/1975/2023/gmd-16-1975-2023.html)

## Processing steps

1. Download `create_hosing_GC3LL_grl_v2.py` from the zenodo repository and get the grid file from their model `mesh_mask_HighresMIP_eORCA1_extr.nc`

2. Run the python code (it worked well using python version 3.12), to produge a hosing map around Greenland with a total freshwater magnitude that can be set in the code. Created output file: `mask_gl_0.3Sv.nc`

3. The created file sets missing values to >1e30. This is changed using cdo:
```bash
cdo expr,'hosing = (hosing > 1e30) ? 0 : hosing' mask_gl_0.3Sv.nc mask_gl_0.3Sv_corr.nc
```

4. As cdo remapcon doesnt work directly, remap first to a high resolution latlon grid, afterwards do conservative regridding to the ClimberX grid
```bash
cdo remapnn,grid_lonlat-0.5deg.txt mask_gl_0.3Sv_corr.nc mask_gl_remapnn_highres_latlon_0.3Sv.nc
cdo remapcon,grid_GEO-5x5.txt mask_gl_remapnn_highres_latlon_0.3Sv.nc mask_hosing_gl_remapcon_0.3Sv.nc
```

5. `create_gl_mask.jl` : Julia script used for plotting the mask on different grids (optional) and data is normalized and saved in `mask_greenland_fw_distribution.nc`. This is the final mask which is copied to climber-x/input 


## Additional script to create hosing-rate files

`create_hosing_rate_ts.jl` : Julia function to create linear time series of freshwater hosing that can be used as input for ClimberX when doing fw hosing experiments. 
Example output file as used for TIPMIP experiment A: `hos_rate_0.3_tipmip-ocn-p1t1-Acd.nc`



