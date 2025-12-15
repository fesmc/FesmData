import xarray as xr
import numpy as np
import pandas as pd
from scipy.interpolate import griddata


# ----------------------------------------------------
#  Paths
# ----------------------------------------------------

age = xr.open_dataset("./isochrone_buffers/PaleoGrIS_1.0_isochrone_buffers_2km_age.nc")
err = xr.open_dataset("./isochrone_buffers/PaleoGrIS_1.0_isochrone_buffers_2km_error.nc")
grid=xr.open_dataset("../../ice_data/Greenland/GRL-8KM/GRL-8KM_TOPO-M17.nc")

# m --> km
age['x']=age.x*1e-3
age['y']=age.y*1e-3
err['x']=err.x*1e-3
err['y']=err.y*1e-3

def regrid_iso(ds, ds_target,var_name,method):
    X, Y = np.meshgrid(ds.x.values, ds.y.values)
    Xc, Yc = np.meshgrid(ds_target.xc.values, ds_target.yc.values)

    isochrone_interp = griddata(
        points=(X.ravel(), Y.ravel()),
        values=ds[var_name].values.ravel(),
        xi=(Xc, Yc),
        method=method
    )

    ds_new = xr.DataArray(
        isochrone_interp,
        coords={'yc': ds_target.yc, 'xc': ds_target.xc},
        dims=('yc', 'xc')
    )
    return ds_new

def remove_ocean(ds,start_i, start_j):
    arr=np.array(ds)
    arr = arr.copy().astype(float) 
    nrows, ncols = arr.shape

    neighbors = [(-1,-1), (-1,0), (-1,1),
                 (0,-1),         (0,1),
                 (1,-1), (1,0), (1,1)]
    queue = [(start_i, start_j)]
    visited = np.zeros_like(arr, dtype=bool)

    while queue:
        i,j = queue.pop(0)
        if visited[i,j]:
            continue
        visited[i,j] = True

        if arr[i,j] == 0:
            arr[i,j] = np.nan
            for di,dj in neighbors:
                ni, nj = i + di, j + dj
                if 0 <= ni < nrows and 0 <= nj < ncols and not visited[ni,nj]:
                    queue.append((ni,nj))

    return arr

age1=regrid_iso(age, grid,"isochrone","nearest")
err1=regrid_iso(err, grid,"isochrone","nearest")

age2=remove_ocean(age1,0,0) #array
err2=remove_ocean(err1,0,0)

ds = xr.Dataset(
    data_vars={
        "age": (["yc", "xc"], age2),
        "err": (["yc", "xc"], err2)
    },
    coords={
        "xc": (["xc"], np.array(age1.xc)),
        "yc": (["yc"], np.array(age1.yc)),
        "lon2D": (["yc", "xc"], np.array(grid.lon2D)),
        "lat2D": (["yc", "xc"], np.array(grid.lat2D))
    },)
ds.to_netcdf("./output/paleogris_8km.nc")