# Datasets related to FWF protocol for CMIP

Paleo time series datasets

Source: [https://zenodo.org/records/17386710](https://zenodo.org/records/17386710)
Citable as: Schmidt, G. A., Mankoff, K. D., Bamber, J. L., Burgard, C., Carroll, D., Chandler, D. M., Coulon, V., Davison, B. J., England, M. H., Holland, P. R., Jourdain, N. C., Li, Q., Marson, J. M., Mathiot, P., McMahon, C. R., Moon, T. A., Mottram, R., Nowicki, S., Olivé Abelló, A., Pauling, A. G., Rackow, T., and Ringeisen, D.: Datasets and protocols for including anomalous freshwater from melting ice sheets in climate simulations, Geosci. Model Dev., 18, 8333–8361, doi:10.5194/gmd-18-8333-2025, 2025.

## Get original data

```bash
wget https://zenodo.org/api/records/17386710/files-archive
unzip files-archive
rm files-archive
```

You should now have the original CSV file `HFgrid14.csv` in the subdirectory.

## Process the data onto a lonlat grid and save as NetCDF
