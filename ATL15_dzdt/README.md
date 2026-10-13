# Ice sheet surface elevation change from ICESat-2 (ATL15 v6)

Gridded height change of the land ice of Antarctica and the Arctic from ICESat-2
repeat-track data (ATL11), quarterly at 1 km on polar stereographic grids (EPSG:3031,
EPSG:3413), cycles 03-31 (2019 to April 2026):

Smith, B., Sutterley, T., Dickinson, S., Jelley, B. P., Felikson, D., Neumann, T. A.,
Fricker, H., Gardner, A., Padman, L., Markus, T., Kurtz, N., Bhardwaj, S., Hancock, D.
and Lee, J.: ATLAS/ICESat-2 L3B Gridded Antarctic and Arctic Land Ice Height Change
(ATL15, Version 6), NASA NSIDC DAAC, 2026,
[doi:10.5067/ATLAS/ATL15.006](https://doi.org/10.5067/ATLAS/ATL15.006).

## Licence

NASA Earth science data (NSIDC DAAC): open, with no restrictions on use or
redistribution. NSIDC asks to cite the data set.

## Original data

ATL15 v6, https://nsidc.org/data/atl15/versions/6, needs a NASA Earthdata login. The
quarterly 1 km files of the four Antarctic quadrants (A1-A4, split along the 90°
meridians) and of Greenland (GL), 13.3 GB in all, go to
`$FESMDATA_SOURCES/atl15_v006/` (datamanifest key `atl15_v006`). With a
`~/.netrc` for urs.earthdata.nasa.gov:

```bash
mkdir -p $FESMDATA_SOURCES/atl15_v006
cd $FESMDATA_SOURCES/atl15_v006
for f in ATL15_A1_0331_3mo_1km_006_02.nc ATL15_A2_0331_3mo_1km_006_02.nc \
         ATL15_A3_0331_3mo_1km_006_02.nc ATL15_A4_0331_3mo_1km_006_02.nc \
         ATL15_GL_0331_3mo_1km_006_01.nc; do
    curl -n -L -c ~/.urs_cookies -b ~/.urs_cookies -O \
        https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/ATLAS/ATL15/006/2019/01/01/$f
done
```

Each file has the height change `delta_h` relative to 1 January 2020 for each quarter
(group `delta_h`, with its uncertainty and the ice-covered area of each cell
`ice_area`, which changes with time in Antarctica), and height change rates over
moving windows of up to 7 years (groups `dhdt_<n>mo`), none of which spans the whole
record.

## Prepare

```bash
julia --project=ATL15_dzdt ATL15_dzdt/prepare.jl
```

`prepare.jl` writes `dzdt`, the surface elevation change rate (m yr-1) over the whole
record, on the 1 km grid of the product to `$FESMDATA_PREPARED/ATL15_dzdt/`:
`ATL15_ANT.nc` (the four quadrants merged on their common grid, the mean where they
overlap) and `ATL15_GRL.nc` (Greenland and its peripheral ice caps).

`dzdt` is the linear trend of `delta_h` in each cell: the unweighted least-squares fit
against time over the valid quarters of the cell, those with `delta_h` and ice in the
cell (`ice_area > 0`). It is missing where fewer than 75% of the quarters of the record
are valid (e.g. ice fronts that advanced or retreated). The period, the number of
quarters and the rule are in the global attributes (`time_coverage_start`,
`time_coverage_end`, `n_quarters`, `min_valid_quarters`, `comment`).
