# GHG: greenhouse gases from ice cores

Atmospheric CO2, CH4 and N2O over glacial cycles, from Antarctic ice cores: the records
of EPICA Dome C, a composite of several cores, and spline-smoothed series with their
radiative forcing. GHG is a records dataset (non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)): its products,
defined in `GHG/records.toml`, are prepared files in the form of the CF discrete
sampling geometries, written to `$FESMDATA/Records/GHG/GHG-<product>.nc`, each
with its text form (`.txt`).

## Products

| Product | Source | Site or region | Variables | Time |
|---|---|---|---|---|
| `GHG-Bereiter2015` | Bereiter et al. (2015): revised Antarctic CO2 composite, [doi:10.25921/n8y4-bp27](https://doi.org/10.25921/n8y4-bp27) | Antarctic ice cores (composite) | `co2`, `co2_sd` (ppm) | 0-806 ka, 1901 values (gas ages, mostly AICC2012) |
| `GHG-Loulergue2008` | Loulergue et al. (2008): EPICA Dome C methane, [doi:10.25921/gfsj-jc86](https://doi.org/10.25921/gfsj-jc86) | EDC | `ch4`, `ch4_sd` (ppb), `lab`, `depth` | 0-799 ka, 2103 values (EDC3 gas age; also AICC2023) |
| `GHG-Schilt2010` | Schilt et al. (2010): EPICA Dome C nitrous oxide, [doi:10.1016/j.quascirev.2009.03.011](https://doi.org/10.1016/j.quascirev.2009.03.011) | EDC | `n2o`, `n2o_artifact`, `n2o_sd` (ppb), `depth` | 0-798 ka, 912 values (EDC3 gas age; also AICC2023) |
| `GHG-Koehler2017` | Köhler et al. (2017): spline-smoothed CO2, CH4 and N2O and their radiative forcing, [doi:10.1594/PANGAEA.871273](https://doi.org/10.1594/PANGAEA.871273) | global | `co2` (ppm), `ch4`, `n2o` (ppb), `rf_co2`, `rf_ch4`, `rf_n2o` (W m-2), each with `_sd` | 2016 CE to 156 ka (N2O to 135 ka), every year |

The records of EDC are time series at the site (featureType timeSeries, dimension
`station`); the composite and the splines are series of a region without a location
(dimension `region`, `region_name`, `lat` and `lon` missing). `time` is in years before
1950 CE (units "years ago"), the gas age on the time scale of the source (in the comment
of `time`). The records of EDC, with depths, also have `time_aicc2023`, the gas age on
AICC2023 (Bouchet et al., 2023) interpolated linearly in depth in the AICC2023 table of
EDC (see IceCores). The composite of Bereiter et al. (2015) has no depths and is kept on
its published ages. Uncertainties `_sd` are 1 sigma.

## Licences

| Source | Licence |
|---|---|
| Bereiter et al. (2015), Loulergue et al. (2008), Schilt et al. (2010) | NOAA NCEI open data, no licence stated; publishing assumed to be allowed |
| Köhler et al. (2017) | CC BY 3.0 (PANGAEA) |

## Making the dataset

```bash
julia fesmdata.jl record GHG
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA/Records/GHG/` with their text forms (`--overwrite`
to replace them).
