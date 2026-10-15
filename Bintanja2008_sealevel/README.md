# Sea level, ice volume and temperature, 3 Myr (Bintanja and van de Wal, 2008)

Global sea level, the ice volume of the North American and Eurasian ice sheets, Northern
Hemisphere and deep-water temperatures, every 100 years over the last 3 Myr, from the
inverse modelling of the LR04 benthic δ18O stack with ice-sheet models. From:

Bintanja, R. and van de Wal, R. S. W.: North American ice-sheet dynamics and the onset of
100,000-year glacial cycles, Nature, 454, 869-872, 2008,
[doi:10.1038/nature07158](https://doi.org/10.1038/nature07158).

Data: 3 Million Year Temperature, Sea Level, and Ice Volume Reconstructions, NOAA NCEI,
[doi:10.25921/revb-da37](https://doi.org/10.25921/revb-da37).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publication and
the dataset. We assume the data may be published.

## Original data

`bintanja2008-noaa.txt` (NOAA template), downloaded by `prepare.jl` (datamanifest key
`bintanja2008_sealevel`): age (ka BP), the modelled benthic δ18O and its ice and
temperature contributions (‰, relative to the present), the temperature anomalies of
Northern Hemisphere land (40-80°N) and of the deep water (°C), the Eurasian and North
American ice volumes (m sea level equivalent, relative to the present) and the sea level
(m, lowering positive). The 1 Myr reconstruction of Bintanja et al. (2005) is not used.

## Prepare and record

```bash
julia --project=Bintanja2008_sealevel Bintanja2008_sealevel/prepare.jl
julia fesmdata.jl record SeaLevel Bintanja2008
```

`prepare.jl` writes `$FESMDATA_PREPARED/Bintanja2008_sealevel/Bintanja2008_sealevel.nc`
(see `Records/README.md`), a global series (dimension `region`, no location) of 30001
values: `sl`, `sl_nam`, `sl_eas` (m), `tas_anom_nh`, `t_deep_anom` (K), `d18O_benthic`,
`d18O_ice`, `d18O_temp` (‰). The sea level and the ice volumes change sign (negative when
sea level is lower); the values at present are kept (`sl` = -1.46 m).
