# RSL: relative sea level indicators

Dated relative sea level indicators (index points and limiting data). RSL is a records
dataset (non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)): its products,
defined in `RSL/records.toml`, are prepared files in the form of the CF discrete
sampling geometries, written to `$FESMDATA/Records/RSL/RSL-<product>.nc`.

## Products

| Product | Source | Region | Variables |
|---|---|---|---|
| `RSL-GAPSLIP` | GAPSLIP 2.1 (Gowan, 2023), [doi:10.5281/zenodo.10121689](https://doi.org/10.5281/zenodo.10121689) | Greenland: 1019 samples at 47 locations, up to 44 ka | `rsl`, `rsl_min`, `rsl_max` (m, 2σ), `type` (marine limiting, index point, terrestrial limiting), `time`, `time_min`, `time_max` (years ago, 2σ), `lab_id`, `site_name`, `sector`, `reference` |
| `RSL-GAPSLIP_global` | GAPSLIP 2.1 (Gowan, 2023), [doi:10.5281/zenodo.10121689](https://doi.org/10.5281/zenodo.10121689), the database used to evaluate PaleoMIST 1.0 (Gowan et al., 2021) | All regions of GAPSLIP (North America, Greenland, Europe and the Eurasian Arctic, Asia, Australia, the Pacific, Antarctica): 9979 samples at 290 locations in 12 regions (8843 primary), 83 % younger than 15 ka, some to 440 ka | as `RSL-GAPSLIP`, and `region`, `site`, `alternative` (1: another interpretation or uplift correction of the samples of `site`) |
| `RSL-GAPSLIP_proxy` | GAPSLIP 2.1 (Gowan, 2023), [doi:10.5281/zenodo.10121689](https://doi.org/10.5281/zenodo.10121689), its region `Proxy_Based_Sea_Level` | Two proxy records as site RSL: the Red Sea at Bab-el-Mandeb (Grant et al., 2012, 2014; 1927 index points, 0-500 ka, a continuous record) and the Karimata Strait (Weiss et al., 2022; 14 terrestrial-limiting samples, 60-32 ka) | as `RSL-GAPSLIP_global` |

Each sample is an observation (featureType point, dimension `obs`) with its `lat`,
`lon` and `time` in years before 1950 CE (units "years ago", calibrated ages).

## Licences

| Source | Licence |
|---|---|
| GAPSLIP 2.1 (Gowan, 2023) | CC BY-SA 4.0 (repository; the Zenodo record states CC BY 4.0), all three products |

## Making the dataset

```bash
julia fesmdata.jl record RSL
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA/Records/RSL/` (`--overwrite` to replace them).
