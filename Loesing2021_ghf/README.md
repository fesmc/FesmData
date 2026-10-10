# Geothermal heat flow of Antarctica (Lösing & Ebbing, 2021)

Geothermal heat flow of Antarctica predicted by machine learning (gradient boosted
regression trees) from geophysical and geological observables, with the minimum and
maximum of three alternative models as uncertainty, at about 55 km resolution:

Lösing, M. and Ebbing, J.: Predicting geothermal heat flow in Antarctica with a machine
learning approach, J. Geophys. Res. Solid Earth, 126, e2020JB021499, 2021,
[doi:10.1029/2020JB021499](https://doi.org/10.1029/2020JB021499).

Data: Lösing, M. and Ebbing, J.: Predicted Antarctic heat flow and uncertainties using
machine learning, PANGAEA, 2021,
[doi:10.1594/PANGAEA.930237](https://doi.org/10.1594/PANGAEA.930237).

The map is also redistributed, regridded, in the supplement of the ISMIP7 heat flow
recommendations (Lösing et al., 2025, [doi:10.5281/zenodo.16874966](https://doi.org/10.5281/zenodo.16874966),
restricted access); it is the Lösing field of the ISMIP7 observations kit and of the v1
file `ANT-16KM_GHF-L21.nc`.

## Licence

CC BY 4.0 (PANGAEA).

## Original data

`HF_Min_Max_MaxAbs-1.csv` (the updated version of 2022, with 115 more points north of
65.5°S; the other values are those of `HF_Min_Max_MaxAbs.csv`), downloaded by
`prepare.jl` (datamanifest key `loesing2021_ghf`) from
<https://download.pangaea.de/dataset/930237/files/HF_Min_Max_MaxAbs-1.csv> (no login).

## Prepare and remap

```bash
julia --project=Loesing2021_ghf Loesing2021_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Loesing2021_ghf/Loesing2021_GHF.nc Antarctica --name=GHF-Loesing2021
```

`prepare.jl` writes `ghf`, `ghf_min` and `ghf_max` (mW m-2) to
`$FESMDATA_WORK/prepared/Loesing2021_ghf/Loesing2021_GHF.nc` (see `Remap/README.md`).

The data are points of an equal-area grid: rings 0.5° apart in latitude, with points
about 0.5°/cos(latitude) apart in longitude (about 55 km). They are put on a regular
lon-lat grid of 0.5° (the rings) by 0.1°, each cell taking the value of the nearest
point of its ring (within half the point spacing), so that each point fills its own
equal-area cell; nothing is interpolated. The point at the pole fills its ring.
Missing points (the ocean, and a few cells inland) stay missing. The column
`HF_max_abs` (= `HF_max - HF_min`) is not used.
