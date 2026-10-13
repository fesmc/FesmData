# Records format

Time series, site and profile data (ice cores, relative sea level, boreholes, GPS,
point SMB, freshwater fluxes, ...) are made like the gridded datasets, from the
original sources with a documented `prepare.jl`, but they are not remapped: the
prepared file is the product (see
[Records](https://fesmc.github.io/FesmData/records_overview.html) for the released
ones). They go to

```
$FESMDATA_PRODUCTS/Records/<Dataset>/<Dataset>-<Product>.nc
```

next to the domain folders of the gridded data, e.g.
`Records/IceCores/IceCores-Kindler2014.nc` or `Records/RSL/RSL-GAPSLIP.nc`.
They are not split by domain: a model reads the file and selects its sites.

Inputs derived for one model (e.g. a hosing mask on the grid of one ocean model, or a
series rescaled for one model) stay in the repositories of those models. Unpublished
data are not included. Making a records dataset from prepared files is described under
[Adding a dataset](https://fesmc.github.io/FesmData/adding.html#records-datasets).

## File form

NetCDF following the CF conventions for discrete sampling geometries (CF 1.11,
chapter 9), so that every file is read the same way:

| Data | `featureType` | Example |
|---|---|---|
| one or more series at fixed sites | `timeSeries` | ice cores, GPS uplift, freshwater fluxes by region |
| vertical profiles at sites | `profile` | borehole temperatures |
| isolated observations | `point` | relative sea level indicators, point SMB |
| series of profiles at sites | `timeSeriesProfile` | firn density through time |

- Sites (`station` dimension): `lat`, `lon` (degrees), `site_name` (string), and
  `z_srf` (m) where known; a region instead of a site gets a `region` variable.
- Time: paleo series use `time` in **years ago** (positive, before 1950 CE; units
  `"years ago"`); modern series a CF time axis (`days since ...`, mid-interval
  values with `time_bnds`).
- Depth: `depth` (m, positive down) for profiles.
- Uncertainties as `<name>_sd` (or `<name>_min`/`<name>_max` for ranges).
- The units and names of the gridded datasets where they apply (e.g. `smb`
  kg m-2 yr-1, temperatures K).
- Global attributes as for prepared gridded files: `title`, `references`, `doi`,
  `license`, `featureType`, plus the provenance attributes.
