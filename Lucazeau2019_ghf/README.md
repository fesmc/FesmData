# Global geothermal heat flow

Paleo time series datasets

Source: [https://agupubs.onlinelibrary.wiley.com/doi/10.1029/2019GC008389](https://agupubs.onlinelibrary.wiley.com/doi/10.1029/2019GC008389)
Citable as: Lucazeau, F. Analysis and Mapping of an Updated Terrestrial Heat Flow Data Set. Geochemistry, Geophysics, Geosystems, 20(8), 4001-4024, doi:10.1029/2019gc008389, 2019.

## Get original data

```bash
wget https://agupubs.onlinelibrary.wiley.com/action/downloadSupplement?doi=10.1029%2F2019GC008389&file=2019GC008389-sup-0003-Data_Set_SI-S01.zip
unzip 2019GC008389-sup-0003-Data_Set_SI-S01.zip
rm 2019GC008389-sup-0003-Data_Set_SI-S01.zip
```

You should now have the original CSV file `HFgrid14.csv` in the subdirectory.

## Process the data onto a lonlat grid and save as NetCDF

First, run script to produce a global lonlat NetCDF file `Lucazeau2019_ghf.nc`:

```bash
julia map-lucazeau-ghf.jl
```

Next generate a grid description file:

```bash
cdo griddes Lucazeau2019_ghf.nc > ../maps/grid_lonlat-0.5deg-720x360.txt
```
