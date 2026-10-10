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
Its melt rates range from -26 to 123 m/yr (actual) and -33 to 118 m/yr (steady state);
those of version 2 from -10 to 158 m/yr and -9 to 153 m/yr (Dryad README).

## Prepare and remap

```bash
julia --project=Rignot2013_bmelt Rignot2013_bmelt/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Rignot2013_bmelt/Rignot2013_BMELT.nc Antarctica --name=BasalMelt-Rignot2013
```

`prepare.jl` writes `bmelt` (actual) and `bmelt_ss` (steady state), in m/yr ice
equivalent, positive for melting and negative for freezing, to
`$FESMDATA_WORK/prepared/Rignot2013_bmelt/Rignot2013_BMELT.nc` (see `Remap/README.md`),
on the original grid (y made ascending).

- **Units.** The file gives "meter/year" without saying ice or water equivalent. We
  take it as water equivalent: the mean rates of the grid over the Pine Island and
  Thwaites ice shelves (16.0 and 17.8 m/yr, in the earlier file) agree with the
  shelf-mean rates of Table 1 of the article, which are its mass loss (Gt/yr) divided
  by the shelf area and the density of water. The rates are converted to ice
  equivalent with 1000/917.
- **Missing values.** The file has 0 outside the ice shelves; these cells are missing
  (NaN).
