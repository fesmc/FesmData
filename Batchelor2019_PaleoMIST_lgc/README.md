# Ice masks of the last glacial cycle: Batchelor et al. (2019) and PaleoMIST 1.0

Global ice area fractions from 80 ka to the Last Glacial Maximum, combining two sources:

- Northern Hemisphere: the ice-sheet extents of Batchelor et al. (2019), best estimate,
  minimum and maximum (`../Batchelor2019_NHIceMasks/`);
- Southern Hemisphere: the ice area fraction derived from PaleoMIST 1.0 (Gowan et al.,
  2021; `../Gowan2021_PaleoMIST1.0/`), the same for the best estimate, minimum and
  maximum.

It replaces `Batchelor2019_ice_masks_lgc.nc` of v1 (made by
`Batchelor2019_NHIceMasks/build_lgc_dataset.jl`, Northern Hemisphere only, 0.5°, time in
negative years from MIS 6), used by CLIMBER-X as the target extent of its synthetic
ice-sheet geometry (`ice_syn_par.nml`, `mask_file`).

References: Batchelor, C. L. et al., Nat. Commun., 10, 3713, 2019,
[doi:10.1038/s41467-019-11601-2](https://doi.org/10.1038/s41467-019-11601-2); Gowan, E. J. et
al., Nat. Commun., 12, 1199, 2021,
[doi:10.1038/s41467-021-21469-w](https://doi.org/10.1038/s41467-021-21469-w) (data:
[doi:10.1594/PANGAEA.905800](https://doi.org/10.1594/PANGAEA.905800)).

## Licence

Batchelor et al. (2019): no licence stated for the shapefiles (OSF), article CC BY 4.0.
PaleoMIST 1.0: CC BY 4.0. See the READMEs of the two sources.

## Original data

The prepared files of the two sources, which are prepared first if they are missing:
`$FESMDATA_WORK/prepared/Batchelor2019_NHIceMasks/Batchelor2019_NH_ICE.nc` and
`$FESMDATA_WORK/prepared/Gowan2021_PaleoMIST1.0/Gowan2021_PaleoMIST.nc`.

## Prepare and remap

```bash
julia -t 16 --project=Batchelor2019_PaleoMIST_lgc Batchelor2019_PaleoMIST_lgc/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Batchelor2019_PaleoMIST_lgc/Batchelor2019_PaleoMIST_LGC.nc Global --name=IceHistory-Batchelor2019_PaleoMIST_LGC
```

`prepare.jl` writes
`$FESMDATA_WORK/prepared/Batchelor2019_PaleoMIST_lgc/Batchelor2019_PaleoMIST_LGC.nc` (see
`Remap/README.md`) on a global 0.1° lon-lat grid (that of `GLOBAL-0.1DEG`) with
`f_ice_best`, `f_ice_min` and `f_ice_max` (1) on (lon, lat, time), and per time slice its
`label` and `time_paleomist`, the time of PaleoMIST used in the Southern Hemisphere.

- Time (years ago, before 1950 CE): the Batchelor slices from MIS 5a to the LGM at the
  ages of `../Batchelor2019_NHIceMasks/time_slices.md`, 80000 (MIS 5a), 65000 (MIS 4),
  45000, 40000, 35000, 30000 and 26500 (LGM), and the LGM again at 21000 (the PMIP LGM),
  so that it is held from 26.5 to 21 ka. Nothing older than 80 ka, where PaleoMIST
  starts.
- Southern Hemisphere: PaleoMIST at the time nearest to each slice, ties to the older:
  80000, 65000, 45000, 40000, 35000, 30000, 27500 (for 26500) and 20000 (for 21000).
- The hemispheres are split at the equator, a cell edge of the grid: neither source has
  ice-sheet ice near it (Batchelor's files contain present-day glaciers, which are left
  out south of the equator; PaleoMIST has no Northern Hemisphere ice outside the Batchelor
  area).
- Northern Hemisphere: the 1 km Batchelor fractions remapped conservatively (5 x 5 samples
  per 0.1° cell); 0 outside the Batchelor grid (which covers all its outlines). Southern Hemisphere: the
  PaleoMIST `f_ice` (0.25°) remapped conservatively (exact).

Differences from the v1 file: fractions instead of a 0/1 mask, the minimum and maximum
extents, global instead of 0-90°N, time in years ago (positive) instead of negative years,
and from MIS 5a instead of MIS 6.
