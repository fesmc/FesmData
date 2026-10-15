# Sea level from benthic foraminifera, 430 kyr (Waelbroeck et al., 2002)

Global mean sea level and mean ocean δ18O derived from benthic foraminiferal δ18O, every
1.5 kyr over the last 430 kyr. From:

Waelbroeck, C., Labeyrie, L., Michel, E., Duplessy, J. C., McManus, J. F., Lambeck, K.,
Balbon, E., and Labracherie, M.: Sea-level and deep water temperature changes derived
from benthic foraminifera isotopic records, Quat. Sci. Rev., 21, 295-305, 2002,
[doi:10.1016/S0277-3791(01)00101-9](https://doi.org/10.1016/S0277-3791(01)00101-9).

Data: Sea-level and Deep Water Temperature 430KYr Reconstructions, NOAA NCEI,
[doi:10.25921/08dt-1228](https://doi.org/10.25921/08dt-1228).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publication and
the dataset. We assume the data may be published.

## Original data

`waelbroeck2002.txt` (free-text NOAA file), downloaded by `prepare.jl` (datamanifest key
`waelbroeck2002_sealevel`), its table 1: age (cal. ka BP; 14C then SPECMAP, adjusted at
Termination II to coral U-Th dates), mean ocean δ18O and its range (‰ SMOW), relative sea
level and its range (m), and three alternate age models. Table 2 (deep-water
temperatures) is not used.

## Prepare and record

```bash
julia --project=Waelbroeck2002_sealevel Waelbroeck2002_sealevel/prepare.jl
julia fesmdata.jl record SeaLevel Waelbroeck2002
```

`prepare.jl` writes `$FESMDATA_PREPARED/Waelbroeck2002_sealevel/Waelbroeck2002_sealevel.nc`
(see `Records/README.md`), a global series (dimension `region`, no location) of 287
values: `sl`, `sl_min`, `sl_max` (m), `d18O_sw`, `d18O_sw_min`, `d18O_sw_max` (‰), and
`time_alt1`, `time_alt2`, `time_alt3` (alternate age models).

Notes:

- The header calls the sea level "m below present sea level", but the values are
  negative when lower: they are used as given (relative to the present).
- RSL- is the shallower bound (`sl_max`) and RSL+ the deeper (`sl_min`).
