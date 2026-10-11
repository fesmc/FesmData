# Northern Hemisphere ice-sheet extents through the Quaternary (Batchelor et al., 2019)

Best-estimate, minimum and maximum extents of the Northern Hemisphere ice sheets for 18
time slices, from the Late Gauss Chron (about 3 Ma) to the Last Glacial Maximum, mapped
from published evidence:

Batchelor, C. L., Margold, M., Krapp, M., Murton, D. K., Dalton, A. S., Gibbard, P. L.,
Stokes, C. R., Murton, J. B. and Manica, A.: The configuration of Northern Hemisphere ice
sheets through the Quaternary, Nat. Commun., 10, 3713, 2019,
[doi:10.1038/s41467-019-11601-2](https://doi.org/10.1038/s41467-019-11601-2).

## Licence

No licence is stated for the shapefiles on OSF (<https://osf.io/7jen3/>). The article is
published under CC BY 4.0. We assume that derived products may be published with a
citation of the article.

## Original data

The OSF project <https://osf.io/7jen3/> (no login): for each time slice, a folder
`hypothesised ice-sheet reconstructions` (`hypothesised ice-sheet reconstruction` for the
LGM) with the shapefiles `<slice>_best_estimate.shp`, `<slice>_min.shp` and
`<slice>_max.shp` (only `LGM_best_estimate.shp` for the LGM), on a north polar Lambert
azimuthal equal-area projection (the LGM in lon-lat). The project, as one zip made by OSF,
is `batchelor2019_nh_ice` in `datamanifest.toml`. OSF builds the zip slowly (30 min for
250 MB, with long pauses), so that the automatic download fails: download it by hand,

```bash
curl -L -o batchelor2019_nh_ice.zip "https://files.osf.io/v1/resources/7jen3/providers/osfstorage/?zip="
unzip -d $DATAMANIFEST_DATASETS_DIR/batchelor2019_nh_ice batchelor2019_nh_ice.zip
```

## Prepare and remap

```bash
julia -t 16 --project=Batchelor2019_NHIceMasks Batchelor2019_NHIceMasks/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Batchelor2019_NHIceMasks/Batchelor2019_NH_ICE.nc North --name=IceHistory-Batchelor2019
```

`prepare.jl` (a few minutes on 16 cores) writes
`$FESMDATA_WORK/prepared/Batchelor2019_NHIceMasks/Batchelor2019_NH_ICE.nc` (see
`Remap/README.md`) with `f_ice_best`, `f_ice_min` and `f_ice_max` (1), the area fraction
of each cell inside the best-estimate, minimum and maximum extents, on (x, y, time), and
the stage name of each time slice in `label`.

- Grid: 1 km on the polar stereographic projection of the North domain (x -5131 to
  4661 km, y -5421 to 4181 km, 9792 x 9602 cells), whose cell edges are on those of the
  North grids, so that remapping onto them is exact. It covers all outlines and all grids
  of the North, Laurentide, Eurasia, GreenlandPaleo and Greenland domains.
- Fractions: from 4 x 4 samples per cell (250 m); a polygon covers a sample if its centre
  is inside it (even-odd rule over the rings of each polygon, union of the polygons).
- Time: `time` in years ago (before 1950 CE), the ages assigned to the time slices in
  `time_slices.md`, oldest first. The paper lists the Early Matuyama Chron (2.2 Ma)
  before the Late Gauss Chron (3.1 Ma); here they are in the order of their age.
- The LGM has only a best estimate, which is also used as its minimum and maximum.
- Some shapefiles also contain present-day glaciers of the whole globe (Natural Earth
  glaciated areas). Those south of the equator, or entirely outside the grid (tropical
  glaciers), are left out; those in the grid are kept, as in the original files.

## Files of v1

`Batchelor2019_ice_masks_lgc.nc`, the last-glacial-cycle masks used by CLIMBER-X, and
`build_lgc_dataset.jl` are replaced by the hybrid last-glacial-cycle product (see
`IceHistory/README.md`). The v1 lon-lat (0.5°) and NH-32KM masks and their scripts are
replaced by `prepare.jl` and remapping.
