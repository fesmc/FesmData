# Global geothermal heat flow (Lucazeau, 2019)

Global geothermal heat flow and its standard deviation on a 0.5° lon-lat grid, from the
supplementary data of:

Lucazeau, F.: Analysis and mapping of an updated terrestrial heat flow data set,
Geochem. Geophys. Geosyst., 20, 4001-4024, 2019,
[doi:10.1029/2019GC008389](https://doi.org/10.1029/2019GC008389).

## Licence

The article and its supporting information are published by AGU under the Wiley
standard terms and conditions (Crossref licence: onlinelibrary.wiley.com/termsAndConditions),
not under an open licence. The grid may be used for research, but redistributing it or
products derived from it (e.g. a FesmData release) needs permission from AGU
or the author. The heat flow observations it
is fitted to are partly in PANGAEA under CC BY 3.0, which does not cover the grid.

## Original data

The supplementary file `HFgrid14.csv` is kept in this folder
(`2019GC008389-sup-0003-Data_Set_SI-S01/`). To get it again:

```bash
wget "https://agupubs.onlinelibrary.wiley.com/action/downloadSupplement?doi=10.1029%2F2019GC008389&file=2019GC008389-sup-0003-Data_Set_SI-S01.zip" -O sup.zip
unzip sup.zip && rm sup.zip
```

## Prepare and remap

```bash
julia --project=Lucazeau2019_ghf Lucazeau2019_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Lucazeau2019_ghf/Lucazeau2019_GHF.nc all --name=GHF-Lucazeau2019
```

`prepare.jl` writes `ghf` and `ghf_sd` (mW m-2) to
`$FESMDATA_WORK/prepared/Lucazeau2019_ghf/Lucazeau2019_GHF.nc` (see `Remap/README.md`).
