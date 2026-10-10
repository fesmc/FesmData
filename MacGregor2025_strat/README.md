# Radiostratigraphy and age structure of the Greenland Ice Sheet (MacGregor et al.)

Gridded age structure of the Greenland Ice Sheet from airborne radar sounding (CReSIS,
1993-2019) dated with ice cores, on a 5 km grid (EPSG:3413): the age of the ice at
normalized depths (10-80 % of the ice thickness) and the depth of isochrones of 3 to
115 ka, with their uncertainties. This is version 2 of the NSIDC data set RRRAG4:

MacGregor, J. A., Fahnestock, M. A., Paden, J. D., Li, J., Harbeck, J. P., and
Aschwanden, A.: A revised and expanded deep radiostratigraphy of the Greenland Ice Sheet
from airborne radar sounding surveys between 1993 and 2019, Earth Syst. Sci. Data, 17,
2911-2931, 2025, [doi:10.5194/essd-17-2911-2025](https://doi.org/10.5194/essd-17-2911-2025).

Data: MacGregor, J. A., et al.: Radiostratigraphy and Age Structure of the Greenland Ice
Sheet (RRRAG4, Version 2), NASA NSIDC DAAC, 2025,
[doi:10.5067/SZSVA3CWV3U4](https://doi.org/10.5067/SZSVA3CWV3U4).

Version 1 (MacGregor et al., 2015, J. Geophys. Res. Earth Surf., 120, 212-241,
doi:10.1002/2014JF003215; RRRAG4 v1, doi:10.5067/UGI2BGTC4QJA, 1993-2013 surveys) is
retired at NSIDC. Version 2 adds the surveys of 2014-2019 and revises the earlier ones.
It has no ice thickness and covers 10-80 % of the ice thickness only (version 1: 4-100 %).

## Licence

CC BY 4.0 (`license` attribute of the file); NASA data are open, provided the data set is
cited (nsidc.org/about/data-use-and-copyright).

## Original data

`RRRAG4_Greenland_1993_2019_02_age_grid.nc` (44 MB), downloaded by hand (NASA Earthdata
login) into `$DATAMANIFEST_DATASETS_DIR/rrrag4_v2/` (datamanifest key `rrrag4_v2`):

```bash
curl -n -L -c ~/.urs_cookies -b ~/.urs_cookies -O https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/ICEBRIDGE-Related/RRRAG4/2/1993/06/24/RRRAG4_Greenland_1993_2019_02_age_grid.nc
```

The same grid (identical values) is in the Zenodo record of the article,
`Greenland_isochrone_grid_v2.nc`, [doi:10.5281/zenodo.14182641](https://doi.org/10.5281/zenodo.14182641)
(CC BY 4.0, no login).

## Prepare and remap

```bash
julia --project=MacGregor2025_strat MacGregor2025_strat/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/MacGregor2025_strat/MacGregor2025_STRAT.nc Greenland GreenlandPaleo --name=Stratigraphy-MacGregor2025
```

`prepare.jl` writes to `$FESMDATA_WORK/prepared/MacGregor2025_strat/MacGregor2025_STRAT.nc`
(see `Remap/README.md`), on the original grid (y made ascending):

- `ice_age`, `ice_age_sd` (ka): age of the ice and its uncertainty at `depth_norm`
  (x, y, depth_norm);
- `depth_iso`, `depth_iso_sd` (m): depth of the isochrones below the ice surface and its
  uncertainty, at the isochrone ages `age` (ka) (x, y, age).

`depth_norm` is the depth below the ice surface as a fraction of the ice thickness
(0.1-0.8; the original file gives it in %). Cells without data are missing (NaN).
