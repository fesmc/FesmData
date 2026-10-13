# Freshwater: freshwater fluxes of the ice sheets

Freshwater flux and mass anomaly series of the ice sheets by region. Freshwater is a
records dataset (non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)): its products,
defined in `Freshwater/records.toml`, are prepared files in the form of the CF discrete
sampling geometries, written to
`$FESMDATA_PRODUCTS/Records/Freshwater/Freshwater-<product>.nc`.

## Products

From Schmidt et al. (2025),
[doi:10.5281/zenodo.17386710](https://doi.org/10.5281/zenodo.17386710), one product per
series file (see
[Schmidt2025_fwf](https://github.com/fesmc/FesmData/blob/main/Schmidt2025_fwf/README.md)):

| Product | Variables (by region) | Time |
|---|---|---|
| `Freshwater-Schmidt2025_GL_discharge` | `discharge`, `discharge_sd` (Gt yr-1) | annual, 1840-2025 |
| `Freshwater-Schmidt2025_GL_runoff` | `surface_runoff_from_ice`, `surface_runoff_from_land`, `subglacial_discharge_from_ice`, `subglacial_discharge_from_land` (m3 s-1), `min_discharge_depth` (m) | monthly, 1950-2022 |
| `Freshwater-Schmidt2025_GL_mass_anomaly` | `SMB_ROI`, `D_ROI`, `MB_ROI`, their anomalies `*_anom`, `SMB_ROI_sd`, `D_ROI_sd`, and the total `MB` (Gt yr-1) | annual, 1850-2024 |
| `Freshwater-Schmidt2025_AQ_calving` | `calving`, `anomaly`, `calving_sd`, `baseline` (Gt yr-1) | annual, 1997-2021 |
| `Freshwater-Schmidt2025_AQ_subshelf_melt` | `melt`, `anomaly`, `baseline` (Gt yr-1), `injection_depth_min`, `injection_depth_max` (m) | annual, 1991-2021 |
| `Freshwater-Schmidt2025_AQ_grounded_mass_change` | `grounded_dm` (Gt yr-1) | annual, 2002-2023 |
| `Freshwater-Schmidt2025_AQ_mass_anomaly` | `calve`, `subshelf_melt`, `grounded_loss`, `MB_ROI_anom` (Gt yr-1) | annual, 1990-2023 |

The series are by region (featureType timeSeries, dimensions `time` and `region`): 7
regions in Greenland (CE, CW, NE, NO, NW, SE, SW) and 18 in Antarctica (A-Ap, ..., K-A).
`region` is the region number, the basin id of the Regions basin set Schmidt2025
(`<GRID>_BASINS-Schmidt2025.nc`, see
[Regions](https://fesmc.github.io/FesmData/datasets/regions.html)), so that a series can
be put on the grid of a domain; `region_name` is its name, and `lat`, `lon` the centroid
of the region. `time` is in days since 1800-01-01, the middle of each year or month,
with `time_bnds`.

The normalised iceberg melt climatologies of the record (`GL_iceberg_melt.nc`,
`AQ_iceberg_melt.nc`) are gridded (0.5° lon-lat) and left out: they are for ocean
models, which remap them onto their own grids.

## Licences

| Source | Licence |
|---|---|
| Schmidt et al. (2025) | CC BY 4.0 (Zenodo) |

## Making the dataset

```bash
julia fesmdata.jl record Freshwater
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA_PRODUCTS/Records/Freshwater/` (`--overwrite` to replace them).
