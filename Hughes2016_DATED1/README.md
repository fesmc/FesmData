# DATED-1: time-slice reconstructions of the Eurasian ice sheets (Hughes et al., 2016)

The extent of the British-Irish, Scandinavian and Svalbard-Barents-Kara ice sheets every
1000 years from 25 to 10 ka, as the most-credible extent with a minimum and a maximum,
interpreted from a compilation of dates (census 1 January 2013):

Hughes, A. L. C., Gyllencreutz, R., Lohne, Ø. S., Mangerud, J. and Svendsen, J. I.: The
last Eurasian ice sheets - a chronological database and time-slice reconstruction,
DATED-1, Boreas, 45, 1-45, 2016, [doi:10.1111/bor.12142](https://doi.org/10.1111/bor.12142).

Data: Hughes, A. L. C. et al.: DATED-1: compilation of dates and time-slice reconstruction
of the build-up and retreat of the last Eurasian (British-Irish, Scandinavian,
Svalbard-Barents-Kara Seas) Ice Sheets 40-10 ka, PANGAEA, 2015,
[doi:10.1594/PANGAEA.848117](https://doi.org/10.1594/PANGAEA.848117).

## Licence

CC BY 3.0 (PANGAEA).

## Original data

`DATED-1_TimeSlices_shp.zip` (11.5 MB, no login) from
<https://store.pangaea.de/Publications/HughesA-etal_2015/DATED-1_TimeSlices_shp.zip>,
`hughes2016_dated1` in `datamanifest.toml`; its description, `DATED-1_readme.pdf`, on the
same PANGAEA page. In the folder `DATED1 TimeSlices shp`: `TS<ka>_mc.shp`, `TS<ka>_min.shp`
and `TS<ka>_max.shp` for 10 to 25 ka, polygons of the most-credible, minimum and maximum
extents on a north polar Lambert azimuthal equal-area projection (WGS84). The older slices
(`TS_3835min/max`, `TS_3230`, `TS_2829`, `TS_27`: 38-35, 32-30, 29-28 and 27 ka) are drawn
with solid and dashed lines and have no three estimates; they are not used.

## Prepare and remap

```bash
julia -t 16 --project=Hughes2016_DATED1 Hughes2016_DATED1/prepare.jl
julia fesmdata.jl remap IceHistory DATED1
```

`prepare.jl` writes `$FESMDATA_PREPARED/Hughes2016_DATED1/Hughes2016_DATED1.nc` (see
`Remap/README.md`) with `f_ice` (the most-credible extent), `f_ice_min` and `f_ice_max`
(1), the area fraction of each cell inside the extent, on (x, y, time).

- Grid: the 2 km grid of the North domain of `Batchelor2019_NHIceMasks`
  (`../shared/outlines.jl`), whose cell edges are on those of the North grids, so that
  remapping onto them is exact.
- Fractions: from 8 x 8 samples per cell (250 m); a polygon covers a sample if its centre
  is inside it (even-odd rule over the rings of each polygon, union of the polygons). The
  edges are densified to 1 km before projecting.
- Time: `time` in years ago (before 1950 CE; the calendar ka of the time slices), oldest
  first.
