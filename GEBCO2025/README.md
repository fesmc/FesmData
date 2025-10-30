# GEBCO2025 Bathymetry and topography



## Steps

1. Download the original dataset (~4 Gb) and unzip it (~7 Gb). Delete zip file to save space.

```bash
# Download surface topography
wget https://dap.ceda.ac.uk/bodc/gebco/global/gebco_2025/ice_surface_elevation/netcdf/gebco_2025.zip
unzip gebco_2025.zip
rm gebco_2025.zip

# Download sub-ice bathymetry
wget https://dap.ceda.ac.uk/bodc/gebco/global/gebco_2025/sub_ice_topography_bathymetry/netcdf/gebco_2025_sub_ice_topo.zip
unzip gebco_2025_sub_ice_topo.zip
rm gebco_2025_sub_ice_topo.zip

```

Now we should have the initial data file `GEBCO_2025.nc` for the surface and `gebco_2025_sub_ice_topo.nc` for the sub-ice bathymetry.

2. Next, ...
