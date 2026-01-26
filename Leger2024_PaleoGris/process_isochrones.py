import xarray as xr
import numpy as np
import pandas as pd
from scipy.interpolate import griddata


# ----------------------------------------------------
#  Paths
# ----------------------------------------------------
# PaleoGrIS isochrones
age = xr.open_dataset("./isochrone_buffers/PaleoGrIS_1.0_isochrone_buffers_2km_age.nc")
err = xr.open_dataset("./isochrone_buffers/PaleoGrIS_1.0_isochrone_buffers_2km_error.nc")
# m --> km
age['x']=age.x*1e-3
age['y']=age.y*1e-3
err['x']=err.x*1e-3
err['y']=err.y*1e-3

# New grid
grid=xr.open_dataset("/p/projects/megarun/ice_data/Greenland/GRL-8KM/GRL-8KM_TOPO-M17.nc")
# Regions for the area timeseries
regs=xr.open_dataset("/p/projects/megarun/luciagu/data/lauritzen2025/Greenland_Basins_PS_v1.4.2_8km.nc")

# ------------------------------------------------------
# Regrid isochrones to 8km grid and remove ocean
# ------------------------------------------------------
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

# ------------------------------------------------------
# Calculate total area and area per region
# ------------------------------------------------------

age0=remove_ocean(age.isochrone,0,0) #array
age_new = xr.Dataset(
    data_vars={
        "isochrone": (["yc","xc"], age0),
    },
    coords={
        "xc": (["xc"], np.array(age.x)),
        "yc": (["yc"], np.array(age.y)),
    },)
reg_hi = regs.mask.interp_like(age_new.isochrone, method="nearest")

time=np.unique(age_new.isochrone)
time=time[~np.isnan(time)]
region_ids = np.unique(regs.mask)
region_ids = region_ids[region_ids != 0] # remove ocean
area_por_region = {r: [] for r in region_ids}
area_total = []
area_celda = 2*2*1e-6#million km²
for t in time:
    cubierta = xr.where(age_new.isochrone <= t, 1, 0)  
    # área total
    A_t = cubierta.sum() * area_celda
    area_total.append(A_t.item())
    
    # área por región
    for r in region_ids:
        A_r_t = cubierta.where(reg_hi == r).sum() * area_celda
        area_por_region[r].append(A_r_t.item())
     
regions = np.array(region_ids)
A = np.stack([area_por_region[r] for r in regions], axis=0)

ds2 = xr.Dataset(
    data_vars={
        "A": (["region", "time"], A),
        "tot": (["time"], np.array(area_total)),
        "time_err": (["time"], np.array(
            [0,500,500,500,500,500,500,500,500,500,500,500,1000]
        )),
    },
    coords={
        "time": (["time"], np.array(time)),
        "region": (["region"], regions.astype(int)),
    },
)

ds2.to_netcdf("./output/regions_area_paleogris.nc")