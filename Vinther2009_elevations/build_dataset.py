import xarray as xr
import numpy as np
import pandas as pd

# ---------------------------------------
# paths
# ---------------------------------------
# Elevation data from Vinther et al. (2009)
vinther = pd.read_csv("/p/projects/megarun/luciagu/data/vinther2009/elevation.csv")
u1 = 40
u2 = 65

# Build dataset 
ice_core_ids = ["camp_century" ,"ngrip", "grip",  "dye3"]

err = np.zeros(np.array(vinther)[:,1:5].shape)
err[:, 0] = u2  
err[:, 3] = u2 
err[:, 1] = u1  
err[:, 2] = u1  

z = np.array(vinther)[:,1:5]
z[:,0]=z[:,0]+1890
z[:,1]=z[:,1]+2920
z[:,2]=z[:,2]+3230
z[:,3]=z[:,3]+2490

ds_vinther = xr.Dataset(
    data_vars={
        "z_srf": (("time", "ice_core"), z),
        "error": (("time", "ice_core"), err)
    },
    coords={
        "time": (-np.array(vinther)[:,0]),
        "ice_core": ice_core_ids
    })

ds_vinther = ds_vinther.sortby("time")
ds_vinther.to_netcdf("./vinther2009.nc")