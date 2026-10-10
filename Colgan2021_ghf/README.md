# Geothermal heat flow of Greenland (Colgan & Wansing, 2021)

Geothermal heat flow of Greenland and its surroundings (within 500 km of the coast)
predicted by machine learning from heat flow measurements and geophysical observables,
with the minimum and maximum of the model ensemble onshore, at about 55 km resolution:

Colgan, W., Wansing, A., Mankoff, K., Lösing, M., et al.: Greenland Geothermal Heat
Flow Database and Map (Version 1), Earth Syst. Sci. Data, 14, 2209-2238, 2022,
[doi:10.5194/essd-14-2209-2022](https://doi.org/10.5194/essd-14-2209-2022).

Data: Colgan, W. and Wansing, A.: Greenland Geothermal Heat Flow Database and Map,
GEUS Dataverse, V2.1, 2021, [doi:10.22008/FK2/F9P03L](https://doi.org/10.22008/FK2/F9P03L).

The map is also redistributed, regridded, in the supplement of the ISMIP7 heat flow
recommendations (Lösing et al., 2025, [doi:10.5281/zenodo.16874966](https://doi.org/10.5281/zenodo.16874966),
restricted access), and is the Colgan field of the ISMIP7 observations kit.

## Licence

CC0 1.0 (GEUS Dataverse).

## Original data

`geothermal_heat_flow_from_machinelearning.xyz` (lon, lat, mean, minimum and maximum
heat flow), downloaded by `prepare.jl` (datamanifest key `colgan2021_ghf`) from
<https://dataverse.geus.dk/api/access/datafile/19155> (no login).

The dataset also has a model that includes the basal heat flow at NGRIP
(`..._with_NGRIP`, 2022), which is much higher around NGRIP (80 instead of 39 mW m-2).
The model without NGRIP is used, as in ISMIP7. The gridded maps of the dataset
(`geothermal_heat_flow_map_55km.nc`, `..._10km.nc`) are interpolated from the points and
have only the mean.

## Prepare and remap

```bash
julia --project=Colgan2021_ghf Colgan2021_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Colgan2021_ghf/Colgan2021_GHF.nc Greenland --name=GHF-Colgan2021
```

`prepare.jl` writes `ghf`, `ghf_min` and `ghf_max` (mW m-2) to
`$FESMDATA_WORK/prepared/Colgan2021_ghf/Colgan2021_GHF.nc` (see `Remap/README.md`).
`ghf` covers land and ocean, `ghf_min` and `ghf_max` only part of it (mostly onshore).

The data are points of an equal-area grid: rings 0.5° apart in latitude (57-85°N),
with points about 0.5°/cos(latitude) apart in longitude (about 55 km). They are put on
a regular lon-lat grid of 0.5° (the rings) by 0.1°, each cell taking the value of the
nearest point of its ring (within half the point spacing), so that each point fills
its own equal-area cell; nothing is interpolated.
