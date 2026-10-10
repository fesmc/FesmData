# Global geothermal heat flow (Shapiro and Ritzwoller, 2004)

Global geothermal heat flow and its standard deviation on a 1° lon-lat grid, predicted
from the global heat flow data set of Pollack et al. (1993), extrapolated by
structural similarity in a global seismic model of the crust and upper mantle:

Shapiro, N. M. and Ritzwoller, M. H.: Inferring surface heat flux distributions guided
by a global seismic model: particular application to Antarctica, Earth Planet. Sci.
Lett., 223, 213-224, 2004,
[doi:10.1016/j.epsl.2004.04.011](https://doi.org/10.1016/j.epsl.2004.04.011).

## Licence

No licence is stated with the data; we assume they may be redistributed, with
citation of the article.

## Original data

The map was published as `hfmap.asc.gz` (with `README_heat_flow`) on the authors' page,
http://ciei.colorado.edu/~nshapiro/MODEL/ASC_VERSION/, which is no longer online. It is
downloaded from the copy in the Internet Archive (datamanifest key `shapiro2004_ghf`,
into `$DATAMANIFEST_DATASETS_DIR/shapiro2004_ghf/`):

```
https://web.archive.org/web/20240806132053id_/http://ciei.colorado.edu/~nshapiro/MODEL/ASC_VERSION/hfmap.asc.gz
```

This copy is identical to the one in the old PIK archive
(`hpc:/data/sicopolis/data/GeothermalHeatFlux/Shapiro2004/hfmap.asc`).

## Prepare and remap

```bash
julia --project=Shapiro2004_ghf Shapiro2004_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Shapiro2004_ghf/Shapiro2004_GHF.nc all --name=GHF-Shapiro2004
```

`prepare.jl` downloads the file if missing and writes `ghf` and `ghf_sd` (standard
deviation), in mW m-2, to `$FESMDATA_WORK/prepared/Shapiro2004_ghf/Shapiro2004_GHF.nc`
(see `Remap/README.md`). The file gives the values at the points of a 1° grid
(longitudes 0-359°, latitudes -90-90°, including the poles); they are written
unchanged as cells centred on these points, with longitudes shifted to -180-179°.
