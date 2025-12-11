# Elevations at the ice core locations 

Data from [Vinther et al. (2009)](https://doi.org/10.1038/nature08355).

The `elevation.csv` file contains the elevation change at Camp Century, NGRIP, GRIP, and DYE-3 ice core sites, extracted from the original file:  
[https://www.ncei.noaa.gov/pub/data/paleo/icecore/greenland/vinther2009greenland.xls](https://www.ncei.noaa.gov/pub/data/paleo/icecore/greenland/vinther2009greenland.xls)

The estimated 1-sigma uncertainties on the site elevation data are:  
- ±40 m for GRIP and NGRIP  
- ±65 m for Camp Century and DYE-3  

(See Vinther et al., 2009, supplementary information for details.)

| Site                   | Location                        |
|------------------------|---------------------------------|
| Camp Century, Greenland | 77°10'N, 61°08'W, 1890 m elevation |
| NGRIP, Greenland        | 75°06'N, 42°18'W, 2920 m elevation |
| GRIP, Greenland         | 72°35'N, 37°38'W, 3230 m elevation |
| DYE-3, Greenland        | 65°11'N, 43°49'W, 2490 m elevation |

## Build `vinther2009.nc` File

To build a dataset with the absolute elevations instead of the elevation change, as well as the uncertainty for each ice core, run the following script:

```
python3.12 build_dataset.py
```

The dependencies are ```xarray```, ```numpy``` and ```pandas```. 
