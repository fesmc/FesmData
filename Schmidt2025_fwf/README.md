# Datasets related to FWF protocol for CMIP

Paleo time series datasets

Source: [https://zenodo.org/records/17386710](https://zenodo.org/records/17386710)
Citable as: Schmidt, G. A., Mankoff, K. D., Bamber, J. L., Burgard, C., Carroll, D., Chandler, D. M., Coulon, V., Davison, B. J., England, M. H., Holland, P. R., Jourdain, N. C., Li, Q., Marson, J. M., Mathiot, P., McMahon, C. R., Moon, T. A., Mottram, R., Nowicki, S., Olivé Abelló, A., Pauling, A. G., Rackow, T., and Ringeisen, D.: Datasets and protocols for including anomalous freshwater from melting ice sheets in climate simulations, Geosci. Model Dev., 18, 8333–8361, doi:10.5194/gmd-18-8333-2025, 2025.

## v2

The regions of the freshwater fluxes (`GL_regions_3413.gpkg`, `AQ_regions_3031.gpkg`,
datamanifest keys `schmidt2025_regions_greenland` and `schmidt2025_regions_antarctica`)
are the basin set Schmidt2025 of `../Regions` (`<GRID>_BASINS-Schmidt2025.nc` on the
grids of GRL-PAL, NH and ANT). Its `basin` is the `region` number of the time series.
The files here are the v1 copies.

## Get original data

```bash
wget https://zenodo.org/api/records/17386710/files-archive
unzip files-archive
rm files-archive
```

You should now have the original CSV file `HFgrid14.csv` in the subdirectory.

## Process the data onto a lonlat grid and save as NetCDF
