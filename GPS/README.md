# GPS: vertical land motion

Vertical velocities of GPS stations as observational estimates of glacial isostatic
adjustment (GIA) uplift rates. GPS is a records dataset (non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)): its products,
defined in `GPS/records.toml`, are prepared files in the form of the CF discrete
sampling geometries, written to `$FESMDATA/Records/GPS/GPS-<product>.nc`.

## Products

| Product | Source | Sites | Variables |
|---|---|---|---|
| `GPS-Schumacher2018` | Schumacher et al. (2018), [doi:10.1594/PANGAEA.889923](https://doi.org/10.1594/PANGAEA.889923) | 4072 stations worldwide (54 in the Greenland domain) | `uplift_rate`, `uplift_rate_sd` (mm yr-1) |

One value per station (featureType point, dimension `station`, with `lat`, `lon` and
`site_name`): the rates are means over the GPS time series, without a time axis.

## Licences

| Source | Licence |
|---|---|
| Schumacher et al. (2018) | CC BY 3.0 (PANGAEA) |

## Making the dataset

```bash
julia fesmdata.jl record GPS
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA/Records/GPS/` (`--overwrite` to replace them).
