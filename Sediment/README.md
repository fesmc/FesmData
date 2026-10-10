# Sediment: sediment thickness

Sediment thickness (m) from global maps, remapped onto the grids of the domains and
onto global lon-lat grids. Sediment is a thematic dataset made by remapping (see Bring
your own data, `Remap/README.md`): its products are defined in `Sediment/remap.toml`.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `Sediment-CRUST1` | Laske et al. (2013): CRUST1.0, 1° global crustal model, land and ocean ([igppweb.ucsd.edu/~gabi/crust1.html](https://igppweb.ucsd.edu/~gabi/crust1.html)); its sediments are essentially those of Laske and Masters (1997), the v1 product SED-L97 | `z_sed` (total), `z_sed_upper`, `z_sed_middle`, `z_sed_lower` (layers) | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |
| `Sediment-GlobSed` | Straume et al. (2019): GlobSed v3, 5' total sediment thickness of the oceans (missing on land), [doi:10.1029/2018GC008115](https://doi.org/10.1029/2018GC008115) | `z_sed` | Antarctica, GreenlandPaleo, Greenland, North, Laurentide, Eurasia, Global |

Each file `<GRID>_Sediment-<Source>.nc` also has `f_valid`, the fraction of each cell
covered by the source. Each source is remapped conservatively; on grids finer than the
source it is then smoothed with a Gaussian of half the source spacing. The global
attribute `remap_method` records what was done on each grid.

## Licences

| Source | Licence |
|---|---|
| Laske et al. (2013), CRUST1.0 | No licence stated (cite Laske et al., 2013, and the REM web site); publishing assumed to be allowed |
| Straume et al. (2019), GlobSed v3 | CC BY 4.0 (PANGAEA, doi:10.1594/PANGAEA.982339) |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap Sediment
```

See `GHF/README.md` for making single products and adding a source.
