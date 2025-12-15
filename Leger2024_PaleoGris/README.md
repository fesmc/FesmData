# Geological sediment properties for North America

Source: [https://data.mendeley.com/datasets/nh57cz4gys/1](https://data.mendeley.com/datasets/nh57cz4gys/1)
Citation: Leger, T. P. M., Clark, C. D., Huynh, C., Jones, S., Ely, J. C., Bradley, S. L., Diemont, C., and Hughes, A. L. C.: A Greenland-wide empirical reconstruction of paleo ice sheet retreat informed by ice extent markers: PaleoGrIS version 1.0, Clim. Past, 20, 701–755, https://doi.org/10.5194/cp-20-701-2024, 2024. 

## Steps

### Download data

Data can be download [here](https://data.mendeley.com/datasets/nh57cz4gys/1). Here we only process the isochrone buffers product in NetCDF format:
`/A Greenland-wide empirical reconstruction of paleo ice-sheet retreat informed by ice extent markers PaleoGrIS version 1.0/Leger_et_al_2024_PaleoGrIS_01_Supplementary_data/Supplementary_data/PaleoGrIS_1.0_isochrones/NetCDF_format/isochrone_buffers`

### Process the data

Running the script `process_isochrones.py` will produce a NetCDF file containing the age and uncertainty of the isochrones on the desired grid. It also removes ocean cells, which in the original data have an age of 0.

1. Modify the paths in `process_isochrones.py` to point to the downloaded data, de desired grid.
2. Run `process_isochrones.py`. This will produce a combined NetCDF file `./output/paleogris_8km.nc`.