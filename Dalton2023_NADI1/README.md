# NADI-1: North American Deglacial Isochrones, 25-1 ka (Dalton et al., 2023)

The extent of the Laurentide, Cordilleran and Innuitian ice sheets every 500 years from 25
to 1 ka (calendar years), as an optimal extent with a minimum and a maximum, from a
database of radiocarbon, cosmogenic nuclide, luminescence and U-series ages. It supersedes
the radiocarbon isochrones of Dalton et al. (2020) (`../Dalton2020_isochrones/`):

Dalton, A. S. et al.: Deglaciation of the north American ice sheet complex in calendar
years based on a comprehensive database of chronological data: NADI-1, Quat. Sci. Rev.,
321, 108345, 2023, [doi:10.1016/j.quascirev.2023.108345](https://doi.org/10.1016/j.quascirev.2023.108345).

Data: Dalton, A. S. et al.: North American Deglacial Isochrones, version 1 (NADI-1),
Zenodo, 2023, [doi:10.5281/zenodo.8161764](https://doi.org/10.5281/zenodo.8161764).

## Licence

CC BY 4.0 (Zenodo).

## Original data

`NADI-1 shapefiles Dalton et al. QSR.zip` (55 MB, no login) from the Zenodo record,
`dalton2023_nadi1` in `datamanifest.toml`. In the folder `NADI-1 shapefiles Dalton et al.
QSR`: `<age>ka_cal_{OPTIMAL,MIN,MAX}_NADI-1_Dalton_etal_QSR.shp` for the 49 time steps, 25
to 1 ka every 0.5 kyr, in longitude-latitude (WGS84); all polygons are ice (attribute
`Area_Km2`).

## Prepare and remap

```bash
julia -t 16 --project=Dalton2023_NADI1 Dalton2023_NADI1/prepare.jl
julia fesmdata.jl remap IceHistory NADI1
```

`prepare.jl` writes `$FESMDATA_PREPARED/Dalton2023_NADI1/Dalton2023_NADI1.nc` (see
`Remap/README.md`) with `f_ice` (the optimal extent), `f_ice_min` and `f_ice_max` (1), the
area fraction of each cell inside the extent, on (x, y, time).

- Grid: the 2 km grid of the North domain of `Batchelor2019_NHIceMasks`
  (`../shared/outlines.jl`), whose cell edges are on those of the North grids, so that
  remapping onto them is exact.
- Fractions: from 8 x 8 samples per cell (250 m); a polygon covers a sample if its centre
  is inside it (even-odd rule over the rings of each polygon, union of the polygons). The
  edges are densified to 0.01° before projecting.
- Time: `time` in years ago (before 1950 CE; the calendar ages of the time steps), oldest
  first.
