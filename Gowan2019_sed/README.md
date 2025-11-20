# Geological sediment properties for North America

Source: [https://doi.pangaea.de/10.1594/PANGAEA.895889](https://doi.pangaea.de/10.1594/PANGAEA.895889)
Citation: Dawson, E.J., Schroeder, D.M., Chu, W. et al.: Ice mass loss sensitivity to the Antarctic ice sheet basal thermal state, Nat Commun 13, 4957, doi:10.1038/s41467-022-32632-2 , 2022.

## Steps

### Download data

We only need the readme and initialization data file

```bash
wget "https://hs.pangaea.de/Maps/NAGS/geology_for_ice_sheet_models.zip"
unzip geology_for_ice_sheet_models.zip
rm geology_for_ice_sheet_models.zip
```

You should now have a folder "data".

### Process the data

Run `julia map_na-seds.jl`. This will produce a combined NetCDF file "Gowan2019_Sediments.nc" with the variables: `grain`, `distribution` and `composite`. The gridded data is at 5km resolution on the original projection used: Lambert conformal (EPSG:3979), which is also used for the Canadian Surficial  Materials Map.

### Produce the corresponding grid description file

```bash
cdo griddes Gowan2019_Sediments.nc > ../maps/grid_Gowan2019_EPSG:3979.txt
```

### Map to grid as needed using CDO

To map to the Laurentide 32KM grid, for example, run:

```bash
./remap.sh LIS-32KM
```