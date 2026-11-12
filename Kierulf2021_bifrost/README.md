# BIFROST2015 GNSS velocities of Fennoscandia (Kierulf et al., 2021)

Velocities of the 164 GNSS stations of the BIFROST2015 network (Fennoscandia, the
Baltic countries, Denmark and northern Central Europe), from the daily GAMIT solutions of
2000.0-2015.0 in ITRF2008, with the modelled elastic deformation over the observation
period of each station. These velocities were also used for the land uplift model
NKG2016LU (Vestøl et al., 2019; `Vestol2019_nkg2016lu`). From:

Kierulf, H. P., Steffen, H., Barletta, V. R., Lidberg, M., Johansson, J., Kristiansen,
O., and Tarasov, L.: A GNSS velocity field for geophysical applications in
Fennoscandia, J. Geodyn., 146, 101845, 2021,
[doi:10.1016/j.jog.2021.101845](https://doi.org/10.1016/j.jog.2021.101845).

The observed vertical velocity is the total vertical land motion (**not corrected**);
the elastic part (`uplift_rate_elastic`, their `sum_t`) is the response to the ice mass
changes of Antarctica, the Greenland ice sheet and its glaciers and the global glaciers
(mostly Svalbard), to hydrology, and atmospheric and non-tidal ocean loading, over the
time span of each station; it is 0.5-1.35 mm/yr at these stations. The GIA estimate is
`uplift_rate - uplift_rate_elastic`.

## Licence

CC BY 4.0: the article is open access under CC BY 4.0, with its supplement.

## Original data

The supplement of the article (`1-s2.0-S0264370721000314-mmc1.zip`, no login),
downloaded and extracted by `prepare.jl` (datamanifest key `kierulf2021_bifrost`):
`BIFROST2015_velocities_final.txt`, with a line of description and one line per station:
code, lat, lon, yrs (length of the series until 2015.0), N, E, U and their RMS and
spectral index, the elastic corrections (ais, gis, ggl, gla, twd, sum_h, atm, nto, sum_t),
the velocities transformed into the frame of their GIA model (`*_fra`) and the velocities
of that model (`*_GIA`), all in mm/yr.

## Prepare and record

```bash
julia --project=Kierulf2021_bifrost Kierulf2021_bifrost/prepare.jl
julia fesmdata.jl record GPS BIFROST2015
```

`prepare.jl` writes `$FESMDATA_PREPARED/Kierulf2021_bifrost/Kierulf2021_BIFROST2015.nc`,
one value per station (featureType point, dimension `station`): `uplift_rate` and
`uplift_rate_sd` (U and U_RMS, mm yr-1), `uplift_rate_elastic` (sum_t, mm yr-1),
`time_start` and `time_end` (2015.0 minus the length of the series, and 2015.0), `lat`,
`lon` and `site_name`. The velocities transformed into the frame of their GIA model and
those of the model are left out: they depend on that model.
