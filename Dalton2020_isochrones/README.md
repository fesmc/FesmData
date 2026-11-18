# Ice-margin chronology of the North American Ice Sheet Complex (Dalton et al., 2020)

The 36 isochrones of the last deglaciation of the North American Ice Sheet Complex
(Laurentide, Cordilleran and Innuitian ice sheets), from 18 to 1 14C ka (22.1 to 0.91
cal ka), an update of the maps of Dyke et al. (2003) and Dyke (2004) from regional
studies and an expanded radiocarbon database:

Dalton, A. S., Margold, M., Stokes, C. R., et al.: An updated
radiocarbon-based ice margin chronology for the last deglaciation of the North American
Ice Sheet Complex, Quat. Sci. Rev., 234, 106223, 2020,
[doi:10.1016/j.quascirev.2020.106223](https://doi.org/10.1016/j.quascirev.2020.106223).

## Licence

The shapefiles are supplementary data of the article on ScienceDirect (Elsevier), with no
licence stated (the accepted manuscript is in the Exeter repository under CC BY-NC-ND
4.0). The product is made but not released (`release = false` in
`IceHistory/remap.toml`) until the redistribution of derived products is settled with the
authors. The calendar-year successor, NADI-1 (Dalton et al., 2023, Quat. Sci. Rev., 321,
108345; [doi:10.5281/zenodo.8161764](https://doi.org/10.5281/zenodo.8161764), CC BY 4.0,
25-1 ka every 500 years with minimum, optimal and maximum margins), has an open licence.

## Original data

`1-s2.0-S0277379119307619-mmc4.zip` (13.9 MB, no login), the supplementary data of the
article: <https://ars.els-cdn.com/content/image/1-s2.0-S0277379119307619-mmc4.zip>,
`dalton2020_isochrones` in `datamanifest.toml`. One shapefile per isochrone,
`<14C age>ka_<calibrated age>cal_Dalton_et_al_2020_QSR.shp` (ages in thousands of
years), polygons of ice (attribute `SYMB` = `ICE`; the file of 0.91 cal ka has no
attributes), in lon-lat (WGS84) except 2, 3.2 and 4.5 cal ka (a Lambert conformal conic
projection). The isochrones include Greenland and the ice caps of the Canadian Arctic.

## Prepare and remap

```bash
julia -t 16 --project=Dalton2020_isochrones Dalton2020_isochrones/prepare.jl
julia fesmdata.jl remap IceHistory Dalton2020
```

`prepare.jl` writes `$FESMDATA_PREPARED/Dalton2020_isochrones/Dalton2020_ISOCHRONES.nc`
(see `Remap/README.md`) with `f_ice` (1), the area fraction of each cell inside the ice
polygons, on (x, y, time), and `age_14c` (time), the radiocarbon age of each isochrone.

- Grid: the 2 km grid of the North domain of `Batchelor2019_NHIceMasks`
  (`../shared/outlines.jl`), whose cell edges are on those of the North grids, so that
  remapping onto them is exact.
- Fractions: from 8 x 8 samples per cell (250 m); a polygon covers a sample if its centre
  is inside it (even-odd rule over the rings of each polygon, union of the polygons). The
  edges are densified to 0.01° (1 km for the projected files) before projecting.
- Time: `time` in years ago (before 1950 CE), the calibrated age the authors give each
  isochrone in its file name, oldest first.
- A few rings at the southern edge of the Cordilleran ice (the oldest isochrones) lie
  partly or entirely outside the grid: those entirely outside are left out, the others
  rasterized where they lie in the grid (the log of `prepare.jl` counts them); none
  reaches a grid of the North domain.
