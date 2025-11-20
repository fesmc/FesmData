# Relative Sea Level reconstructions in Greenland

This repository contains the dataset `rsl_gris_preliminary.nc`, which is a compilation (still under construction) of relative sea level (RSL) observations from 26 sites in Greenland.


## Dataset Description

The **`rsl_gris.nc`** NetCDF file includes the following dimensions and variables:

- **Dimensions**
  
### Dimensions
- **`obs_label` (26)** → Identifies each group of measurements at a location.  
  - Example: one block of lake sediment observations, another block of shell data at the same site.  
- **`n` (49)** → Maximum number of measurements per group. Each `obs_label` can have a different number of observations, up to 49.

### Variables
| Variable   | Dimensions        | Type     | Description |
|------------|------------------|----------|-------------|
| `time`     | (obs_label, n)   | float64  | Age of the observation (years BP) |
| `time_err` | (obs_label, n)   | float64  | Age uncertainty |
| `rsl`      | (obs_label, n)   | float64  | RSL (m) |
| `rsl_err`  | (obs_label, n)   | float64  | RSL uncertainty |


### Coordinates (per `obs_label`)
| Coordinate       | Type     | Description |
|------------------|----------|-------------|
| `obs_label`      | string   | Unique identifier for each measurement group |
| `location_label` | string   | Name of the location (e.g., Scoresby Sund, Upernivik) |
| `region`         | string   | Geographic region (e.g., east, west) |
| `lat`            | float64  | Latitude of the location |
| `lon`            | float64  | Longitude of the location |
| `source`         | string   | Bibliographic reference for the dataset |

---

## Dataset Description

This map shows all the locations included in the dataset along with their references:

<img src="figs/locations_map.pdf" alt="Locations map and references" width="500">