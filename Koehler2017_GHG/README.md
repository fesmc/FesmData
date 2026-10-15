# CO2, CH4 and N2O splines and radiative forcing, 156 kyr (Köhler et al., 2017)

Spline-smoothed atmospheric CO2, CH4 and N2O, with their radiative forcing, every year
from 2016 CE back to 156 ka (N2O to 135 ka), from ice cores, firn and atmospheric
measurements. From:

Köhler, P., Nehrbass-Ahles, C., Schmitt, J., Stocker, T. F., and Fischer, H.: A 156 kyr
smoothed history of the atmospheric greenhouse gases CO2, CH4, and N2O and their
radiative forcing, Earth Syst. Sci. Data, 9, 363-387, 2017,
[doi:10.5194/essd-9-363-2017](https://doi.org/10.5194/essd-9-363-2017).

Data: PANGAEA, [doi:10.1594/PANGAEA.871273](https://doi.org/10.1594/PANGAEA.871273).

## Licence

CC BY 3.0 (PANGAEA).

## Original data

The version 2 splines (revised 2017-06-08, which replace version 1), the tab-delimited
text of three PANGAEA datasets, downloaded by `prepare.jl` (datamanifest keys
`koehler2017_co2`, `koehler2017_ch4`, `koehler2017_n2o`):

| Gas | PANGAEA | Columns |
|---|---|---|
| CO2 | [876013](https://doi.org/10.1594/PANGAEA.876013) | age (ka BP), CO2 (µmol/mol = ppm), 1σ, ΔR (W m-2), 1σ |
| CH4 | [876009](https://doi.org/10.1594/PANGAEA.876009) | age, CH4 (nmol/mol = ppb), 1σ, ΔR, 1σ |
| N2O | [876014](https://doi.org/10.1594/PANGAEA.876014) | age, N2O (ppb), 1σ, ΔR, 1σ |

The radiative forcing is relative to the preindustrial values: 5.35 ln(CO2/278),
1.4 × 0.036 (√CH4 − √742), 0.12 (√N2O − √272). The CH4 spline is of the Southern
Hemisphere (Antarctic ice cores). The ice core ages are on AICC2012 (EDC, EDML,
TALDICE), WD2014 (WAIS Divide) and GICC05 (NGRIP). The raw and pre-processed data of
the same collection are not used.

## Prepare and record

```bash
julia --project=Koehler2017_GHG Koehler2017_GHG/prepare.jl
julia fesmdata.jl record GHG Koehler2017
```

`prepare.jl` writes `$FESMDATA_PREPARED/Koehler2017_GHG/Koehler2017_GHG.nc` (see
`Records/README.md`), a global series (featureType timeSeries, dimension `region`, no
location) every year from -66 to 156306 years before 1950 CE: `co2` (ppm), `ch4`, `n2o`
(ppb), `rf_co2`, `rf_ch4`, `rf_n2o` (W m-2), each with its `_sd` (1σ); CH4 and N2O are
missing beyond their records (156211 and 134519 years).
