# IceHistory: paleo ice sheets and topography

Reconstructions of past ice sheets and topography (glacial cycles, Pliocene), remapped
onto the grids of the domains and onto global lon-lat grids. IceHistory is a thematic
dataset made by remapping (see Bring your own data, `Remap/README.md`): its products
are defined in `IceHistory/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `IceHistory-ICE5G` | Peltier (2004): ICE-5G v1.2, 1°, 21-0 ka, [doi:10.1146/annurev.earth.32.082503.144359](https://doi.org/10.1146/annurev.earth.32.082503.144359) | `z_topo` (topography incl. bathymetry), `H_ice`, `f_ice`, on `time` (years ago) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `IceHistory-ICE6G_C` | Peltier et al. (2015), Argus et al. (2014): ICE-6G_C (VM5a), 1°, 26-0 ka, [doi:10.1002/2014JB011176](https://doi.org/10.1002/2014JB011176) | `z_topo`, `z_srf`, `dz_topo`, `H_ice`, `f_ice`, `f_land`, on `time` (years ago) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `IceHistory-PRISM4` | Dowsett et al. (2016): PRISM4 (PlioMIP2) boundary conditions, 1°, [doi:10.5194/cp-12-1519-2016](https://doi.org/10.5194/cp-12-1519-2016) | `z_topo_enh`, `z_topo_std`, `z_topo_mod` (enhanced, standard Pliocene, modern), `mask_enh`, `mask_std` (0 ocean, 1 land, 2 ice) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `IceHistory-Batchelor2019` | Batchelor et al. (2019): Northern Hemisphere ice-sheet extents, 18 time slices from 3.1 Ma to the LGM, rasterized at 1 km, [doi:10.1038/s41467-019-11601-2](https://doi.org/10.1038/s41467-019-11601-2) | `f_ice_best`, `f_ice_min`, `f_ice_max` (best-estimate, minimum and maximum extents), on `time` (years ago) | GreenlandPaleo, Greenland, North, Laurentide, Eurasia (grids of 2 km and coarser) |
| `IceHistory-PaleoMIST` | Gowan et al. (2021): PaleoMIST 1.0, 0.25°, 80-0 ka every 2.5 kyr, [doi:10.1594/PANGAEA.905800](https://doi.org/10.1594/PANGAEA.905800) | `z_topo`, `z_bed`, `H_ice`, `dz_sl` (sea-level change), `f_ice` (from the 5 km regional reconstructions), on `time` (years ago) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `IceHistory-PaleoGrIS` | Leger et al. (2024): PaleoGrIS 1.0 isochrone buffers, 1 km, [doi:10.17632/nh57cz4gys.1](https://doi.org/10.17632/nh57cz4gys.1) | `age_deglac` (time of deglaciation, years ago, 13-7 ka), `age_deglac_err` | GreenlandPaleo, Greenland (grids of 1 km and coarser) |
| `IceHistory-Margold2015` | Margold et al. (2015): Laurentide ice streams, rasterized at 1 km, [doi:10.1080/17445647.2014.912036](https://doi.org/10.1080/17445647.2014.912036), with their activity from Stokes et al. (2016), [doi:10.1038/nature16947](https://doi.org/10.1038/nature16947) | `f_stream`, `f_stream_lgm` (streams active at 21.8 ka), `age_stream_start`, `age_stream_end` (years ago) | North, Laurentide |
| `IceHistory-Batchelor2019_PaleoMIST_LGC` | Batchelor et al. (2019) in the Northern Hemisphere and PaleoMIST 1.0 (Gowan et al., 2021) in the Southern Hemisphere, 0.1°, 80-21 ka (replaces `Batchelor2019_ice_masks_lgc.nc` of v1, used by CLIMBER-X) | `f_ice_best`, `f_ice_min`, `f_ice_max`, on `time` (years ago: 80000, 65000, 45000, 40000, 35000, 30000, 26500, 21000) | Global |

Each file `<GRID>_IceHistory-<Source>.nc` also has `f_valid`, the fraction of each cell
covered by the source. Fields are remapped conservatively and, on grids finer than the
source, smoothed with a Gaussian of half the source spacing; the masks are remapped as
classes (the class covering most of each cell). Ice extents from outlines (Batchelor,
Margold) are rasterized as area fractions at 1 km, so that remapping gives the fraction of
each cell. The global attribute `remap_method` records what was done on each grid.

## Licences

| Source | Licence |
|---|---|
| Peltier (2004), ICE-5G | None stated; cite Peltier (2004) |
| Peltier et al. (2015), ICE-6G_C | None stated; cite Peltier et al. (2015) and Argus et al. (2014) |
| Dowsett et al. (2016), PRISM4 | Public domain (USGS); no licence in the files |
| Batchelor et al. (2019) | No licence stated for the shapefiles (OSF); article CC BY 4.0; cite the article |
| Gowan et al. (2021), PaleoMIST 1.0 | CC BY 4.0 (PANGAEA) |
| Leger et al. (2024), PaleoGrIS 1.0 | CC BY 4.0 (Mendeley Data) |
| Margold et al. (2015), with Stokes et al. (2016) | Outlines CC BY 4.0 (figshare); ages from the source data of Stokes et al. (2016), Nature, no open licence stated |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap IceHistory
```

See `GHF/README.md` for making single products and adding a source.
