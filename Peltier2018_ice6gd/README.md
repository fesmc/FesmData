# ICE-6G_D (VM5a) ice thickness and topography of Antarctica (Peltier et al., 2018)

Ice thickness, grounded ice thickness and topography of Antarctica (south of 60°S) from
122.5 ka to present (128 time slices), on the Gaussian grid of the model (1024 x 512,
about 0.35°), from the ICE-6G_D (VM5a) glacial isostatic adjustment model, the update of
ICE-6G_C after Purcell et al. (2016):

Peltier, W. R., Argus, D. F. and Drummond, R.: Comment on "An assessment of the
ICE-6G_C (VM5a) glacial isostatic adjustment model" by Purcell et al., J. Geophys. Res.
Solid Earth, 123, 2019-2028, 2018,
[doi:10.1002/2016JB013844](https://doi.org/10.1002/2016JB013844).

The files ask to cite ICE-6G_C: Argus et al. (2014),
[doi:10.1093/gji/ggu140](https://doi.org/10.1093/gji/ggu140), and Peltier et al.
(2015), [doi:10.1002/2014JB011176](https://doi.org/10.1002/2014JB011176) (see
`../Peltier2015_ice6g/README.md`).

## Licence

The data page of W. R. Peltier
(https://www.atmosp.physics.utoronto.ca/~peltier/data.php) has ICE-6G_D only as
present-day rates (uplift, horizontal velocity), not the ice history. The ice history
is in the supporting information of Peltier et al. (2018): `ANT-32KM_ICE-6G_D.nc` of
isostasy_data was made from its Data Set S5 (`jgrb52450-sup-0005-data_s5.nc`, cdo
history), and has the same ice volume as `ICE6GD_IceT.nc` (within 0.03% on ANT-32KM).
The article and its supporting information are published by AGU under the Wiley
standard terms (no open licence): redistributing products derived from them (e.g. a
FesmData release) needs permission from AGU or the authors. The isostasy_data archive
is under CC BY 4.0, a licence set by the archive, not by the authors.

## Original data

The supporting information of the article (Wiley blocks automated downloads; we could
not check which data sets hold `IceG` and `Topo`), e.g.
https://agupubs.onlinelibrary.wiley.com/action/downloadSupplement?doi=10.1002%2F2016JB013844&file=jgrb52450-sup-0005-data_s5.nc.
We use the copies in the isostasy_data repository (J. Swierczek-Jereczek, for
FastIsostasy, Swierczek-Jereczek et al., 2024, doi:10.5194/gmd-17-5263-2024):
`ice_history/ICE6G_D/ICE6GD_<IceT|IceG|Topo>.nc` of isostasy_data v0.2.0
(Swierczek-Jereczek, 2024,
[doi:10.5281/zenodo.11175418](https://doi.org/10.5281/zenodo.11175418), no login; also
https://github.com/JanJereczek/isostasy_data), entry `isostasy_data_v0_2` of
`../datamanifest.toml`, downloaded and extracted by `prepare.jl`: `IceT` (ice
thickness), `IceG` (grounded ice thickness) and `Topo` (topography: bedrock altitude
plus grounded ice thickness, bathymetry in the ocean), in m, on Lon 0:360/1024:359.6,
the 86 southernmost latitudes of the 512 Gaussian latitudes (89.73°S to 59.88°S) and
Time (ka BP, 122.5 to -0.25).

## Prepare and remap

```bash
julia --project=Peltier2018_ice6gd Peltier2018_ice6gd/prepare.jl
julia fesmdata.jl remap IceHistory ICE6G_D
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Peltier2018_ice6gd/Peltier2018_ICE6G_D.nc`
(see `Remap/README.md`) with the dimension `time` (years ago, i.e. before 1950 CE,
oldest first; the source gives ka BP) and

- `H_ice` (m): ice thickness (`IceT`);
- `H_ice_grounded` (m): grounded ice thickness (`IceG`);
- `z_topo` (m): topography (`Topo`), the ice or land surface where the ice is
  grounded or on land, and the sea floor in the ocean and under ice shelves.

The longitudes are reordered to -180:180, and the cell edges of the Gaussian latitudes
are written as `lat_bnds` (from the Gauss weights; the latitudes of the files differ
from the exact Gaussian latitudes by up to 0.0002°). The last time slice, -250 years
ago (250 years after present), is kept: its ice thickness is that of the present, its
grounded ice and topography differ.
