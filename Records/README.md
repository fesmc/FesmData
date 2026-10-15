# Records format

Time series, site and profile data (ice cores, relative sea level, boreholes, GPS,
point SMB, freshwater fluxes, ...) are made like the gridded datasets, from the
original sources with a documented `prepare.jl`, but they are not remapped: the
prepared files are the product (see
[Records](https://fesmc.github.io/FesmData/records_overview.html) for the released
ones). They go to

```
$FESMDATA_PRODUCTS/Records/<Dataset>/<Dataset>-<Product>.nc           # a product of one file
$FESMDATA_PRODUCTS/Records/<Dataset>/<Dataset>-<Product>-<part>.nc    # or of several, one per part
```

next to the domain folders of the gridded data, e.g.
`Records/IceCores/IceCores-Kindler2014.nc` or `Records/RSL/RSL-GAPSLIP.nc`. A product
has several files when its data do not share their axes, e.g. the records of several
ice cores, each on its own time axis. Each NetCDF file comes with its text form,
`<...>.txt` (see below). Records are not split by domain: a model reads the file and
selects its sites.

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

## Text form

Each NetCDF file of a record has a text form next to it, the same name with `.txt`, for
reading without a NetCDF library (e.g. in Fortran or a spreadsheet):

```
# Text form of IceCores-Kindler2014.nc (FesmData record, see https://fesmc.github.io/FesmData/records.html)
# title: ...
# references: ...
# license: ...
#
# station (1): label in column names; site_name, lat, lon
#   NGRIP: site_name="NGRIP", lat=75.1, lon=-42.32
#
# columns: name, units, long name
#   time, years ago, time
#   tas, K, near-surface air temperature
#   ...
#
# 5651 rows (one per time) after the line of column names; missing values are NaN
  time    tas    acc ...
    10.0 243.43 ...
```

- Lines starting with `#`: the global attributes, the sites (or regions) with their
  variables, and the columns with their units and long names.
- One line of column names, then one line per row, columns separated by spaces.
- The rows are along the time (or sample, depth) axis of the record, or are the
  observations of point data. A variable on the sites and the rows is a column per site,
  `<name>_<site>` (e.g. `d18O_NGRIP`), or `<name>` for a record of one site; a variable
  on the rows and another axis is a column per index (e.g. `time_bnds_1`,
  `time_bnds_2`).
- Numbers as stored in the NetCDF file (times in the units of the header, not
  decoded), missing values as `NaN`, strings in double quotes.
- Variables on other axes only (e.g. lookup tables) are named in the header but are only
  in the NetCDF file. Records whose variables have more than two axes, or that are too
  large for text, have no text form (`text = false` in `records.toml`).

The text form is made from the NetCDF file (`fesmdata.jl record`, again after `stamp`
at a release), so both have the same data and version.
