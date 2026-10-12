# Basal melt rates of Antarctic ice shelves (Rignot et al., 2013)

Basal melt rates of the Antarctic ice shelves in 2007-2008, from the flux divergence of the
ice shelves, surface mass balance and thinning, on a 1 km polar stereographic grid
(EPSG:3031): the actual melt rate and the steady-state melt rate (that of ice shelves of
constant thickness). From:

Rignot, E., Jacobs, S., Mouginot, J., and Scheuchl, B.: Ice-shelf melting around
Antarctica, Science, 341, 266-270, 2013,
[doi:10.1126/science.1235798](https://doi.org/10.1126/science.1235798).

Data: Rignot, E., Mouginot, J., Scheuchl, B., and Jacobs, S.: Ice-shelf melting around
Antarctica, Dryad, 2025, [doi:10.5061/dryad.5hqbzkhg2](https://doi.org/10.5061/dryad.5hqbzkhg2).

## Licence

CC0 1.0 (Dryad).

## Original data

`Ant_MeltingRate.v2.nc` (502 MB) from Dryad, downloaded by hand in a browser (Dryad does
not allow scripted downloads) into `$DATAMANIFEST_DATASETS_DIR/rignot2013_melt_v2/`
(datamanifest key `rignot2013_melt_v2`).

The FesmData v1 product (`BMELT-R13`) was made from an earlier version of the file,
`Ant_MeltingRate.nc` (version "1.0 (v8Apr2012)", same grid and fields, without `lat`,
`lon`), kept in the old PIK archive (`hpc:/data/sicopolis/data/Antarctica/Ant_MeltingRate.nc`).
Its melt rates range from -26 to 123 m yr-1 (actual) and -33 to 118 m yr-1 (steady state);
those of version 2 from -10 to 158 m yr-1 and -9 to 153 m yr-1 (Dryad README).

## Prepare and remap

```bash
julia --project=Rignot2013_bmelt Rignot2013_bmelt/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Rignot2013_bmelt/Rignot2013_BMELT.nc Antarctica --name=BasalMelt-Rignot2013
```

`prepare.jl` writes `bmelt` (actual) and `bmelt_ss` (steady state), in m yr-1 ice
equivalent, positive for melting and negative for freezing, and their basin means
(`bmelt_basin`, `bmelt_eq_basin`, `bmelt_reese`, `bmelt_eq_reese`, see Basin means) to
`$FESMDATA_WORK/prepared/Rignot2013_bmelt/Rignot2013_BMELT.nc` (see `Remap/README.md`),
on the original grid (y made ascending). The basin means need the Regions basins on
ANT-1KM (`ANT-1KM_BASINS-Zwally2012.nc`), so Regions must be made first.

- **Units.** The file gives "meter/year" without saying ice or water equivalent. We
  take it as water equivalent: the mean rates of the grid over the Pine Island and
  Thwaites ice shelves (16.0 and 17.8 m yr-1, in the earlier file) agree with the
  shelf-mean rates of Table 1 of the article, which are its mass loss (Gt/yr) divided
  by the shelf area and the density of water. The rates are converted to ice
  equivalent with 1000/917.
- **Missing values.** The file has 0 outside the ice shelves; these cells are missing
  (NaN).

## Basin means

The means of the melt rates over the ice shelves of drainage basins, for models that
take one melt rate per basin (e.g. as the reference of a melt parameterisation):

- `bmelt_basin`, `bmelt_eq_basin`: mean of `bmelt`, `bmelt_ss` over each basin of the
  Regions basin set Zwally2012 (GSFC drainage systems 1-27, Zwally et al., 2012).
- `bmelt_reese`, `bmelt_eq_reese`: mean of `bmelt`, `bmelt_ss` over groups of these
  basins, those of `bm_ac_reese` and
  `bm_eq_reese` of the v1 product (see below).

The means are taken on the source grid, over the ice-shelf cells of each basin (or
group), the cells with a melt rate (of equal area, 1 km): the basins of ANT-1KM (whose
cells include those of the source grid) are extended over the open ocean to the nearest
basin (FesmUtils `extend_labels`), so that every cell with a rate is in a basin. Basin
25 (the northern Antarctic Peninsula) has no cell with a rate: it takes the mean over
the ice shelves of its neighbours, basins 24 and 26 together (also in `bmelt_reese` and `bmelt_eq_reese`,
where it is a group of its own).

The prepared file has one value per basin (fields on the dimension `basin`, with the
attribute `regions = "BASINS-Zwally2012"`), and the remapping sets on each grid every
cell to the value of its basin in `<GRID>_BASINS-Zwally2012.nc`, the cells outside the
basins (the open ocean beyond the shelf break, the outer cells of the grid) to that of
the nearest basin (see `Remap/README.md`): the fields are constant over each basin, the
same 27 values on all grids, and cover the whole grid (no `f_valid`).

**`bm_eq_reese` of v1.** The v1 product `BMELT-R13` was made with `gridding`
(`src/Rignot13_BasalMelt.f90`), which writes `bm_actual_ave` and `bm_equil_ave`, the
means of the remapped rates over the cells of each basin of `BASINS-nasa` (Zwally)
on the target grid. `bm_eq_reese` and `bm_ac_reese` ("basin average") were added to
the files later, by an undocumented step. On ANT-16KM, `bm_eq_reese` is constant over
groups of Zwally basins, 1-3, 7-8, 9-11, 15-16, 17-19 and 21-22 (the others alone),
with values (rounded to 0.001) equal to `bm_equil_ave` in the basins that are not
grouped (`bm_ac_reese` is constant over the same groups, a mean of `bm_actual`): the v1 basin means of `bm_equil` over merged basins, presumably those of the
basins of PICO (Reese et al., 2018), which merges Zwally basins. `bmelt_eq_reese`
uses these groups, with the rates of version 2 and means on the source grid
(m yr-1):

| Zwally basins | 1-3 | 4 | 5 | 6 | 7-8 | 9-11 | 12 | 13 | 14 | 15-16 | 17-19 | 20 | 21-22 | 23 | 24 | 25 | 26 | 27 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `bm_eq_reese` (v1) | 0.251 | 0.279 | 0.564 | 0.605 | 2.502 | 0.604 | 1.367 | 4.800 | -0.136 | 1.130 | 0.077 | 2.042 | 7.650 | 2.699 | 2.630 | 2.437 | 0.157 | 0.516 |
| `bmelt_eq_reese` | 0.239 | 0.412 | 0.431 | 0.562 | 3.851 | 0.496 | 1.335 | 5.758 | 1.028 | 1.190 | 0.071 | 2.139 | 12.155 | 2.066 | 2.341 | 1.195 (24 and 26) | 0.307 | 0.865 |
| `bm_ac_reese` (v1) | 0.391 | 0.031 | 0.399 | 0.622 | 1.430 | 0.909 | 2.325 | 5.284 | -0.783 | 1.525 (15), 1.085 | 0.063 | 2.953 | 12.066 | 2.912 | 3.167 | -0.177 | 0.165 | -0.247 |
| `bmelt_reese` | 0.387 | 0.211 | 0.275 | 0.527 | 2.919 | 0.882 | 2.414 | 6.836 | 0.372 | 1.346 | 0.070 | 3.347 | 17.469 | 2.229 | 2.927 | 1.432 (24 and 26) | 0.274 | 0.009 |

The v1 groups are the regions `basin_reese` of the v1 basin file `BASINS-nasa` (19
regions, values above on ANT-16KM), which follow the Zwally basins only roughly: region
10 is basin 15, region 11 most of 16 (with parts of 14, 15 and 17), region 12 basins
17-19 (with parts of 14 and 20), and region 1 also takes the edges of 4, 5 and 27. The
groups of `bmelt_reese` and `bmelt_eq_reese` are whole Zwally basins (15-16 one group).

The largest differences (Amundsen Sea, 21-22; 7-8; 14; 25) come from the rates of
version 2 (up to 153 m yr-1 at steady state, 118 in the earlier file) and from the
basins: the v1 basins were extended over the ocean on each grid, and the ice shelves
of a basin differ between the two sets.
