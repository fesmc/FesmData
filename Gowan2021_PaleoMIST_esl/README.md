# Sea level from the ice sheets of PaleoMIST 1.0 (Gowan et al., 2021)

The equivalent sea level of the ice sheets of PaleoMIST 1.0 (North America with
Greenland, Eurasia, Antarctica, Patagonia) every 2.5 kyr from 80 ka to the present, for
the minimal and maximal MIS 3 scenarios of North America, computed from the gridded ice
thickness of the reconstruction. From:

Gowan, E. J., Zhang, X., Khosravi, S., Rovere, A., Stocchi, P., Hughes, A. L. C.,
Gyllencreutz, R., Mangerud, J., Svendsen, J.-I., and Lohmann, G.: A new global ice sheet
reconstruction for the past 80 000 years, Nat. Commun., 12, 1199, 2021,
[doi:10.1038/s41467-021-21469-w](https://doi.org/10.1038/s41467-021-21469-w).

Data: PANGAEA, [doi:10.1594/PANGAEA.905800](https://doi.org/10.1594/PANGAEA.905800). The
gridded reconstruction is IceHistory-PaleoMIST (`../Gowan2021_PaleoMIST1.0`).

## Licence

CC BY 4.0 (PANGAEA).

## Original data

The archive of PaleoMIST 1.0 (3.5 GB, datamanifest key `gowan2021_paleomist`, also used
by `Gowan2021_PaleoMIST1.0`): the ice thickness (`ice_thickness`) of the global 0.25°
grids, `ice_reconstruction/global_grid/reconstruction[_a1]_0.25_degree.nc`, the same as
`H_ice` of IceHistory-PaleoMIST. The suffix `_a1` is the maximal MIS 3 scenario. The
archive has no sea level series by ice sheet that agrees with its grids (below).

## Method

For each ice sheet, the ice volume of its cells of the global grid (cell areas on a
sphere of radius 6371 km; the negative thicknesses next to the margins, left by the
smoothing of the author, set to 0), and its change from the present, converted to
equivalent sea level as in Gowan et al. (2021): total ice volume (not above flotation),
ice density 910 kg m-3, water density 1000 kg m-3 (SELEN's `RHOI`, `RHOW` in
`calc_sl/data.inc`), over the present ocean area, 361 × 10⁶ km². The ice sheets are the
domains of the regional reconstructions (`ice_reconstruction_files/<region>/projection_info.sh`):
Patagonia 80°W-60°W and 57°S-25°S, Antarctica south of 45°S elsewhere, and north of 35°N
North America (with Greenland and Iceland) west of 14°W (10°W north of 62°N) and Eurasia
east of it. The grid has no ice outside them (checked by `prepare.jl`).

## Why not the volume series of the archive

The archive gives, for each regional reconstruction, the ice volume relative to the
present and its equivalent sea level (`ice_reconstruction_files/<region>/volume_sorted.txt`);
their sum is the volume column of Supplementary Table 1 of the paper. These volumes are
lower than the ice thickness grids of the same archive, both the 5 km regional grids
(`thickness/<age>.nc`) and the global grids, mostly in Antarctica. Gowan's calculated
eustatic sea level, from the Stokes coefficients of the SELEN run (`calc_sl/run_eus.sh`,
and the ESL column of Supplementary Table 1), agrees with the grids, not with
`volume_sorted.txt`. Change of the ice volume from the present at 22.5 ka (minimal
scenario), 10⁶ km³:

| | North America | Eurasia | Antarctica | Patagonia | total | ESL (m) |
|---|---|---|---|---|---|---|
| `volume_sorted.txt` (= Suppl. Table 1 volume) | 29.52 | 6.49 | 4.04 | 0.30 | 40.35 | -101.7 |
| 5 km regional thickness grids | 30.30 | 7.10 | 6.56 | 0.31 | 44.27 | -111.6 |
| global 0.25° grid (this product) | 30.14 | 7.05 | 6.51 | 0.31 | 44.01 | -110.9 |
| Gowan's calculated ESL (`run_eus.sh`; Suppl. Table 1) | | | | | | -111.4 |

Over the records, the total of this product differs from Gowan's calculated ESL by -0.5 m
on average and by at most 1.1 m (both scenarios), except at 2.5 ka (1.9 m), where Gowan's
sea-level calculation has no ice change from the present (its input took the present ice
from 2.5 ka). The
first version of this product (SeaLevel v2.0.0) was made from `volume_sorted.txt` and was
about 9 % low (-101.7 m at 22.5 ka, Antarctica -10.2 instead of -16.4 m).

## Prepare and record

```bash
julia --project=Gowan2021_PaleoMIST_esl Gowan2021_PaleoMIST_esl/prepare.jl
julia fesmdata.jl record SeaLevel PaleoMIST PaleoMIST_max
```

`prepare.jl` writes `$FESMDATA_PREPARED/Gowan2021_PaleoMIST_esl/Gowan2021_PaleoMIST_esl.nc`
(minimal MIS 3 scenario) and `Gowan2021_PaleoMIST_max_esl.nc` (maximal), global series
(dimension `region`, no location) of 33 values: `sl_nam`, `sl_eis`, `sl_ais`, `sl_pat`
(m, minus the change of the equivalent sea level of each ice sheet: negative when sea
level is lower) and `sl`, their sum.
