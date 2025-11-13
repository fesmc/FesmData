#!/bin/bash

# Generate source grid file, make sure to set grid type to latlon
cdo griddes Lucazeau2019_ghf.nc > grid_lonlat-0.5deg-720x360.txt
sed -i -e 's/generic/latlon/g' grid_lonlat-0.5deg-720x360.txt
rm grid_lonlat-0.5deg-720x360.txt-e
mv grid_lonlat-0.5deg-720x360.txt ../maps/
