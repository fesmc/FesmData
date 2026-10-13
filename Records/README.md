# Records: non-gridded data

Time series, site and profile data (ice cores, relative sea level, boreholes, GPS,
point SMB, freshwater fluxes, ...) are made like the gridded datasets, from the
original sources with a documented `prepare.jl`, but they are not remapped: the
prepared file is the product. They go to

```
$FESMDATA_PRODUCTS/Records/<Dataset>/<Dataset>-<Product>.nc
```

next to the domain folders of the gridded data, e.g.
`Records/IceCores/IceCores-Kindler2014.nc` or `Records/RSL/RSL-GAPSLIP.nc`.
Records are not split by domain: a model reads the record and selects its sites.

Inputs derived for one model (e.g. a hosing mask on the grid of one ocean model, or a
series rescaled for one model) stay in the repositories of those models. Unpublished
data are not included.

## Steps

1. **Prepare**, as for a gridded source (see Bring your own data): the source folder
   `<Author><Year>_<topic>/` has `README.md` (data, reference, licence, original data)
   and `prepare.jl`, which gets the originals through `datamanifest.toml` and writes
   `$FESMDATA_PREPARED/<Source>/<file>.nc` in the form below, with
   `provenance_attrib(<tag>)`.
2. **Record**: `<Dataset>/records.toml` lists the products,
   ```toml
   [products.Kindler2014]            # → IceCores-Kindler2014.nc
   source = "Kindler2014"            # source folder
   file = "Kindler2014_NGRIP.nc"     # prepared file
   # figure = { variable = "acc" }   # optional: the variable of its figure on the website
   ```
   and
   ```bash
   julia fesmdata.jl record IceCores                 # all products
   julia fesmdata.jl record IceCores Kindler2014     # one product
   ```
   prepares the missing sources, checks each prepared file against the form below and
   copies it to `$FESMDATA_PRODUCTS/Records/<Dataset>/<Dataset>-<Product>.nc` (`--overwrite`
   to replace).
3. **Publish**, as for a thematic dataset: add the dataset to `Publish/datasets.toml`,
   write `<Dataset>/README.md`, make its figures (`julia fesmdata.jl figures
   <Dataset>`, see `Figures/README.md`) and add its page in `docs/datasets/`.
4. **Release** (see Releasing): a records dataset is released on the domain `Records`
   (one package per dataset, `Records_<Dataset>`, and `registry/Records/<Dataset>.toml`);
   `fesmdata.jl list/fetch/release` work as for the gridded datasets.

## File form

NetCDF following the CF conventions for discrete sampling geometries (CF 1.11,
chapter 9), so that every record is read the same way:

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
