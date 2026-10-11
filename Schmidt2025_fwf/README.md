# Freshwater fluxes of the ice sheets by region (Schmidt et al., 2025)

Freshwater flux and mass anomaly series of the Greenland and Antarctic ice sheets by
region, from the datasets of the protocol for including anomalous freshwater from the
ice sheets in climate simulations (CMIP):

Schmidt, G. A., Mankoff, K. D., Bamber, J. L., Burgard, C., Carroll, D., Chandler,
D. M., Coulon, V., Davison, B. J., England, M. H., Holland, P. R., Jourdain, N. C., Li,
Q., Marson, J. M., Mathiot, P., McMahon, C. R., Moon, T. A., Mottram, R., Nowicki, S.,
Olivé Abelló, A., Pauling, A. G., Rackow, T., and Ringeisen, D.: Datasets and protocols
for including anomalous freshwater from melting ice sheets in climate simulations,
Geosci. Model Dev., 18, 8333-8361, 2025,
[doi:10.5194/gmd-18-8333-2025](https://doi.org/10.5194/gmd-18-8333-2025).

Data: Freshwater sources from Antarctica and Greenland, Zenodo, 2025,
[doi:10.5281/zenodo.17386710](https://doi.org/10.5281/zenodo.17386710). Each file names
its original data source (Mankoff, Davison, Paolo, Dohne, ...) in its attributes.

## Licence

CC BY 4.0 (Zenodo).

## Original data

Files of the Zenodo record 17386710 (no login), downloaded by `prepare.jl` (datamanifest
keys `schmidt2025_<file>`, lowercase):

| File | Series (by region) | Time |
|---|---|---|
| `GL_discharge.nc` | marine discharge and its uncertainty (Gt yr-1) | annual, 1840-2025 |
| `GL_runoff.nc` | surface runoff and subglacial discharge from ice and land (m3 s-1), minimum discharge depth | monthly, 1950-2022 |
| `GL_mass_anomaly.nc` | SMB, discharge, mass balance and their anomalies (Gt yr-1) | annual, 1850-2024 |
| `AQ_calving.nc` | calving, baseline, anomaly, uncertainty (Gt yr-1) | annual, 1997-2021 |
| `AQ_subshelf_melt.nc` | sub-shelf melt, baseline, anomaly (Gt yr-1), injection depths | annual, 1991-2021 |
| `AQ_grounded_mass_change.nc` | grounded mass change (Gt yr-1) | annual, 2002-2023 |
| `AQ_mass_anomaly.nc` | calving, sub-shelf melt, grounded loss and mass balance anomalies (Gt yr-1) | annual, 1990-2023 |

The regions are 7 in Greenland (the Mouginot regions CE, CW, NE, NO, NW, SE, SW) and 18
in Antarctica (the IMBIE 2016 basins A-Ap, ..., K-A), numbered in alphabetical order:
they are the basin set Schmidt2025 of `../Regions` (`<GRID>_BASINS-Schmidt2025.nc`),
whose `basin` is the region number of the series. Their polygons, `GL_regions_3413.gpkg`
and `AQ_regions_3031.gpkg` (datamanifest keys `schmidt2025_regions_greenland`,
`schmidt2025_regions_antarctica`), are also used here for the centroids of the regions.

The record also has `GL_iceberg_melt.nc` and `AQ_iceberg_melt.nc`, normalised iceberg
melt climatologies (12 months x region of calving on a 0.5° lon-lat grid), the regions
in lon-lat (`*_regions_4326.gpkg`) and grown over the ocean (`*_regions_*_flood.nc`):
these are gridded and not made as records. The v1 copies of all files that were kept in
this folder are removed: they are on Zenodo.

## Prepare and record

```bash
julia --project=Schmidt2025_fwf Schmidt2025_fwf/prepare.jl
julia fesmdata.jl record Freshwater
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Schmidt2025_fwf/Schmidt2025_<file>.nc` for
the seven series files (see `Records/README.md`): time series by region (featureType
timeSeries, dimensions `time` and `region`), with the variables of the source (names and
attributes, oriented (time, region)) and `region` (number), `region_name`, `lat` and
`lon` (the area-weighted centroid of the polygons of the region), `time` (days since
1800-01-01) and `time_bnds`.

Notes:

- The time stamps of the source are the start of the year (Greenland, annual), the start
  of the month (`GL_runoff`) or 1 July of the year (Antarctica). `time` is the middle of
  the year or month, with `time_bnds`.
- The uncertainties are renamed `<name>_sd` (`err` of `GL_discharge` → `discharge_sd`,
  `SMB_ROI_err`, `D_ROI_err` → `SMB_ROI_sd`, `D_ROI_sd`, `uncertainty` of `AQ_calving`
  → `calving_sd`).
- Units missing in the source are set to Gt yr-1 (`MB_ROI`, `MB`, `*_anom` of
  `GL_mass_anomaly`, `uncertainty` of `AQ_calving`, `MB_ROI_anom` of
  `AQ_mass_anomaly`), and the units "Gt d-1" of `SMB_ROI_err`, `D_ROI_err` are replaced
  by Gt yr-1, as their values have the magnitude of the annual fluxes; such variables
  have the attribute `comment_units`.
- `SMB_ROI_sd` has negative values in the source (down to -11.7 Gt yr-1), kept.
