# Orbital: orbital elements and insolation

The orbital elements of the Earth and insolation series computed from them, the forcing
of glacial cycles. Orbital is a records dataset (non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)): its products,
defined in `Orbital/records.toml`, are prepared files in the form of the CF discrete
sampling geometries, written to `$FESMDATA_PRODUCTS/Records/Orbital/Orbital-<product>.nc`,
each with its text form (`.txt`).

## Products

| Product | Source | Variables | Time |
|---|---|---|---|
| `Orbital-La2004` | Laskar et al. (2004): La2004 orbital solution, [doi:10.1051/0004-6361:20041335](https://doi.org/10.1051/0004-6361:20041335) | `ecc`, `obl` (degree), `per` (degree), `prec`; `insol_65n_jun21`, `insol_65n_jja`, `insol_65s_dec21`, `insol_65s_djf` (W m-2) | 5 Ma ago to 1 Ma in the future, 1 kyr |

A series of the region "global" without a location (featureType timeSeries, dimension
`region`, `lat` and `lon` missing). `time` is in years before 1950 CE (units "years
ago"), negative in the future.

The insolation is the daily mean at the top of the atmosphere, computed in closed form
(Berger, 1978) as in the insol library used by the models
([fesmc/insol](https://github.com/fesmc/insol)), with S0 = 1365 W m-2 and a year of 365
days with the vernal equinox on 21 March (21 June: day 172, 21 December: day 355); the
seasonal means are means of the daily values (JJA: days 152-243, DJF: 335-365 and 1-59).
Models that need other latitudes or days compute them from the elements, or with insol.

## Licences

| Source | Licence |
|---|---|
| Laskar et al. (2004), La2004 | No licence stated (ASD/IMCCE); publishing assumed to be allowed |

## Making the dataset

```bash
julia fesmdata.jl record Orbital
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA_PRODUCTS/Records/Orbital/` with their text forms
(`--overwrite` to replace them).
