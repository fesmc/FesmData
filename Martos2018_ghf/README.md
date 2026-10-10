# Geothermal heat flux of Greenland (Martos et al., 2018)

Geothermal heat flux and Curie depth of Greenland, with their uncertainties, on a 15 km
grid, derived from the Curie depths of the World Digital Magnetic Anomaly Map 2 and a
thermal model of the lithosphere:

Martos, Y. M., Jordan, T. A., Catalán, M., Jordan, T. M., Bamber, J. L. and Vaughan, D. G.:
Geothermal heat flux reveals the Iceland hotspot track underneath Greenland, Geophys.
Res. Lett., 45, 8214-8222, 2018, [doi:10.1029/2018GL078289](https://doi.org/10.1029/2018GL078289).

Data: Martos, Y. M.: Greenland geothermal heat flux distribution and estimated Curie
depths, links to gridded files, PANGAEA, 2018,
[doi:10.1594/PANGAEA.892973](https://doi.org/10.1594/PANGAEA.892973).

## Licence

CC BY 3.0 (Creative Commons Attribution 3.0 Unported), as stated on PANGAEA.

## Original data

Four ASCII files (`x y z`, no header) from
https://store.pangaea.de/Publications/Martos-etal_2018/, downloaded by `prepare.jl`
(`datamanifest.toml`, keys `martos2018_*`) to `$DATAMANIFEST_DATASETS_DIR/martos2018/`:

- `Geothermal_Heat_Flux_Greenland.xyz`: heat flux (mW m-2)
- `Geothermal_Heat_Flux_Greenland_uncertainty.xyz`: its uncertainty (mW m-2)
- `Curie_Depth_Greenland.xyz`: Curie depth (km, positive downwards)
- `Curie_Depth_Greenland_uncertainty.xyz`: its uncertainty (km)

The files are identical to the copies in the old PIK archive
(`/data/sicopolis/data/GeothermalHeatFlux/Martos2018/original_data/`).

## Prepare and remap

```bash
julia --project=Martos2018_ghf Martos2018_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Martos2018_ghf/Martos2018_GHF.nc Greenland --name=GHF-Martos2018
```

`prepare.jl` writes `ghf`, `ghf_sd` (mW m-2), `depth_curie` and `depth_curie_sd` (km) to
`$FESMDATA_WORK/prepared/Martos2018_ghf/Martos2018_GHF.nc` (see `Remap/README.md`).

The coordinates are x, y in m in UTM zone 23N (WGS84), as stated on PANGAEA ("X and Y
geographic coordinates are in UTM23N projection"); the points lie on a regular 15 km
grid (cell centres at multiples of 15 km), which is written as is. The files list land
points only (10715 of the 120 x 183 cells), so the ocean and some coastal cells are
missing; the uncertainties are taken as standard deviations (`_sd`).
