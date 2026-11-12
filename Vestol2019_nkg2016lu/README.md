# Land uplift model NKG2016LU of Fennoscandia (Vestøl et al., 2019)

The official land uplift model of the Nordic Geodetic Commission (NKG) for Fennoscandia
and the Baltic region: the absolute uplift NKG2016LU_abs (relative to the Earth's
centre of mass, ITRF2008) and its standard uncertainty, on a grid of 1/12° x 1/6° over
49-75°N, 0-50°E (313 x 301 nodes). It is semi-empirical: a model of the uplift rates of
the GNSS stations of BIFROST (ITRF2008, about 170 stations; see `Kierulf2021_bifrost`),
precise levelling and tide gauges, with a GIA model (NKG2016GIA_prel0306) that fills the
gaps between the observations and extends the model outside them (where the uncertainty
grows from about 0.2 to 0.7 mm/yr). The GNSS rates are not corrected for the elastic
response to present ice and water changes (**elastic part not removed**; 0.5-1.35
mm/yr at the BIFROST stations, Kierulf et al., 2021). From:

Vestøl, O., Ågren, J., Steffen, H., Kierulf, H., and Tarasov, L.: NKG2016LU: a new land
uplift model for Fennoscandia and the Baltic Region, J. Geod., 93, 1759-1779, 2019,
[doi:10.1007/s00190-019-01280-8](https://doi.org/10.1007/s00190-019-01280-8).

The levelled uplift NKG2016LU_lev (relative to the geoid) and the gravity change
NKG2016LU_gdot are not prepared.

## Licence

CC BY 4.0: Lantmäteriet distributes NKG2016LU under CC BY 4.0
(<https://www.lantmateriet.se/sv/geodata/gps-geodesi-och-swepos/referenssystem/landhojning/>).

## Original data

`nkg2016lu-with-readme.zip` of Lantmäteriet (no login), downloaded and extracted by
`prepare.jl` (datamanifest key `vestol2019_nkg2016lu`): the grids NKG2016LU_abs,
NKG2016LU_lev and NKG2016LU_StdUnc in three formats (Gravsoft ASCII `.gri` and binary
`.bin`, and lines of latitude, longitude, value in `.dat`), with a readme, the
description of the Gravsoft format and a presentation of the model. `prepare.jl` reads
the `.dat` files of NKG2016LU_abs and NKG2016LU_StdUnc (mm/a).

## Prepare

```bash
julia --project=Vestol2019_nkg2016lu Vestol2019_nkg2016lu/prepare.jl
julia fesmdata.jl remap SolidEarth NKG2016LU
```

`prepare.jl` writes `$FESMDATA_PREPARED/Vestol2019_nkg2016lu/Vestol2019_NKG2016LU.nc` on
the grid of the model (nodes as cell centres, `lon`, `lat`): `uplift_rate` (NKG2016LU_abs)
and `uplift_rate_sd` (NKG2016LU_StdUnc), in mm yr-1. The model covers the sea and the land
of its grid alike.
