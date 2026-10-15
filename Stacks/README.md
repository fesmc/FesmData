# Stacks: benthic δ18O stacks

Global stacks of benthic foraminiferal δ18O, the reference of the ice volume and deep-sea
temperature over glacial cycles and the age model of many reconstructions. Stacks is a
records dataset (non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)): its products,
defined in `Stacks/records.toml`, are prepared files in the form of the CF discrete
sampling geometries, written to `$FESMDATA_PRODUCTS/Records/Stacks/Stacks-<product>.nc`,
each with its text form (`.txt`).

## Products

| Product | Source | Variables | Time |
|---|---|---|---|
| `Stacks-LR04` | Lisiecki and Raymo (2005): stack of 57 records, [doi:10.25921/k88j-0106](https://doi.org/10.25921/k88j-0106) | `d18O_benthic`, `d18O_benthic_sd` (standard error) (‰) | 0-5.32 Ma (1 kyr to 600 ka, then 2, 2.5 and 5 kyr) |
| `Stacks-ProbStack` | Ahn et al. (2017): probabilistic stack of 180 records, [doi:10.1093/climsys/dzx002](https://doi.org/10.1093/climsys/dzx002) | `d18O_benthic`, `d18O_benthic_sd`, `d18O_benthic_min`, `d18O_benthic_max` (95%) (‰) | 0-5 Ma (as LR04) |

Both are series of the region "global" without a location (featureType timeSeries,
dimension `region`, `lat` and `lon` missing). `time` is in years before 1950 CE (units
"years ago") on the age model of the stack.

## Licences

| Source | Licence |
|---|---|
| Lisiecki and Raymo (2005) | NOAA NCEI open data, no licence stated; publishing assumed to be allowed (also on PANGAEA, CC BY 3.0) |
| Ahn et al. (2017) | GPL-3.0 (repository of the authors) |

## Making the dataset

```bash
julia fesmdata.jl record Stacks
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA_PRODUCTS/Records/Stacks/` with their text forms (`--overwrite`
to replace them).
