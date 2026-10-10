# IceHistory: paleo ice sheets and topography

Reconstructions of past ice sheets and topography (glacial cycles, Pliocene), remapped
onto the grids of the domains and onto global lon-lat grids. IceHistory is a thematic
dataset made by remapping (see Bring your own data, `Remap/README.md`): its products
are defined in `IceHistory/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `IceHistory-ICE5G` | Peltier (2004): ICE-5G v1.2, 1°, 21-0 ka, [doi:10.1146/annurev.earth.32.082503.144359](https://doi.org/10.1146/annurev.earth.32.082503.144359) | `z_topo` (topography incl. bathymetry), `H_ice`, `f_ice`, on `time` (ka BP) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `IceHistory-ICE6G_C` | Peltier et al. (2015), Argus et al. (2014): ICE-6G_C (VM5a), 1°, 26-0 ka, [doi:10.1002/2014JB011176](https://doi.org/10.1002/2014JB011176) | `z_topo`, `z_srf`, `dz_topo`, `H_ice`, `f_ice`, `f_land`, on `time` (ka BP) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `IceHistory-PRISM4` | Dowsett et al. (2016): PRISM4 (PlioMIP2) boundary conditions, 1°, [doi:10.5194/cp-12-1519-2016](https://doi.org/10.5194/cp-12-1519-2016) | `z_topo_enh`, `z_topo_std`, `z_topo_mod` (enhanced, standard Pliocene, modern), `mask_enh`, `mask_std` (0 ocean, 1 land, 2 ice) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |

Each file `<GRID>_IceHistory-<Source>.nc` also has `f_valid`, the fraction of each cell
covered by the source. Fields are remapped conservatively and, on grids finer than the
source, smoothed with a Gaussian of half the source spacing; the masks are remapped as
classes (the class covering most of each cell). The global attribute `remap_method`
records what was done on each grid.

## Licences

| Source | Licence |
|---|---|
| Peltier (2004), ICE-5G | None stated; cite Peltier (2004) |
| Peltier et al. (2015), ICE-6G_C | None stated; cite Peltier et al. (2015) and Argus et al. (2014) |
| Dowsett et al. (2016), PRISM4 | Public domain (USGS); no licence in the files |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap IceHistory
```

See `GHF/README.md` for making single products and adding a source.
