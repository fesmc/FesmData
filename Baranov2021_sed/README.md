# Sediment thickness of Antarctica, ANTASed (Baranov et al., 2021)

Sediment thickness of the Antarctic continent (under grounded ice and ice shelves) on a
0.1° (11 km) grid of an azimuthal equidistant projection centred on the South Pole,
from seismic, gravity, radar and magnetic data and the bed topography of BedMachine:

Baranov, A., Morelli, A. and Chuvaev, A.: ANTASed - An updated sediment model for
Antarctica, Front. Earth Sci., 9, 722699, 2021,
[doi:10.3389/feart.2021.722699](https://doi.org/10.3389/feart.2021.722699).

The mean thickness over the continent is 0.77 km, with up to 12.7 km in the
Filchner-Ronne basin.

## Licence

No licence or terms of use are stated for the data file on the web site of IEPT RAS;
the article is published under CC BY 4.0. We assume that derived products may be
published with a citation of Baranov et al. (2021).

## Original data

`0.1_lim_b.dat_.zip` (0.3 MB, no login) from the ANTASed page of IEPT RAS,
<https://www.itpz-ran.ru/en/activity/current-projects/antased-a-new-sediment-model-for-antarctica/>
("Data file"), <https://www.itpz-ran.ru/wp-content/uploads/2021/04/0.1_lim_b.dat_.zip>,
which holds `0.1_lim_b.dat`. It is in `datamanifest.toml` (`antased`) and downloaded
and extracted by `prepare.jl` if missing.

## Prepare and remap

```bash
julia --project=Baranov2021_sed Baranov2021_sed/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Baranov2021_sed/Baranov2021_ANTASed.nc Antarctica --name=Sediment-ANTASed
```

`prepare.jl` writes `z_sed` (m) to
`$FESMDATA_WORK/prepared/Baranov2021_sed/Baranov2021_ANTASed.nc` (see `Remap/README.md`),
missing outside the continent.

`0.1_lim_b.dat` has three columns, x, y and the sediment thickness (km), for the points
of the grid on the continent. The article gives the grid as an azimuthal equidistant
projection centred on the South Pole with a step of 0.1°: x and y are distances from the
pole in degrees of arc, x towards 90°E and y towards 0°E (as in EPSG:3031), from -23.5°
to 24.9° and -19.9° to 20.9°. They are converted to m on a sphere of radius 6371 km,
the radius of the PROJ string of the prepared file
(`+proj=aeqd +lat_0=-90 +lon_0=0 +R=6371000`), so the positions do not depend on it.
On the ANT-16KM grid, the data cover the grounded ice, ice-free land and ice shelves of
BedMachine (all but 22 of 53,114 cells), and their mean, 0.77 km, is that of the article.
