# IceCores: ice core records

Time series at Greenland ice core sites: temperature, accumulation, water isotopes and
surface elevation. IceCores is a records dataset (non-gridded data, see
`Records/README.md`): its products, defined in `IceCores/records.toml`, are prepared
files in the form of the CF discrete sampling geometries, written to
`$FESMDATA_PRODUCTS/Records/IceCores/IceCores-<product>.nc`.

## Products

| Product | Source | Sites | Variables | Time |
|---|---|---|---|---|
| `IceCores-Kindler2014` | Kindler et al. (2014): reconstruction from δ15N and a firn model, [doi:10.5194/cp-10-887-2014](https://doi.org/10.5194/cp-10-887-2014) | NGRIP | `tas` (K), `acc` (kg m-2 yr-1), `depth` | 10-122 ka, 20 years (GICC05modelext) |
| `IceCores-Gkinis2020` | Gkinis et al. (2020): 0.05 m samples, [doi:10.1594/PANGAEA.925552](https://doi.org/10.1594/PANGAEA.925552) | NEEM | `d18O`, `dD` (‰) with precision and accuracy offsets, `depth` | 8-121 ka (GICC05, GICC05_modelext; also AICC2012) |
| `IceCores-Vinther2009` | Vinther et al. (2009): Holocene thinning, [doi:10.1038/nature08355](https://doi.org/10.1038/nature08355) | Camp Century, NGRIP, GRIP, DYE-3 | `dz_srf`, `dz_srf_sd` (m), `z_srf` (present) | 11.7 ka to present, 20 years (GICC05) |

All are time series at fixed sites (featureType timeSeries, dimension `station`, with
`lat`, `lon`, `site_name`, and `z_srf` where the source gives it). `time` is in years
before 1950 CE (units "years ago"), converted from the b2k ages (before 2000 CE) of the
sources by subtracting 50.

## Licences

| Source | Licence |
|---|---|
| Kindler et al. (2014) | CC BY 3.0 (Clim. Past supplement) |
| Gkinis et al. (2020) | CC BY 4.0 (PANGAEA) |
| Vinther et al. (2009) | NOAA NCEI open data, no licence stated; publishing assumed to be allowed |

## Making the dataset

```bash
julia fesmdata.jl record IceCores
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA_PRODUCTS/Records/IceCores/` (`--overwrite` to replace them).
