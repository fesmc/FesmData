# Antarctic surface mass balance and surface climate (RACMO2.3p2; van Wessem et al., 2023)

Surface mass balance (SMB), its components and the near-surface climate of Antarctica
from the regional atmospheric climate model RACMO2.3p2, forced by ERA5, on its 27 km
rotated-pole grid (ANT27), 1979-2022: an update of the ERA-Interim simulation of

van Wessem, J. M., van de Berg, W. J., Noël, B. P. Y., van Meijgaard, E., Amory, C.,
Birnbaum, G., Jakobs, C. L., Krüger, K., Lenaerts, J. T. M., Lhermitte, S., Ligtenberg,
S. R. M., Medley, B., Reijmer, C. H., van Tricht, K., Trusel, L. D., van Ulft, L. H.,
Wouters, B., Wuite, J., and van den Broeke, M. R.: Modelling the climate and surface mass
balance of polar ice sheets using RACMO2 - Part 2: Antarctica (1979-2016), The Cryosphere,
12, 1479-1498, 2018, [doi:10.5194/tc-12-1479-2018](https://doi.org/10.5194/tc-12-1479-2018).

Data: van Wessem, J. M., van de Berg, W. J., and van den Broeke, M. R.: Data set: Monthly
averaged RACMO2.3p2 variables; Antarctica, Zenodo, 2023,
[doi:10.5281/zenodo.7760491](https://doi.org/10.5281/zenodo.7760491).

## Licence

CC BY 4.0 (Zenodo record).

## Original data

Zenodo record 7760491 (no login), downloaded by `prepare.jl` (DataManifest keys
`racmo23p2_ant27_*` in `datamanifest.toml`) to `$DATAMANIFEST_DATASETS_DIR/racmo23p2_ant27/`
(0.4 GB): `Height_latlon_ANT27.nc` (orography, ice and grounded-ice masks) and the monthly
files `<var>_monthly{S,A}_ANT27_ERA5-3H_RACMO2.3p2_197901_202212.nc` of `smb`, `precip`,
`snowfall`, `runoff`, `snowmelt`, `subl` (monthly sums, kg m-2) and `t2m`, `tskin`
(monthly means, K).

## Prepare and remap

```bash
julia --project=vanWessem2023_racmo23 vanWessem2023_racmo23/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/vanWessem2023_racmo23/RACMO2.3p2_1991-2020.nc Antarctica --name=SMB-RACMO2.3p2-1991-2020
```

`prepare.jl` writes to `$FESMDATA_WORK/prepared/vanWessem2023_racmo23/`:

- `RACMO2.3p2_1981-2010.nc`, `RACMO2.3p2_1991-2020.nc`: monthly climatologies
  (x, y, month);
- `RACMO2.3p2_1985-2014.nc`: the monthly climatology of the reference period of the
  ISMIP7 experiments, a reference climate for model forcing, with `smb` complete (see
  Notes);
- `RACMO2.3p2_annual_1979-2022.nc`: annual values (x, y, time).

Fields, with the names and units of the RACMO2.4p1 products (`vanDalum2025_racmo24`):
`smb` (surface mass balance), `pr` (total precipitation), `sf` (snowfall), `runoff`
(meltwater runoff), `melt` (snow melt), `subl` (sublimation, negative, and deposition,
positive, including drifting snow), all in kg m-2 yr-1 (= mm w.e. yr-1), and `t2m` (2 m
air temperature) and `T_srf` (surface skin temperature) in K. Static fields in every file:
`z_srf` (RACMO surface elevation, m), `f_ice` (glaciated fraction, grounded and floating
ice) and the integer mask `mask_grounded` (grounded ice). RACMO2.3p2 has no land-sea mask:
all cells with f_ice = 0 are ocean.

## Notes

- Grid: the rotated-pole grid is regular in rotated longitude and latitude (0.25°). It is
  written as x, y = R · rotated longitude, latitude (radians), R = 6371229 m, with the
  PROJ string `+proj=ob_tran +o_proj=eqc +o_lat_p=-180.0 +lon_0=10.0 +R=6371229 +units=m`
  (equidistant cylindrical on the rotated sphere; spacing 27.8 km): the same cells, not
  regridded. It reproduces the lon, lat of the original files to 5e-5°.
- Units: the monthly sums are converted to rates, sum / days of the month × 365.25
  (kg m-2 yr-1), and averaged over the years for the climatologies; the annual values
  are the sums over the 12 months of each year. Temperatures are monthly means, and
  day-weighted annual means.
- `smb`, `runoff`, `melt` and `subl` are set missing where f_ice < 0.1 (RACMO2.3p2 gives
  smb near zero and `subl` as evaporation over the ocean there). `pr`, `sf`, `t2m` and
  `T_srf` cover the whole domain. In the reference climate 1985-2014, `smb` is
  `pr + subl` where f_ice < 0.1 (the surface mass balance without runoff, which is
  meaningful on glaciated surfaces only), so that it covers the whole domain as the
  forcing of a model whose ice may advance onto the ocean or land.
- Sign: `smb = pr + subl - runoff` minus drifting-snow erosion (not included here); `subl`
  is negative for sublimation, as in the source.

## Older version (v1)

FesmData v1 had a monthly climatology of this data release, remapped to ANT-8KM,
ANT-16KM and ANT-32KM as `$ICE_DATA/Antarctica/<grid>/RACMO2.3/<grid>_RACMO23-VW23.nc`
(smb in kg m-2 d-1, of an undocumented period), without a script to make it. The products
of this source replace it.
