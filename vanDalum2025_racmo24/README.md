# Antarctic surface mass balance and surface climate (RACMO2.4p1; van Dalum et al., 2025)

Surface mass balance (SMB), its components and the near-surface climate of Antarctica
from the regional atmospheric climate model RACMO2.4p1, forced by ERA5, on its 11 km
rotated-pole grid (PXANT11), 1979-2025, from:

van Dalum, C. T., van de Berg, W. J., van den Broeke, M. R., and van Tiggelen, M.: The
surface mass balance and near-surface climate of the Antarctic ice sheet in RACMO2.4p1,
The Cryosphere, 19, 4061-4090, 2025,
[doi:10.5194/tc-19-4061-2025](https://doi.org/10.5194/tc-19-4061-2025).

Data: van Dalum, C., van de Berg, W. J., van den Broeke, M., and Hofsteenge, M.: Monthly
RACMO2.4p1 data for Antarctica (11 km) for SMB, SEB and near-surface variables
(1979-2025), version 2, Zenodo, 2026,
[doi:10.5281/zenodo.19255213](https://doi.org/10.5281/zenodo.19255213) (all versions:
[doi:10.5281/zenodo.14217231](https://doi.org/10.5281/zenodo.14217231)).

## Licence

CC BY 4.0 (Zenodo record and article).

## Original data

Zenodo record 19255213 (no login), downloaded by `prepare.jl` (DataManifest keys
`racmo24p1_ant11_*` in `datamanifest.toml`) to `$DATAMANIFEST_DATASETS_DIR/racmo24p1_ant11/`
(3.1 GB): `ANT11_masks.nc` and the monthly files
`<var>_monthly{S,A}_ANT11_RACMO2.4p1_ERA5_197901_202512.nc` of `smbgl`, `pr`, `sf`,
`totrunoff`, `mltgl`, `subltot` (monthly sums, kg m-2) and `tas`, `ts` (monthly means, K).

## Prepare and remap

```bash
julia --project=vanDalum2025_racmo24 vanDalum2025_racmo24/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/vanDalum2025_racmo24/RACMO2.4p1_1991-2020.nc Antarctica --name=SMB-RACMO2.4p1-1991-2020
```

`prepare.jl` (3 min, 6 GB memory: run it on a compute node) writes to
`$FESMDATA_WORK/prepared/vanDalum2025_racmo24/`:

- `RACMO2.4p1_1981-2010.nc`, `RACMO2.4p1_1991-2020.nc`: monthly climatologies
  (x, y, month);
- `RACMO2.4p1_annual_1979-2023.nc`: annual values (x, y, time).

Fields: `smb` (surface mass balance), `pr` (total precipitation), `sf` (snowfall), `runoff`
(meltwater runoff), `melt` (melt), `subl` (sublimation, negative, and deposition, positive,
including drifting snow), all in kg m-2 yr-1 (= mm w.e. yr-1), and `t2m` (2 m air
temperature) and `T_srf` (surface temperature) in K. Static fields in every file:
`z_srf` (RACMO surface elevation, m), `f_ice` (glaciated fraction, grounded and floating
ice), and the integer masks `mask_land` (land-sea mask; ice shelves are land) and
`mask_icesheet` (Antarctic ice sheet, grounded and floating, without peripheral
glaciers). RACMO2.4p1 has no grounded-ice mask.

## Notes

- Grid: the rotated-pole grid is regular in rotated longitude and latitude (0.1°). It is
  written as x, y = R · rotated longitude, latitude (radians), R = 6371229 m, with the
  PROJ string `+proj=ob_tran +o_proj=eqc +o_lat_p=-185.0 +lon_0=20.0 +R=6371229 +units=m`
  (equidistant cylindrical on the rotated sphere; spacing 11.12 km): the same cells, not
  regridded. It reproduces the lon, lat of the original files to 1e-6°.
- Units: the monthly sums are converted to rates, sum / days of the month × 365.25
  (kg m-2 yr-1), and averaged over the years for the climatologies; the annual values
  are the sums over the 12 months of each year. Temperatures are monthly means, and
  day-weighted annual means.
- `smb`, `runoff`, `melt` and `subl` are given by RACMO per unit glaciated area (IceMask ≥ 0.1)
  and are zero elsewhere; they are missing there in the prepared files. `pr`, `sf`,
  `t2m` and `T_srf` cover the whole domain (Antarctica, the Southern Ocean to about 40°S,
  and Patagonia).
- Sign: `smb = pr + subl - runoff` minus drifting-snow erosion (not included here).
- Years: only 1979-2023 are used. The months 2024-2025 appended in version 2 of the
  record were not post-processed like the earlier ones: the glaciated-surface fields are
  nonzero where IceMask = 0, and `subltot` is missing in January 2024.
- Coverage: the RACMO domain does not reach the outer corners of the Antarctica grids
  (ocean north of about 64°S on ANT-32KM; 5% of its cells), which are missing after
  remapping.

## Older version (v1)

FesmData v1 used RACMO2.3p2 forced by ERA5 at 27 km (ANT27), 1979-2022 (an update of van Wessem
et al., 2018, [doi:10.5194/tc-12-1479-2018](https://doi.org/10.5194/tc-12-1479-2018); Zenodo [doi:10.5281/zenodo.7760491](https://doi.org/10.5281/zenodo.7760491),
CC BY 4.0), remapped to ANT-16KM and ANT-32KM as
`$ICE_DATA/Antarctica/ANT-16KM/RACMO2.3/ANT-16KM_ERA5-3H_RACMO2.3p2_1979-2022_monthly.nc`
(t2m, precip, z_srf) and the RACMO2.3 ERA-Interim climatology 1981-2010
(`ANT-32KM_RACMO23-ERA-INTERIM_monthly_1981-2010.nc`, kg m-2 d-1). It is not prepared
here; RACMO2.4p1 replaces it.
