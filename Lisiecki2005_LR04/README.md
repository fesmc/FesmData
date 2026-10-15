# LR04 benthic d18O stack, 5.3 Myr (Lisiecki and Raymo, 2005)

The average of 57 globally distributed benthic δ18O records over the last 5.3 Myr, on an
age model tuned to a simple model of ice volume forced by 21 June insolation at 65°N.
From:

Lisiecki, L. E. and Raymo, M. E.: A Pliocene-Pleistocene stack of 57 globally distributed
benthic δ18O records, Paleoceanography, 20, PA1003, 2005,
[doi:10.1029/2004PA001071](https://doi.org/10.1029/2004PA001071).

Data: LR04 Global Pliocene-Pleistocene Benthic d18O Stack, NOAA NCEI,
[doi:10.25921/k88j-0106](https://doi.org/10.25921/k88j-0106).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publication and
the dataset (also on PANGAEA, doi:10.1594/PANGAEA.701576, CC BY 3.0). We assume the
data may be published.

## Original data

`lisiecki2005-d18o-stack-noaa.txt` (NOAA template), downloaded by `prepare.jl`
(datamanifest key `lisiecki2005_lr04`): age (ka BP), benthic δ18O (‰) and its standard
error (‰), 2115 values every 1 kyr to 600 ka, 2 kyr to 1500 ka, 2.5 kyr to 3000 ka and 5
kyr to 5320 ka. The same file is on the page of the author
(https://lorraine-lisiecki.com/stack.html), with the cores of the stack.

## Prepare and record

```bash
julia --project=Lisiecki2005_LR04 Lisiecki2005_LR04/prepare.jl
julia fesmdata.jl record Stacks LR04
```

`prepare.jl` writes `$FESMDATA_PREPARED/Lisiecki2005_LR04/Lisiecki2005_LR04.nc` (see
`Records/README.md`), a global series (dimension `region`, no location): `d18O_benthic`,
`d18O_benthic_sd` (standard error) (‰).
