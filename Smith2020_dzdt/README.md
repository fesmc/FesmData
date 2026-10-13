# Ice sheet height and thickness change 2003-2019 (Smith et al., 2020)

Rates of surface height change and ice thickness change of the Antarctic and Greenland
ice sheets between ICESat (2003-2009) and ICESat-2 (2018-2019), at 5 km on polar
stereographic grids (EPSG:3031, EPSG:3413):

Smith, B., Fricker, H. A., Gardner, A. S., Medley, B., Nilsson, J., Paolo, F. S.,
Holschuh, N., Adusumilli, S., Brunt, K., Csatho, B., Harbeck, K., Markus, T., Neumann,
T., Siegfried, M. R. and Zwally, H. J.: Pervasive ice sheet mass loss reflects competing
ocean and atmosphere processes, Science, 368(6496), 1239-1242, 2020,
[doi:10.1126/science.aaz5845](https://doi.org/10.1126/science.aaz5845).

Data: Ice-sheet height and thickness changes from ICESat to ICESat-2, University of
Washington ResearchWorks, 2020, updated February 2021,
<http://hdl.handle.net/1773/45388>.

## Licence

CC BY 3.0 US (ResearchWorks). Cite the article.

## Original data

The archive `ICESat1_ICESat2_mass_change_updated_2_2021.zip` (12 MB), datamanifest key
`smith2020_dhdt`, downloaded by `prepare.jl` to `$FESMDATA_SOURCES/smith2020_dhdt.zip`
and extracted next to it. ResearchWorks now redirects to a UW login, so the archive is
taken from the Internet Archive (capture of 2023-09-05); it is identical to the original
(sha256 `8d09ffcce4e84fba8cabbc85ee79fec4de36419f8b242ca1f95adacaa2f229e3`, the checksum
used by polartoolkit for the ResearchWorks file).

The archive has two sets of GeoTIFFs, in m yr-1 of ice:

- `dhdt/`: surface height change rates of the grounded ice; over floating ice, thickness
  change rates converted from height change by hydrostatic equilibrium;
- `dmdt/`: the same corrected for changes in firn air content, i.e. ice thickness change
  rates (ice equivalent). For Greenland there is no firn correction: `gris_dmdt.tif` is
  identical to `gris_dhdt.tif`.

each with `ais_<set>_grounded.tif`, `ais_<set>_floating.tif` (Antarctica) and
`gris_<set>.tif` (Greenland), unfiltered (for mass budgets), smoothed for display
(`_filt`, `_filt_rgb`) and their RMSE (`_rmse`).

## Prepare

```bash
julia --project=Smith2020_dzdt Smith2020_dzdt/prepare.jl
```

`prepare.jl` (a few seconds) writes the unfiltered grids on their own grids to
`$FESMDATA_PREPARED/Smith2020_dzdt/`, in m yr-1:

| File | Fields | Grid |
|---|---|---|
| `Smith2020_GRL.nc` | `dzdt` (surface elevation change rate, `gris_dhdt.tif`) | 5 km, EPSG:3413, 289 x 513 |
| `Smith2020_ANT.nc` | `dzdt` (surface elevation change rate, `ais_dhdt_grounded.tif`), `dHdt` (ice thickness change rate, ice equivalent, `ais_dmdt_grounded.tif`) | 5 km, EPSG:3031, 1035 x 863 |
| `Smith2020_ANT_floating.nc` | `dHdt` (ice thickness change rate, ice equivalent, `ais_dmdt_floating.tif`) | about 5 km, EPSG:3031, 1073 x 915 |

`dzdt` is the surface elevation change of the grounded ice only: over floating ice the
archive gives thickness changes. Greenland has no `dHdt`, as it has no firn correction.
The grid of the floating ice is not that of the grounded ice (its cell edges are offset
by about 4.5 km in x and 1.5 km in y, and its GeoTIFF gives a spacing of 5000.01 m x
5001.19 m), so it is written to a file of its own, on its grid as given; the two files
of Antarctica make one product, `IceChange-Smith2020-ANT`, whose `dHdt` combines them on
each grid (see `IceChange/README.md`). The smoothed grids and the RMSE are left out.

## Remap

```bash
julia -t 8 fesmdata.jl remap IceChange Smith2020-ANT Smith2020-GRL
```
