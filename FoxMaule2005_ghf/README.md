# Geothermal heat flow from satellite magnetic data (Fox Maule et al., 2005)

Geothermal heat flow of Antarctica and of the land north of 55°N (Greenland, northern
North America and Eurasia), and the magnetic crustal thickness north of 55°N, derived
from satellite magnetic data with the method of:

Fox Maule, C., Purucker, M. E., Olsen, N. and Mosegaard, K.: Heat flux anomalies in
Antarctica revealed by satellite magnetic data, Science, 309, 464-467, 2005,
[doi:10.1126/science.1106888](https://doi.org/10.1126/science.1106888).

The data are the update by M. Purucker (NASA GSFC) with the MF7 magnetic field model
(CHAMP), which also extends the map to Greenland and the northern high latitudes
(Fox Maule, C., Purucker, M. E. and Olsen, N.: Inferring magnetic crustal thickness
and geothermal heat flux from crustal magnetic field models, Danish Climate Centre
Report 09-09, 2009). The magnetic crustal thickness is the depth to the bottom of
the magnetic layer, taken as the Curie isotherm (580 °C), from which the heat flow is
computed with a thermal model of the crust.

## Licence

No licence stated. The web page asks users to cite Fox Maule et al. (2005). We assume
we may publish.

## Original data

Three files (lon, lat, value) from Purucker's page
`core2.gsfc.nasa.gov/research/purucker/heatflux_updates.html`, which is offline; they
are downloaded by `prepare.jl` from the Wayback Machine (snapshots of 2016, identical to
the copies in the old PIK archive, `hpc:/data/sicopolis/data/GeothermalHeatFlux/`):

| Datamanifest key | File | Content |
|---|---|---|
| `foxmaule2005_ghf` | `heatflux_mf7_foxmaule05.txt` | heat flow (mW m-2), Antarctica (87-63°S) and Greenland (61.5-84°N) |
| `foxmaule2005_ghf_npolar` | `heatflux_mf7_foxmaule05_npolar.txt` | heat flow (mW m-2), land 55.5-84°N |
| `foxmaule2005_mct_npolar` | `mct_mf7_foxmaule05_npolar.txt` | magnetic crustal thickness (km), land 55.5-84°N |

The Greenland points of the first file are also in the second, with the same values,
so only its Antarctic points are used.

## Prepare and remap

```bash
julia --project=FoxMaule2005_ghf FoxMaule2005_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/FoxMaule2005_ghf/FoxMaule2005_GHF.nc Antarctica Greenland --name=GHF-FoxMaule2005
```

`prepare.jl` writes `ghf` (mW m-2) and `h_mag` (magnetic crustal thickness, km, north
of 55°N only) to `$FESMDATA_WORK/prepared/FoxMaule2005_ghf/FoxMaule2005_GHF.nc` (see
`Remap/README.md`). The GHF product remaps only `ghf`.

The data are points of an equal-area grid: rings 1.5° apart in latitude (about
170 km), with points about as far apart in longitude. They are put on a regular
lon-lat grid of 1.5° (the rings) by 0.1°, each cell taking the value of the nearest
point of its ring (within half the point spacing), so that each point fills its own
equal-area cell; nothing is interpolated (`shared/ringgrid.jl`). The data cover land
only: the ocean is missing. The southernmost ring is at 87°S, so the polar cap south
of 87.75°S (about 250 km around the South Pole) has no data.

The v1 file `GRL-16KM_GHF-M05.nc` (gridding/GeothermalHeatFlux.f90) was made from the
crustal thickness file, not from the heat flow: its `ghf` is the magnetic crustal
thickness in km.
