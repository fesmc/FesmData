# AICC2023 ice core chronology (Bouchet et al., 2023)

Depth-age tables of the Antarctic Ice Core Chronology 2023 for EDC, EDML, TALDICE,
Vostok and NGRIP: ice and gas ages on AICC2023 with their uncertainties, the ages on
AICC2012, and the accumulation rate, thinning and lock-in depth of the analysis. From:

Bouchet, M., Landais, A., Grisart, A., Parrenin, F., Prié, F., Jacob, R., Fourré, E.,
Capron, E., Raynaud, D., Lipenkov, V. Y., Loutre, M.-F., Extier, T., Svensson, A.,
Legrain, E., Martinerie, P., Leuenberger, M., Jiang, W., Ritterbusch, F., Lu, Z.-T., and
Yang, G.-M.: The Antarctic Ice Core Chronology 2023 (AICC2023) chronological framework
and associated timescale for the European Project for Ice Coring in Antarctica (EPICA)
Dome C ice core, Clim. Past, 19, 2257-2286, 2023,
[doi:10.5194/cp-19-2257-2023](https://doi.org/10.5194/cp-19-2257-2023).

Data: Bouchet, M. et al.: The Antarctic ice core chronology (AICC2023), PANGAEA,
[doi:10.1594/PANGAEA.961017](https://doi.org/10.1594/PANGAEA.961017).

## Licence

CC BY 4.0 (PANGAEA).

## Original data

The tab-delimited text of the PANGAEA tables (no login), one per core, downloaded by
`prepare.jl` (datamanifest keys `aicc2023_<core>`):

| Core | PANGAEA | Depths | Bottom age (AICC2023) |
|---|---|---|---|
| EDC | [990377](https://doi.org/10.1594/PANGAEA.990377) | 0-3192.75 m, every 0.55 m | 813 ka |
| EDML | [990380](https://doi.org/10.1594/PANGAEA.990380) | 18-2416 m, every 1 m | 145 ka |
| NGRIP | [990383](https://doi.org/10.1594/PANGAEA.990383) | 8-3082 m, every 1 m | 125 ka |
| TALDICE | [990384](https://doi.org/10.1594/PANGAEA.990384) | 0-1597 m, every 1 m | 492 ka |
| Vostok | [990385](https://doi.org/10.1594/PANGAEA.990385) | 0-3272 m, every 1 m | 408 ka |

These are version 2 of the tables (2026), which corrects the AICC2012 ages of the first
version (PANGAEA 961018-961022). The bundle also has a table of WAIS Divide-EDC tie
points (990386), not used here.

## Prepare and record

```bash
julia --project=Bouchet2023_AICC2023 Bouchet2023_AICC2023/prepare.jl
julia fesmdata.jl record IceCores AICC2023
```

`prepare.jl` writes `$FESMDATA_PREPARED/Bouchet2023_AICC2023/AICC2023_<core>.nc` (see
`Records/README.md`), a profile at the site of the core along `depth` (m, featureType
profile), with `site_name`, `lat`, `lon` and `z_srf` from the PANGAEA event:

- `age_ice_aicc2023`, `age_gas_aicc2023` (years ago, before 1950 CE) and their
  uncertainties `age_ice_aicc2023_sd`, `age_gas_aicc2023_sd` (yr); `delta_age_sd` (yr),
  the uncertainty of the ice-gas age difference;
- `age_ice_aicc2012`, `age_gas_aicc2012` (years ago), the ages on AICC2012 (missing
  beyond the range of AICC2012, e.g. the bottom of TALDICE);
- `acc`, `acc_sd` (kg m-2 yr-1, from m ice yr-1 with an ice density of 917 kg m-3),
  `thinning`, `thinning_sd`, `lid`, `lid_sd` (lock-in depth, m), `delta_depth`,
  `delta_depth_sd` (depth difference between ice and gas of the same age, m).

Ages in ka are converted to years. The gas ages are missing near the surface (above the
lock-in depth).

These files also give the AICC2023 ages of the other ice core records: `aicc2023_age`
of `shared/records_prepare.jl` interpolates the ice or gas age linearly in depth (and
prepares this source first if needed).
