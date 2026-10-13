# RSL: relative sea level indicators

Dated relative sea level indicators (index points and limiting data). RSL is a records
dataset (non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)): its products,
defined in `RSL/records.toml`, are prepared files in the form of the CF discrete
sampling geometries, written to `$FESMDATA_PRODUCTS/Records/RSL/RSL-<product>.nc`.

## Products

| Product | Source | Region | Variables |
|---|---|---|---|
| `RSL-GAPSLIP` | GAPSLIP 2.1 (Gowan, 2023), [doi:10.5281/zenodo.10121689](https://doi.org/10.5281/zenodo.10121689) | Greenland: 1019 samples at 47 locations, up to 44 ka | `rsl`, `rsl_min`, `rsl_max` (m, 2σ), `type` (marine limiting, index point, terrestrial limiting), `time`, `time_min`, `time_max` (years ago, 2σ), `lab_id`, `site_name`, `sector`, `reference` |

Each sample is an observation (featureType point, dimension `obs`) with its `lat`,
`lon` and `time` in years before 1950 CE (units "years ago", calibrated ages).

## Licences

| Source | Licence |
|---|---|
| GAPSLIP 2.1 (Gowan, 2023) | CC BY-SA 4.0 (repository; the Zenodo record states CC BY 4.0) |

## Making the dataset

```bash
julia fesmdata.jl record RSL
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA_PRODUCTS/Records/RSL/` (`--overwrite` to replace them).
