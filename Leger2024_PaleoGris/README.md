# PaleoGrIS 1.0: deglaciation of the Greenland Ice Sheet (Leger et al., 2024)

Time of deglaciation of the Greenland Ice Sheet and its uncertainty, from the isochrones of
an empirical reconstruction of its retreat since the Last Glacial Maximum (13 to 7 ka):

Leger, T. P. M., Clark, C. D., Huynh, C., Jones, S., Ely, J. C., Bradley, S. L., Diemont,
C. and Hughes, A. L. C.: A Greenland-wide empirical reconstruction of paleo ice sheet
retreat informed by ice extent markers: PaleoGrIS version 1.0, Clim. Past, 20, 701-755,
2024, [doi:10.5194/cp-20-701-2024](https://doi.org/10.5194/cp-20-701-2024).

Data: Mendeley Data, [doi:10.17632/nh57cz4gys.1](https://doi.org/10.17632/nh57cz4gys.1).

## Licence

CC BY 4.0 (Mendeley Data).

## Original data

`Leger_et_al_2024_PaleoGrIS_01_Supplementary_data.zip` (2 GB, no login) from
<https://data.mendeley.com/datasets/nh57cz4gys/1>, `leger2024_paleogris` in
`datamanifest.toml`. Used are the 1 km isochrone buffer products,
`Supplementary_data/PaleoGrIS_1.0_isochrones/NetCDF_format/isochrone_buffers/PaleoGrIS_1.0_isochrone_buffers_1km_{age,error}.nc`
(EPSG:3413), which give each area between two isochrones their age and uncertainty
(also at 2 km; the isochrones themselves as lines at 200 m and as shapefiles).

## Prepare and remap

```bash
julia --project=Leger2024_PaleoGris Leger2024_PaleoGris/prepare.jl
julia fesmdata.jl remap $FESMDATA_PREPARED/Leger2024_PaleoGris/Leger2024_PaleoGrIS.nc Greenland GreenlandPaleo --name=IceHistory-PaleoGrIS
```

`prepare.jl` writes `$FESMDATA_PREPARED/Leger2024_PaleoGris/Leger2024_PaleoGrIS.nc`
(see `Remap/README.md`) on the 1 km grid of the buffers with

- `age_deglac` (years ago, before 1950 CE): time of deglaciation, 13000 to 7000 (13000,
  12250, then every 500 years);
- `age_deglac_err` (years): its uncertainty, 500 to 1000.

The buffers are 0 outside the reconstructed area (the present ice sheet, and the land and
ocean beyond the outermost isochrone); these cells are missing here. The coordinates,
stored as Float32 in the original files, are rebuilt on the exact 1 km spacing.

The v1 files of this folder (a copy of the 2 km buffers, `process_isochrones.py` and its
output on GRL-8KM and the area per basin) are replaced by `prepare.jl` and remapping.
