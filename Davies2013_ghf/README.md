# Global geothermal heat flow (Davies, 2013)

Global geothermal heat flow and its error estimate on a 2° lon-lat grid, from the
supporting information of:

Davies, J. H.: Global map of solid Earth surface heat flow, Geochem. Geophys. Geosyst.,
14, 4608-4622, 2013, [doi:10.1002/ggge.20271](https://doi.org/10.1002/ggge.20271).

The map combines heat flow observations, where there are any, with estimates from
geology and, for young ocean crust, from a cooling model, on a 2° equal-area grid. The
supporting information also gives it on a 2° lon-lat grid, which is used here.

## Licence

The article and its supporting information are published by AGU under the Wiley
standard terms and conditions, not under an open licence. The map may be used for
research, but redistributing it or products derived from it (e.g. a FesmData release)
needs permission from AGU or the author.

## Original data

`ggge20271-sup-0003-Data_Table1_Eq_lon_lat_Global_HF.csv` (Data Table 1, lon-lat
version) of the supporting information, in `$DATAMANIFEST_DATASETS_DIR/davies2013_ghf/`
(datamanifest key `davies2013_ghf`). Wiley blocks automated downloads, so get it by
hand from the article page (Supporting Information), or with a browser from:

```
https://agupubs.onlinelibrary.wiley.com/action/downloadSupplement?doi=10.1002%2Fggge.20271&file=ggge20271-sup-0003-Data_Table1_Eq_lon_lat_Global_HF.csv
```

A copy is in the old PIK archive; on Levante:

```bash
mkdir -p /work/ba1442/data/davies2013_ghf
scp hpc:/data/sicopolis/data/GeothermalHeatFlux/Davies2013/ggge20271-sup-0003-Data_Table1_Eq_lon_lat_Global_HF.csv /work/ba1442/data/davies2013_ghf/
```

## Prepare and remap

```bash
julia --project=Davies2013_ghf Davies2013_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Davies2013_ghf/Davies2013_GHF.nc all --name=GHF-Davies2013
```

`prepare.jl` writes `ghf` (heat flow based on the mean of the observations in each
polygon of geology and grid, column `Mean_HF`), `ghf_median` (based on the median,
`Median_HF`) and `ghf_err` (error estimate, `Total_Erro`), all in mW m-2, to
`$FESMDATA_WORK/prepared/Davies2013_ghf/Davies2013_GHF.nc` (see `Remap/README.md`).
The values are those of the file, unchanged; the error estimate exceeds 1000 mW m-2 in
a few cells.
