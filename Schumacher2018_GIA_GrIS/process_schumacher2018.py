import xarray as xr
import numpy as np
import matplotlib as mpl
import pandas as pd
from matplotlib import pyplot as plt

def point(lat, lon, grid):
    dist = np.sqrt((grid.lat2D - lat)**2 + (grid.lon2D - lon)**2)
    iy, ix = np.unravel_index(dist.argmin(), dist.shape)
    point_ts = grid.isel(yc=iy, xc=ix)
    return point_ts

schu=pd.read_csv("./data/Schumacher_etal_2018_GIA_no_header.tab", sep="\t", comment="#", na_values=["-9999"])
grid=xr.open_dataset("./data/GRL-8KM_TOPO-M17.nc")

station=schu.to_numpy()[:,0]
lon=schu.to_numpy()[:,1]
lat=schu.to_numpy()[:,2]
v_vert=schu.to_numpy()[:,3]
std=schu.to_numpy()[:,4]

ds = xr.Dataset(
    data_vars=dict(
        v_vert=("station", v_vert),
        std=("station", std),
    ),
    coords=dict(
        station=("station", station),
        lat=("station", lat),
        lon=("station", lon),
    ),
    attrs={"Source": "Source: Schumacher et al. (2018)", 
           "doi": "https://doi.org/10.1093/gji/ggy235"}
)

xc_list = []
yc_list = []

for la, lo in zip(ds.lat.values, ds.lon.values):
    p = point(float(la), float(lo), grid)   # aplica tu función
    xc_list.append(p.xc.values)
    yc_list.append(p.yc.values)
    
ds = ds.assign_coords(
    xc=("station", np.array(xc_list)),
    yc=("station", np.array(yc_list))
)

ds_gris=ds.where((ds.xc>-600)&(ds.xc<900)&(ds.yc>-3400)&(ds.yc<0))
ds_gris = ds_gris.dropna(dim="station", subset=["v_vert", "std"])
ds_gris.to_netcdf("./data/schumacher2018_GR.nc")


# ----------------------------------------------------------------------------
# Figure Location of GIA stations
# ----------------------------------------------------------------------------
present=grid.where((grid.xc<900)&(grid.yc<grid.xc*0.75-650))

f=17
fig,ax=plt.subplots(1,1, figsize=(8,12))

# Mapa fondo --------------------------------------------
ax.set_facecolor("white")
ax.contour(present.xc, present.yc, present.z_srf, levels=np.linspace(0,10,1), colors="black", linewidths=0.5,zorder=3)
ax.contourf(present.xc, present.yc, present.z_srf.where(present.z_srf>-10), colors="#98C37C",zorder=1)
xmin=-780
xmax=1050
mask = np.where(np.isnan(present.z_srf), 0, present.z_srf)
mask = np.where(mask == 0, 1, np.nan)
ny = mask.shape[0]
xc = present.xc.values
zeros_left = np.ones((ny, 1))
zeros_right = np.ones((ny, 1))
mask_extended = np.hstack([zeros_left, mask, zeros_right])
xc_extended = np.concatenate([[xmin], xc, [xmax]])
ax.contourf(xc_extended, present.yc, mask_extended,colors="white",zorder=2)
ax.contour(present.xc, present.yc, present.H_ice, levels=np.linspace(0,10,1), colors="black", linewidths=0.5,zorder=3)
ax.contourf(present.xc, present.yc, present.H_ice.where(present.H_ice>0), levels=np.linspace(0,4000,2), colors="#E6F1F3",zorder=3)


# Estaciones --------------------------------------------
i=0
for station in ds_gris.station.values:
    sim=ds_gris.sel(station=station)
    ax.plot(sim.xc, sim.yc, 'o', color="red", markersize=10, markeredgecolor='black', label=station,zorder=6)  
    if sim.xc<100:
        a=-200
    else:
        a=10
    if i%2==0:
        b=10
    else:
        b=-70    
    if station=="TREO":a=-150
    if station=="KBUG":a, b=-150, 10
    if station=="LEFN":a, b=-180, -50
    if station=="HRDG":a=8
    if station=="KMJP":b=30
    if station=="BLAS":a, b=-180,-40
    if station=="GROK":a, b=-200,-40
    if station=="YMER":a, b=-200,-40
    if station=="HMBG":a, b=-200,-40
    if station=="KAGA":a, b=15,-40
    if station=="ILUL":a, b=0,40
    if station=="RINK":a, b=15,0
    if station=="SRMP":a, b=15,0
    if station=="SCBY":a, b=15,0
    if station=="ASKY":a, b=15,0
    if station=="KAPI":a, b=15,0

    ax.text(sim.xc+a, sim.yc+b, station, color="black", fontsize=f, zorder=5,
            bbox=dict(facecolor='#E6F1F3',edgecolor='none',alpha=0.8))
    i=i+1

    
ax.set_xlim(xmin,xmax)
ax.set_aspect(1)
ax.tick_params(labelbottom=False, labelleft=False)
plt.tight_layout()
fig.savefig("./figs/map_stations.png", dpi=300)
plt.close()