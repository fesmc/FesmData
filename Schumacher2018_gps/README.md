# GPS vertical velocities for GIA (Schumacher et al., 2018)

Vertical velocities of about 4000 GPS stations worldwide (4072 rows, 4070 station
names), corrected for non-GIA effects (atmospheric loading, elastic response to present
changes of ice and ocean loads, rotational pole changes) as observational estimates of
glacial isostatic adjustment uplift rates. From:

Schumacher, M., King, M. A., Rougier, J., Sha, Z., Khan, S. A., and Bamber, J. L.: A new
global GPS data set for testing and improving modelled GIA uplift rates, Geophys. J.
Int., 214, 2164-2176, 2018,
[doi:10.1093/gji/ggy235](https://doi.org/10.1093/gji/ggy235).

Data: PANGAEA, [doi:10.1594/PANGAEA.889923](https://doi.org/10.1594/PANGAEA.889923).

## Licence

CC BY 3.0 (PANGAEA).

## Original data

The tab-delimited text of the PANGAEA dataset,
https://doi.pangaea.de/10.1594/PANGAEA.889923?format=textfile (no login), downloaded by
`prepare.jl` (datamanifest key `schumacher2018_gps`): station, longitude, latitude,
vertical velocity and its standard deviation (mm/a).

## Prepare and record

```bash
julia --project=Schumacher2018_gps Schumacher2018_gps/prepare.jl
julia fesmdata.jl record GPS Schumacher2018
```

`prepare.jl` writes
`$FESMDATA_PREPARED/Schumacher2018_gps/Schumacher2018_GPS.nc` (see
`Records/README.md`), one value per station (featureType point, dimension `station`):
`uplift_rate` and `uplift_rate_sd` (mm yr-1), `lat`, `lon` and `site_name`.

All stations are kept, as records are not split by domain; the v1 file
`schumacher2018_GR.nc` had the 54 stations in the Greenland domain (GRL-8KM), with the
cell indices of that grid.
