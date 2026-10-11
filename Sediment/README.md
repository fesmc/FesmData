# Sediment: sediment thickness

Sediment thickness (m) from global and regional maps, and sediment properties of North
America and Greenland, remapped onto the grids of the domains and onto global lon-lat
grids. Sediment is a thematic dataset made by remapping (see Bring your own data,
`Remap/README.md`): its products are defined in `Sediment/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `Sediment-CRUST1` | Laske et al. (2013): CRUST1.0, 1° global crustal model, land and ocean ([igppweb.ucsd.edu/~gabi/crust1.html](https://igppweb.ucsd.edu/~gabi/crust1.html)); its sediments are essentially those of Laske and Masters (1997), the v1 product SED-L97 | `z_sed` (total), `z_sed_upper`, `z_sed_middle`, `z_sed_lower` (layers) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Sediment-GlobSed` | Straume et al. (2019): GlobSed v3, 5' total sediment thickness of the oceans (missing on land), [doi:10.1029/2018GC008115](https://doi.org/10.1029/2018GC008115) | `z_sed` | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Sediment-ECM1` | Mooney et al. (2023): ECM1, 1° global crustal model, land and ocean, [doi:10.1016/j.earscirev.2023.104493](https://doi.org/10.1016/j.earscirev.2023.104493); the v1 product SED-M23 | `z_sed` (total), `z_sed_upper`, `z_sed_middle`, `z_sed_lower` (layers) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Sediment-ANTASed` | Baranov et al. (2021): ANTASed, 0.1° (11 km) map of the Antarctic continent (grounded ice and ice shelves, missing in the ocean), [doi:10.3389/feart.2021.722699](https://doi.org/10.3389/feart.2021.722699) | `z_sed` | Antarctica |
| `Sediment-Gowan2019` | Gowan et al. (2019): 5 km maps of the surface sediments of North America, Greenland and Iceland (areas of the former ice sheets; missing elsewhere), [doi:10.1594/PANGAEA.895889](https://doi.org/10.1594/PANGAEA.895889); the v1 product SED-G19 | `grain` (1 clay, 2 sand, 3 silt), `distribution` (1 blanket, 2 veneer, 3 rock), `composite` (0-8, both combined); classes | Laurentide |

Each file `<GRID>_Sediment-<Source>.nc` also has `f_valid`, the fraction of each cell
covered by the source. Each source is remapped conservatively; on grids finer than the
source it is then smoothed with a Gaussian of half the source spacing. The classes of
Gowan et al. (2019) are remapped as classes: each cell gets the class that covers most
of it. The global attribute `remap_method` records what was done on each grid.

## Licences

| Source | Licence |
|---|---|
| Laske et al. (2013), CRUST1.0 | No licence stated (cite Laske et al., 2013, and the REM web site); publishing assumed to be allowed |
| Straume et al. (2019), GlobSed v3 | CC BY 4.0 (PANGAEA, doi:10.1594/PANGAEA.982339) |
| Mooney et al. (2023), ECM1 | No licence stated (web site; article under Elsevier standard terms); publishing assumed to be allowed |
| Baranov et al. (2021), ANTASed | No licence stated for the data file (IEPT RAS web site; article CC BY 4.0); publishing assumed to be allowed |
| Gowan et al. (2019) | CC BY 4.0 (PANGAEA, doi:10.1594/PANGAEA.895889) |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap Sediment
```

See `GHF/README.md` for making single products and adding a source.
