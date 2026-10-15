# Sea level from the ice sheets of PaleoMIST 1.0 (Gowan et al., 2021)

The equivalent sea level of the ice sheets of PaleoMIST 1.0 (North America with
Greenland, Eurasia, Antarctica, Patagonia) every 2.5 kyr from 80 ka to the present, for
the minimal and maximal MIS 3 scenarios of North America. From:

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
by `Gowan2021_PaleoMIST1.0`): `ice_reconstruction/ice_reconstruction_files/<region>[_a1]/volume_sorted.txt`,
for each region the ice volume relative to the present (km³ and 10⁶ km³) and its
equivalent sea level (m, for an ocean area of 361 × 10⁶ km² and an ice density of 910 kg
m-3, positive for more ice) every 2.5 kyr. The suffix `_a1` is the maximal MIS 3
scenario. The archive has no global sea level series.

## Prepare and record

```bash
julia --project=Gowan2021_PaleoMIST_esl Gowan2021_PaleoMIST_esl/prepare.jl
julia fesmdata.jl record SeaLevel PaleoMIST PaleoMIST_max
```

`prepare.jl` writes `$FESMDATA_PREPARED/Gowan2021_PaleoMIST_esl/Gowan2021_PaleoMIST_esl.nc`
(minimal MIS 3 scenario) and `Gowan2021_PaleoMIST_max_esl.nc` (maximal), global series
(dimension `region`, no location) of 33 values: `sl_nam`, `sl_eis`, `sl_ais`, `sl_pat`
(m, minus the equivalent sea level of each region: negative when sea level is lower)
and `sl`, their sum.
