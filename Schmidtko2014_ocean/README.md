# Antarctic shelf bottom water (Schmidtko et al., 2014)

Temperature and salinity of the bottom water on the Antarctic continental shelf
(sea floor shallower than 1500 m), means over 1975-2012 on a 0.25° x 0.125° lon-lat grid,
from:

Schmidtko, S., Heywood, K. J., Thompson, A. F. and Aoki, S.: Multidecadal warming of
Antarctic waters, Science, 346, 1227-1231, 2014,
[doi:10.1126/science.1256117](https://doi.org/10.1126/science.1256117).

## Licence

No licence is stated by the authors. We assume the data may be used and published,
with citation of the article.

## Original data

`Antarctic_shelf_data.txt` (ASCII, 1.7 MB) from the web page of S. Schmidtko at GEOMAR,
downloaded by `prepare.jl` (datamanifest key `schmidtko2014_shelf`):

```bash
wget https://www.geomar.de/fileadmin/personal/fb1/po/sschmidtko/Antarctic_shelf_data.txt
```

It lists one row per shelf cell: longitude (0 to 360), latitude (rounded to 0.01°), depth
of the sea floor (m, negative), conservative temperature and its standard deviation
(°C), absolute salinity and its standard deviation (g kg-1), all TEOS-10.

## Prepare and remap

```bash
julia --project=Schmidtko2014_ocean Schmidtko2014_ocean/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Schmidtko2014_ocean/Schmidtko2014_OCEAN.nc Antarctica --name=OCEAN-Schmidtko2014
```

`prepare.jl` puts the cells on their lon-lat grid (longitudes -180 to 180, latitudes
-79.875 to -60), missing off the shelf, and writes `ct_bottom`, `ct_bottom_std` (°C),
`sa_bottom`, `sa_bottom_std` (g kg-1) and `z_bottom` (m) to
`$FESMDATA_WORK/prepared/Schmidtko2014_ocean/Schmidtko2014_OCEAN.nc` (see
`Remap/README.md`). The values are not converted (conservative temperature and absolute
salinity, not potential temperature and practical salinity).

The data are bottom values only, with no depth axis. The v1 file `ANT-16KM_OCEAN_S14.nc`
had `to` and `so` on the 42 depth levels of ORAS4: the bottom values were repeated at
every level, in a copy of the ORAS4 file (with its `mask_ocn`).
