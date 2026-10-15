# Red Sea relative sea level, 492 kyr (Grant et al., 2014)

Relative sea level of the Red Sea (at the Hanish Sill), a record of global sea level, over
the last 492 kyr: the probabilistic record every 125 years with its 95% intervals and
rate of change, and the data points. From:

Grant, K. M., Rohling, E. J., Ramsey, C. B., Cheng, H., Edwards, R. L., Florindo, F.,
Heslop, D., Marra, F., Roberts, A. P., Tamisiea, M. E., and Williams, F.: Sea-level
variability over five glacial cycles, Nat. Commun., 5, 5076, 2014,
[doi:10.1038/ncomms6076](https://doi.org/10.1038/ncomms6076); with the chronology of
Grant et al. (2012, [doi:10.1038/nature11593](https://doi.org/10.1038/nature11593)) for
0-150 ka.

## Licence

Supplementary Data 1 of the article (Springer Nature): no open licence stated. We assume
the data may be published.

## Original data

`41467_2014_BFncomms6076_MOESM1342_ESM.xlsx` (Supplementary Data 1), downloaded by
`prepare.jl` (datamanifest key `grant2014_redsea`), one sheet: the age (ka BP) and RSL
(m) of the data points, and the probabilistic record: time (ka), the 95% interval of the
data, the probability maximum with its 95% interval, and the rate of change (m kyr-1) with
its 95% interval. The description of the sheet swaps the labels of the bounds of the
probability maximum: the column RSL_Pmax95high_m is the upper bound (checked).

## Prepare and record

```bash
julia --project=Grant2014_RedSea Grant2014_RedSea/prepare.jl
julia fesmdata.jl record SeaLevel Grant2014
```

`prepare.jl` writes two files in `$FESMDATA_PREPARED/Grant2014_RedSea/` (see
`Records/README.md`), time series at the Hanish Sill (13.7°N, 42.7°E; featureType
timeSeries), the two parts of the product:

- `Grant2014_RedSea_probabilistic.nc`: 3937 values every 125 years: `rsl`, `rsl_min`,
  `rsl_max`, `rsl_data_min`, `rsl_data_max` (m), `drsl`, `drsl_min`, `drsl_max`
  (m kyr-1);
- `Grant2014_RedSea_data.nc`: the 1928 data points sorted by age (dimension `sample`):
  `rsl` (m).
