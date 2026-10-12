# IceChange: observed recent change of the ice sheets

Observed recent change of the Antarctic and Greenland ice sheets, remapped onto the grids
of the domains: for now, rates of surface elevation change and ice thickness change from
satellite laser altimetry; later possibly mass change, and changes of the grounding line
and the ice front. IceChange is a thematic dataset made by remapping (see Bring your own
data, `Remap/README.md`): its products are defined in `IceChange/remap.toml`. Each
source has a product per ice sheet (`-ANT`, `-GRL`), on the grids of 4 km and coarser.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `IceChange-ATL15-ANT` | ICESat-2 ATL15 v6 (Smith et al., 2026): linear trend of the quarterly 1 km height change, 2019 to 2026 (cycles 03-31), [doi:10.5067/ATLAS/ATL15.006](https://doi.org/10.5067/ATLAS/ATL15.006) | `dzdt` (surface elevation change rate, m yr-1) | Antarctica |
| `IceChange-ATL15-GRL` | as above, Greenland and its peripheral ice caps | `dzdt` | Greenland |
| `IceChange-Smith2020-ANT` | Smith et al. (2020): ICESat (2003-2009) to ICESat-2 (2018-2019), 5 km, grounded and floating ice, [doi:10.1126/science.aaz5845](https://doi.org/10.1126/science.aaz5845), data <http://hdl.handle.net/1773/45388> | `dzdt` (surface elevation change rate of the grounded ice), `dHdt` (ice thickness change rate, ice equivalent, grounded and floating ice), m yr-1 | Antarctica |
| `IceChange-Smith2020-GRL` | as above, Greenland ice sheet (grounded ice) | `dzdt` | Greenland |

`dzdt` is the rate of change of the surface elevation, including the changes of the
firn. `dHdt` is the rate of change of the ice thickness in ice equivalent: the surface
elevation change corrected for changes in firn air content and, over floating ice,
converted from elevation change by hydrostatic equilibrium.

ATL15 gives the height change of each quarter relative to 2020 (and rates over moving
windows of up to 7 years); `dzdt` is the linear trend over the whole record in each
1 km cell, the unweighted least-squares fit over the quarters with data and ice in the
cell, and missing where fewer than 75% of the quarters have them (e.g. moving ice
fronts). The period and the number of quarters are in the global attributes of the
files. See `ATL15_dzdt/README.md`.

Smith et al. (2020) give over floating ice only thickness changes, so `dzdt` of
`IceChange-Smith2020-ANT` covers the grounded ice only, and `dHdt` both the grounded and
the floating ice, which are on 5 km grids of their own in the source and are combined on
each grid (see `Remap/README.md`): where a cell has both, `dHdt` is their mean weighted
by the area of each. Greenland has no `dHdt`, as Smith et al. (2020) have no firn
correction there. There are no data south of about 86°S (not covered by ICESat).
Integrated over the ice, the surface elevation change of the grounded ice of Antarctica
is -130 km3 yr-1, its thickness change -127 km3 yr-1 (-116 Gt yr-1 of ice; Smith et al.,
2020: -118 Gt yr-1) and that of the floating ice +16 km3 yr-1; the surface elevation
change of Greenland is -250 km3 yr-1. See `Smith2020_dzdt/README.md`.

Each file also has `f_valid`, the fraction of each cell covered by the source
(`f_valid_<field>` where the fields differ). The fields are remapped conservatively,
and smoothed on the grids finer than the source (4 km, for the 5 km grids of Smith et
al., 2020).

## Licences

| Source | Licence |
|---|---|
| ICESat-2 ATL15 v6 | NASA Earth science data (NSIDC), no restrictions on use; cite the data set |
| Smith et al. (2020) | CC BY 3.0 US (UW ResearchWorks); cite the article |

## Making the dataset

```bash
julia -t 8 fesmdata.jl remap IceChange
julia -t 8 fesmdata.jl remap IceChange Smith2020-ANT Smith2020-GRL   # some products
```

This prepares the sources not prepared yet (`<source>/prepare.jl`). ATL15 needs a
manual download first (NASA Earthdata login, 13 GB, see `ATL15_dzdt/README.md`), and
its preparation reads all of it (about 2 GB of memory per quadrant).
