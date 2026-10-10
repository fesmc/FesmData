# Geothermal heat flow of Antarctica, Aq1 (Stål et al., 2021)

Geothermal heat flow of Antarctica, Aq1, from a similarity detection between
observables in Antarctica and heat flow measurements on other continents, with its
uncertainty, on a 20 km polar stereographic grid (EPSG:3031):

Stål, T., Reading, A. M., Halpin, J. A., and Whittaker, J. M.: Antarctic geothermal
heat flow model: Aq1, Geochem. Geophys. Geosyst., 22, e2020GC009428, 2021,
[doi:10.1029/2020GC009428](https://doi.org/10.1029/2020GC009428).

Data: Stål, T., Reading, A. M., Halpin, J. A., and Whittaker, J. M.: Antarctic
geothermal heat flow model: Aq1, PANGAEA, 2020,
[doi:10.1594/PANGAEA.924857](https://doi.org/10.1594/PANGAEA.924857).

The map is also redistributed, extrapolated by 80 km beyond the coast and regridded, in
the supplement of the ISMIP7 heat flow recommendations (Lösing et al., 2025,
[doi:10.5281/zenodo.16874966](https://doi.org/10.5281/zenodo.16874966), restricted
access). The original map, without the extrapolation, is used here.

## Licence

CC BY 4.0 (PANGAEA).

## Original data

`aq1_01_20.nc` (revision 01, 20 km), downloaded by `prepare.jl` (datamanifest key
`staal2020_aq1`) from <https://download.pangaea.de/dataset/924857/files/aq1_01_20.nc>
(no login).

## Prepare and remap

```bash
julia --project=Stal2020_ghf Stal2020_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Stal2020_ghf/Stal2020_GHF.nc Antarctica --name=GHF-Stal2020
```

`prepare.jl` writes `ghf` (`Q` of Aq1) and `ghf_unc` (its uncertainty `U`), converted
from W m-2 to mW m-2, to `$FESMDATA_WORK/prepared/Stal2020_ghf/Stal2020_GHF.nc` (see
`Remap/README.md`). The grid has 280 x 280 points from -2800 to 2800 km (spacing
20.07 km). The map ends at the coast. The other fields of the file (`N`, sum of
similarity; `H`, information entropy) are not used.
