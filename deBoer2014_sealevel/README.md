# Sea level and ice sheet contributions, 5.3 Myr (de Boer et al., 2014)

Eustatic sea level and the ice volumes of the Eurasian, North American, Antarctic and
Greenland ice sheets, every 100 years over the last 5.3 Myr, from the inverse modelling
of the LR04 benthic δ18O stack with the ANICE ice-sheet models. From:

de Boer, B., Lourens, L. J., and van de Wal, R. S. W.: Persistent 400,000-year
variability of Antarctic ice volume and the carbon cycle is revealed throughout the
Plio-Pleistocene, Nat. Commun., 5, 2999, 2014,
[doi:10.1038/ncomms3999](https://doi.org/10.1038/ncomms3999).

Data: 5 Myr Global Sea Level, Ice Volume, and Temperature Reconstructions, NOAA NCEI,
[doi:10.25921/xs31-nt56](https://doi.org/10.25921/xs31-nt56) (also PANGAEA,
doi:10.1594/PANGAEA.855850, CC BY 3.0).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publication and
the dataset. We assume the data may be published.

## Original data

`deboer2014-noaa.txt` (NOAA template, -999 for missing values), downloaded by
`prepare.jl` (datamanifest key `deboer2014_sealevel`): age (ka BP, from 5300 ka to the
present), the modelled benthic δ18O and its ice-volume and temperature contributions
(‰), the eustatic sea level relative to the present (m), the Northern Hemisphere
temperature anomaly (40-80°N, °C), the total ice volumes of the four ice sheets (m sea
level equivalent, negative), the Antarctic ice volume (10⁶ km³) and ice discharge
(Gt yr-1).

## Prepare and record

```bash
julia --project=deBoer2014_sealevel deBoer2014_sealevel/prepare.jl
julia fesmdata.jl record SeaLevel deBoer2014
```

`prepare.jl` writes `$FESMDATA_PREPARED/deBoer2014_sealevel/deBoer2014_sealevel.nc` (see
`Records/README.md`), a global series (dimension `region`, no location) of 53001 values,
sorted forward in age: `sl`, `sl_eis`, `sl_nais`, `sl_ais`, `sl_gris` (m),
`tas_anom_nh` (K), `d18O_benthic`, `d18O_sw`, `d18O_temp` (‰), `V_ais` (10⁶ km³),
`D_ais` (Gt yr-1). The contributions of the ice sheets are the changes of their volumes
from the present, with the sign of the source (negative when sea level is lower); they
add up to about `sl`.
