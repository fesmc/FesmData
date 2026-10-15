# Sea level and ice sheet volumes, 5.3 Myr (Rohling et al., 2021)

Sea level and the volumes of the Laurentide, Eurasian, Antarctic and Greenland ice
sheets, with the ice-volume and temperature components of the benthic δ18O, every 1 kyr
over the last 5.3 Myr on the LR04 stack (main regression). From:

Rohling, E. J., Yu, J., Heslop, D., Foster, G. L., Opdyke, B., and Roberts, A. P.: Sea
level and deep-sea temperature reconstructions suggest quasi-stable states and critical
transitions over the past 40 million years, Sci. Adv., 7, eabf5326, 2021,
[doi:10.1126/sciadv.abf5326](https://doi.org/10.1126/sciadv.abf5326).

Data: NOAA NCEI, [doi:10.25921/rq2y-4k67](https://doi.org/10.25921/rq2y-4k67).

## Licence

NOAA NCEI open data, no licence stated (the article is CC BY 4.0). We assume the data may
be published.

## Original data

`rohling2021-lr-main.txt` (NOAA template), downloaded by `prepare.jl` (datamanifest key
`rohling2021_sealevel`): time (ka, negative in the past), the LR04 δ18O, sea level (m
relative to the present), the ice volumes of the four ice sheets (m sea level equivalent,
positive totals), their mean δ18O, the ice-volume and temperature δ18O changes (‰) and the
deep-sea temperature change (°C). The files of the 95% bound (a single bound) and of the
version on the record of Westerhold et al. (2020, 40 Myr) are not used.

## Prepare and record

```bash
julia --project=Rohling2021_sealevel Rohling2021_sealevel/prepare.jl
julia fesmdata.jl record SeaLevel Rohling2021
```

`prepare.jl` writes `$FESMDATA_PREPARED/Rohling2021_sealevel/Rohling2021_sealevel.nc` (see
`Records/README.md`), a global series (dimension `region`, no location) of 5301 values,
sorted forward in age: `sl`, `sl_lis`, `sl_eis`, `sl_ais`, `sl_gris` (m),
`d18O_benthic`, `d18O_sw`, `d18O_temp` (‰), `t_deep_anom` (K). The contributions of the
ice sheets are minus the changes of their volumes from the present (negative when sea
level is lower). The mean δ18O of the ice sheets are not kept.
