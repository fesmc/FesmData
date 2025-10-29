#!/bin/bash

# Generate source grid file, make sure to set grid type to latlon
cdo griddes Batchelor2019_ice_masks.nc > grid_NH-lonlat-0.5deg.txt
sed -i -e 's/generic/latlon/g' grid_NH-lonlat-0.5deg.txt
rm grid_NH-lonlat-0.5deg.txt-e

