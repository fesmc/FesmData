import numpy as np
import xarray as xr
import pandas as pd
import glob
import os

# ----------------------------------------------------------------------------
# Paths
# ----------------------------------------------------------------------------
path_data="./paleo_sea_level/sea_level_data/Greenland/*"
path_output="./output"
data_paths = sorted(glob.glob(path_data))
grid = xr.open_dataset("/p/projects/megarun/ice_data/Greenland/GRL-8KM/GRL-8KM_TOPO-M17.nc")

# ---------------------------------------------
# processing data:
# Creates a dataset with all the observations grouped by site (xc,yc) in the coordinadates of grid
# ---------------------------------------------
records = [] 
for region_path in data_paths:
    if os.path.isdir(region_path):
        region = os.path.basename(region_path)
        file_path = os.path.join(region_path, "calibrated.txt")

        if os.path.exists(file_path):
            df = pd.read_csv(
                file_path,
                sep="\t",
                header=None,
                names=[
                    "label", "lat", "lon", "time", "time_err",
                    "type", "RSL", "RSL_err_max", "RSL_err_min", "source"
                ]
            )
            df["region"] = region  
            records.append(df)

df_all = pd.concat(records, ignore_index=True)


def point(lat, lon, grid):
    dist = np.sqrt((grid.lat2D - lat)**2 + (grid.lon2D - lon)**2)
    iy, ix = np.unravel_index(dist.argmin(), dist.shape)
    point_ts = grid.isel(yc=iy, xc=ix)
    return point_ts

x=[]
y=[]
for lat, lon in zip(df_all['lat'], df_all['lon']): 
    ds0 = point(lat, lon, grid)
    xc,yc = ds0.xc.values, ds0.yc.values
    x.append(xc)
    y.append(yc)
x=np.array(x)
y=np.array(y)
df_all['xc']=x
df_all['yc']=y

df = df_all.copy()
df = df.sort_values("time")   # importante
grouped = df.groupby(["xc", "yc"])

sites = []
time = []
time_err = []
RSL = []
RSL_err_min = []
RSL_err_max = []
labels = []
regions = []

for (xc, yc), g in grouped:
    sites.append((xc, yc))
    time.append(g["time"].values)
    time_err.append(g["time_err"].values)
    RSL.append(g["RSL"].values)
    RSL_err_min.append(g["RSL_err_min"].values)
    RSL_err_max.append(g["RSL_err_max"].values)
    labels.append(",".join(g["label"].astype(str)))
    regions.append(g["region"].iloc[0])
    
max_len = max(len(t) for t in time)

def pad(a, n, fill=np.nan):
    a = np.asarray(a, dtype=float)
    return np.pad(a, (0, n - len(a)), constant_values=fill)

time          = np.array([pad(a, max_len) for a in time])
time_err      = np.array([pad(a, max_len) for a in time_err])
RSL           = np.array([pad(a, max_len) for a in RSL])
RSL_err_min   = np.array([pad(a, max_len) for a in RSL_err_min])
RSL_err_max   = np.array([pad(a, max_len) for a in RSL_err_max])

ds_new = xr.Dataset(
    data_vars=dict(
        time=(("site", "obs"), time),
        time_err=(("site", "obs"), time_err),
        RSL=(("site", "obs"), RSL),
        RSL_err_min=(("site", "obs"), RSL_err_min),
        RSL_err_max=(("site", "obs"), RSL_err_max),
    ),
    coords=dict(
        site=np.arange(len(sites)),
        obs=np.arange(max_len),
        xc=("site", [s[0] for s in sites]),
        yc=("site", [s[1] for s in sites]),
        label=("site", labels),
        region=("site", regions),
    ),
)
ds_new.to_netcdf(os.path.join(path_output, "rsl_dataset.nc"))

# ---------------------------------------------
# processing data:
# Create a dataset based on ds_new but with reduced number of sites (one per region)
# Coordinates are promedied per region
# We keep all the observations (RSL vs time) for each region
# ---------------------------------------------

ds_flat = ds_new.stack(obs_all=("site", "obs"))
ds_flat = ds_flat.dropna(dim="obs_all", subset=["time"])

groups = []
regions = []

xc_new_list = []
yc_new_list = []
xc_min_list = []
xc_max_list = []
yc_min_list = []
yc_max_list = []
n_sites_list = []

for reg, g in ds_flat.groupby("region"):
    xc_new = g.xc.mean().item()
    yc_new = g.yc.mean().item()
    xc_min = g.xc.min().item()
    xc_max = g.xc.max().item()
    yc_min = g.yc.min().item()
    yc_max = g.yc.max().item()
    n_sites = len(np.unique(g.site.values))

    ds_reg = xr.Dataset(
        data_vars=dict(
            time=(["obs"], g.time.values),
            time_err=(["obs"], g.time_err.values),
            RSL=(["obs"], g.RSL.values),
            RSL_err_min=(["obs"], g.RSL_err_min.values),
            RSL_err_max=(["obs"], g.RSL_err_max.values),
        ),
        coords=dict(
            obs=np.arange(g.sizes["obs_all"])
        )
    )

    groups.append(ds_reg)
    regions.append(reg)

    xc_new_list.append(xc_new)
    yc_new_list.append(yc_new)
    xc_min_list.append(xc_min)
    xc_max_list.append(xc_max)
    yc_min_list.append(yc_min)
    yc_max_list.append(yc_max)
    n_sites_list.append(n_sites)

ds_region = xr.concat(groups, dim="region")

ds_region = ds_region.assign_coords(
    region=("region", regions),
    xc=("region", xc_new_list),
    yc=("region", yc_new_list),
    xc_min=("region", xc_min_list),
    xc_max=("region", xc_max_list),
    yc_min=("region", yc_min_list),
    yc_max=("region", yc_max_list),
    n_sites=("region", n_sites_list)
)
ds_region = ds_region.drop_vars("obs")  # solo si no necesitas
ds_region.to_netcdf(os.path.join(path_output, "rsl_dataset_reduced.nc"))