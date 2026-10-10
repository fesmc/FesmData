# Antarctic geothermal heat flow (Martos et al., 2017)

Geothermal heat flow and Curie depth of Antarctica, with their uncertainties, on a
15 km polar stereographic grid, derived from spectral analysis of the ADMAP-2 airborne
magnetic compilation. The grid covers the continent only (no data offshore).

Martos, Y. M., Catalan, M., Jordan, T. A., Golynsky, A., Golynsky, D., Eagles, G., and
Vaughan, D. G.: Heat flux distribution of Antarctica unveiled, Geophys. Res. Lett., 44,
11417-11426, 2017, [doi:10.1002/2017GL075609](https://doi.org/10.1002/2017GL075609).

Data: Martos, Y. M.: Antarctic geothermal heat flux distribution and estimated Curie
Depths, links to gridded files, PANGAEA, 2017,
[doi:10.1594/PANGAEA.882503](https://doi.org/10.1594/PANGAEA.882503).

## Licence

CC BY 3.0 (PANGAEA).

## Original data

Four ASCII files (x, y in m, value), downloaded by `prepare.jl` (DataManifest keys
`martos2017_*` in `datamanifest.toml`) from
<https://store.pangaea.de/Publications/Martos-etal_2017/>:

- `Antarctic_GHF.xyz`: heat flow (mW m-2)
- `Antarctic_GHF_uncertainty.xyz`: its uncertainty (mW m-2)
- `Curie_Depth.xyz`: Curie depth (km, positive downwards)
- `Curie_Depth_Uncertainty.xyz`: its uncertainty (km)

The same files are in the old PIK archive, `hpc:/data/sicopolis/data/GeothermalHeatFlux/Martos2017/original_data/`.

## Prepare and remap

```bash
julia --project=Martos2017_ghf Martos2017_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Martos2017_ghf/Martos2017_GHF.nc Antarctica --name=GHF-Martos2017
```

`prepare.jl` writes `ghf`, `ghf_sd` (mW m-2), `depth_curie` and `depth_curie_sd` (km)
to `$FESMDATA_WORK/prepared/Martos2017_ghf/Martos2017_GHF.nc` (see `Remap/README.md`).
The points of the files lie on a regular 15 km grid in polar stereographic coordinates
with true scale at 71°S on WGS84 (EPSG:3031, the projection of ADMAP-2); grid points
missing from the files (ocean) are missing values. `ghf_sd` and `depth_curie_sd` are
the uncertainties given by the authors.
