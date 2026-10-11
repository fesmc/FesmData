# Sediment properties of North America and Greenland (Gowan et al., 2019)

Grain size and distribution of the surface sediments in the areas of the former North
American ice sheets, Greenland and Iceland, as classes on a 5 km grid (Lambert
conformal conic), from:

Gowan, E. J., Niu, L., Knorr, G. and Lohmann, G.: Geology datasets in North America,
Greenland and surrounding areas for use with ice sheet models, Earth Syst. Sci. Data,
11, 375-391, 2019, [doi:10.5194/essd-11-375-2019](https://doi.org/10.5194/essd-11-375-2019).

Data: Gowan, E. J., Niu, L., Knorr, G. and Lohmann, G.: Geology datasets in North
America, Greenland and surrounding areas for use with ice sheet models, PANGAEA, 2019,
[doi:10.1594/PANGAEA.895889](https://doi.org/10.1594/PANGAEA.895889).

## Licence

CC BY 4.0 (PANGAEA).

## Original data

`geology_for_ice_sheet_models.zip` (224 MB, no login) from PANGAEA,
<https://hs.pangaea.de/Maps/NAGS/geology_for_ice_sheet_models.zip>, of which
`data/netcdf/grain_size.nc`, `distribution.nc` and `final_sed.nc` are used (see
`data/readme.txt`). It is in `datamanifest.toml` (`gowan2019_geology`) and downloaded
and extracted by `prepare.jl` if missing.

## Prepare and remap

```bash
julia --project=Gowan2019_sed Gowan2019_sed/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Gowan2019_sed/Gowan2019_sed.nc Laurentide --name=Sediment-Gowan2019
```

`prepare.jl` writes three integer fields of classes (with `flag_values` and
`flag_meanings`) to `$FESMDATA_WORK/prepared/Gowan2019_sed/Gowan2019_sed.nc` (see
`Remap/README.md`), missing where there are no data (oceans, and land outside the areas
of the former ice sheets):

- `grain`: grain size, 1 clay, 2 sand, 3 silt (`grain_size.nc`);
- `distribution`: sediment distribution, 1 blanket (continuous), 2 veneer
  (discontinuous), 3 rock (mostly bare rock) (`distribution.nc`);
- `composite`: both combined, 0-8 for blanket, veneer and rock with sand, silt and clay
  (`final_sed.nc`, converted from the shapefile).

`distribution.nc` has 2 for rock and 3 for veneer, the reverse of `data/readme.txt`:
`composite` and the attributes of the shapefile (`sediment_properties/`) show that
veneer covers about 3.7 times the area of rock. It is recoded to the classes of the
readme, and set missing where it is 1 (blanket) only because there are no data. The
v1 product SED-G19 used the codes of `distribution.nc` as they are, and filled the
missing values with silt (`grain`) and blanket silt (`composite`).

The grid is that of the files, a Lambert conformal conic projection on the Clarke 1866
ellipsoid (as in their WKT; `data/readme.txt` calls it EPSG:3979, the same projection on
GRS80). The bedrock geology (`geology.nc`, on another grid) is not used.
