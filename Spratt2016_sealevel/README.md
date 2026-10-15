# Sea-level stacks of the last 798 kyr (Spratt and Lisiecki, 2016)

Two stacks of global sea level: the scaled first principal component of seven
reconstructions from 0 to 430 ka, and of five from 0 to 798 ka, every 1 kyr on the LR04
age model, with their uncertainties. From:

Spratt, R. M. and Lisiecki, L. E.: A Late Pleistocene sea level stack, Clim. Past, 12,
1079-1092, 2016, [doi:10.5194/cp-12-1079-2016](https://doi.org/10.5194/cp-12-1079-2016).

Data: Late Pleistocene Sea Level Stack, NOAA NCEI,
[doi:10.25921/rd66-5820](https://doi.org/10.25921/rd66-5820) (the same values are on
PANGAEA, doi:10.1594/PANGAEA.979830, CC BY 3.0).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publication and
the dataset. We assume the data may be published.

## Original data

`spratt2016-noaa.txt` (NOAA template), downloaded by `prepare.jl` (datamanifest key
`spratt2016_sealevel`): age (ka BP), and for each stack the sea level (m above the
present), its 1σ uncertainty (bootstrap) and the bounds of the 95% confidence interval.

## Prepare and record

```bash
julia --project=Spratt2016_sealevel Spratt2016_sealevel/prepare.jl
julia fesmdata.jl record SeaLevel Spratt2016
```

`prepare.jl` writes `$FESMDATA_PREPARED/Spratt2016_sealevel/Spratt2016_sealevel.nc` (see
`Records/README.md`), a global series (dimension `region`, no location) of 799 values
every 1 kyr: `sl_short` (missing beyond 430 ka), `sl_long` (m), each with `_sd`,
`_min`, `_max`. The stacks are not zero at the present (+8.5 and +9.0 m, an effect of
their scaling; 0 at about 5 ka): the values are kept as given.
