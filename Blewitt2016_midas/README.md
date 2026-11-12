# MIDAS GPS velocities of the Nevada Geodetic Laboratory (Blewitt et al., 2016)

Vertical velocities of all GPS stations processed by the Nevada Geodetic Laboratory (NGL,
University of Nevada, Reno), about 22 000 worldwide, estimated from their daily time
series with the MIDAS robust trend estimator, in the frame IGS20. The velocities are
the observed total vertical land motion: they include, besides glacial isostatic
adjustment (GIA), the elastic response to present changes of ice, water and atmosphere
loads, tectonics and local motion. **No correction is applied** (`elastic_correction =
"not removed"`). NGL updates the file every week; FesmData keeps a dated snapshot.

Blewitt, G., Kreemer, C., Hammond, W. C., and Gazeaux, J.: MIDAS robust trend estimator
for accurate GPS station velocities without step detection, J. Geophys. Res. Solid
Earth, 121, 2054-2068, 2016,
[doi:10.1002/2015JB012552](https://doi.org/10.1002/2015JB012552).

NGL asks to cite its data products with Blewitt, G., Hammond, W. C., and Kreemer, C.:
Harnessing the GPS data explosion for interdisciplinary science, Eos, 99, 2018,
[doi:10.1029/2018EO104623](https://doi.org/10.1029/2018EO104623), and, where they
exist, the data citations of the stations used (on the NGL station pages).

## Licence

CC BY 4.0: the data products policy of the Nevada Bureau of Mines and Geology (NBMG,
University of Nevada, Reno, <https://nbmg.unr.edu/Copyright.html>), which applies to
the products of NGL (<https://geodesy.unr.edu/Disclaimer.php>).

## Original data

`midas.IGS.txt` of NGL, <https://geodesy.unr.edu/gps_timeseries/IGS20/midas/midas.IGS.txt>
(no login), downloaded by `prepare.jl` (datamanifest key `blewitt2016_midas`) into a
folder named after the date of the download, the snapshot: **2026-11-12** (file of NGL
of 2026-11-11, MIDAS5, 21 892 stations). The columns are described in
<https://geodesy.unr.edu/velocities/midas.readme.txt>; the velocities are in m/yr, the
longitudes partly below -180°. A new snapshot is a new date in the `storage_path` of the
datamanifest entry.

## Prepare and record

```bash
julia --project=Blewitt2016_midas Blewitt2016_midas/prepare.jl
julia fesmdata.jl record GPS MIDAS
```

`prepare.jl` writes `$FESMDATA_PREPARED/Blewitt2016_midas/Blewitt2016_MIDAS.nc`, one
value per station (featureType point, dimension `station`): `uplift_rate` and
`uplift_rate_sd` (mm yr-1, the MIDAS vertical velocity and its uncertainty),
`time_start` and `time_end` (first and last epoch of the series, decimal years),
`n_steps` (steps in the series from the NGL step database), `lat`, `lon` (in -180:180)
and `site_name`. The global attributes `reference_frame` (IGS20) and `snapshot` give the
frame and the date of the file.

All stations are kept, also those with short series: MIDAS rates of series shorter than
about 2.5 years are biased by seasonal signals and should be left out or weighted down
(`time_end - time_start`).
