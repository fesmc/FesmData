# GLAC-1D extended to 80 ka with PaleoMIST 1.0

Global ice histories from 80 ka to present, for ice-load forcing of glacial isostatic
adjustment models, e.g. to compare with PaleoMIST 1.0, which spans the same time:

- North America + Greenland and Antarctica: the regional GLAC-1D reconstructions of
  `../Tarasov2012_glac1d/`, North America nn9894 (as in the PMIP4 GLAC-1D) or nn9927, with
  Greenland GrB, and Antarctica nn4041;
- elsewhere (Eurasia, Patagonia, mountain glaciers, ...): the global GLAC-1D of PMIP4
  (`../Tarasov2012_glac1d/`) from 26 ka, its oldest step, and PaleoMIST 1.0 (minimal MIS 3
  scenario, `../Gowan2021_PaleoMIST1.0/`) before.

References: those of `../Tarasov2012_glac1d/README.md` and Gowan, E. J. et al., Nat.
Commun., 12, 1199, 2021,
[doi:10.1038/s41467-021-21469-w](https://doi.org/10.1038/s41467-021-21469-w) (data:
[doi:10.1594/PANGAEA.905800](https://doi.org/10.1594/PANGAEA.905800)).

## Licence

GLAC-1D: none stated by the providers (cite the references). PaleoMIST 1.0: CC BY 4.0.
See the READMEs of the two sources.

## Original data

The prepared files of the two sources, which are prepared first if they are missing:
`Tarasov2012_GLAC1D_NA_nn9894.nc`, `Tarasov2012_GLAC1D_NA_nn9927.nc`,
`Tarasov2012_GLAC1D_ANT_nn4041.nc`, `Tarasov2012_GLAC1D_PMIP4_ice.nc` and
`Tarasov2012_GLAC1D_PMIP4_topo.nc` in `$FESMDATA_PREPARED/Tarasov2012_glac1d/`, and
`$FESMDATA_PREPARED/Gowan2021_PaleoMIST1.0/Gowan2021_PaleoMIST.nc`.

## Prepare and remap

```bash
julia -t 8 --project=Tarasov2012_glac1d_80k Tarasov2012_glac1d_80k/prepare.jl
julia fesmdata.jl remap IceHistory GLAC1D_80k GLAC1D_nn9927_80k
```

`prepare.jl` writes two files to `$FESMDATA_PREPARED/Tarasov2012_glac1d_80k/` (see
`Remap/README.md`), `Tarasov2012_GLAC1D_80k.nc` (North America nn9894, product
`GLAC1D_80k`) and `Tarasov2012_GLAC1D_nn9927_80k.nc` (nn9927, `GLAC1D_nn9927_80k`), on
the 0.5° x 0.25° grid of the PMIP4 ice thickness (global, longitudes in -180:180), with
`H_ice` (m) and `f_ice` (1) on (lon, lat, time).

- Time (years ago, before 1950 CE, oldest first): the steps of the regional
  reconstructions from 80 ka, where PaleoMIST starts, every 1 kyr to 30 ka and then
  every 100 years (351 steps).
- In each cell, with `w` the fraction of the cell covered by the regional grids (North
  America + Greenland, 170°W-11°W and 36°N-85°N; Antarctica, south of 59°S): `H_ice
  = w * H_regional + (1 - w) * H_rest` and `f_ice = w * f_regional + (1 - w) * f_rest`.
  The regional grids (1° x 0.5°) nest in the grid of the file, so `w` is 1 or 0 there, and
  the remapped products are the same combination with `w` the coverage of the regional
  products (their `f_valid`), fractional at the edges.
- `H_rest`: the PMIP4 GLAC-1D ice thickness (`HGLOBH`, on the grid of the file) at and
  after 26 ka; before, the PaleoMIST ice thickness (0.25°, remapped conservatively),
  linearly interpolated in time between its steps (every 2.5 kyr). The GLAC-1D thickness
  includes the ice shelves, that of PaleoMIST only the grounded ice.
- `f_ice`: each source's own ice fraction, combined as `H_ice`: the fraction with ice
  (`H_ice > 0`) of the regional grids (which have no ice mask), the PMIP4 ice mask
  (`ICEM`, 1° x 0.5°, remapped conservatively) at and after 26 ka, and the PaleoMIST
  `f_ice` (from its 5 km regional reconstructions, remapped, interpolated in time)
  before. So it keeps the extents of the sources, also where they differ from their
  thickness (the thin `HGLOBH` ice over Siberia and Alaska, where `ICEM` is 0, and the
  smoothed PaleoMIST thickness beyond its margins).

The rest of the globe changes source between 26.1 ka (PaleoMIST) and 26 ka (PMIP4
GLAC-1D), with a step in the ice volume there, mostly in Eurasia; it is not smoothed.
`prepare.jl` prints its size (the volume outside the regional grids at 26 ka from each
source) and the global ice volume at 80, 26, 21 and 0 ka.
