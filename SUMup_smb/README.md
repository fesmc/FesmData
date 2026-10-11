# SUMup surface mass balance measurements (SUMup 2025)

Surface mass balance measurements of the Greenland and Antarctic ice sheets and their
peripheral glaciers (2.74 million measurements: ice cores, snow pits, stakes, surface
height ranging, ground and airborne radar), from the 2025 release of:

Vandecrux, B., Amory, C., Ahlstrøm, A. P., et al.: The SUMup collaborative database:
Surface mass balance, subsurface temperature and density measurements from the
Greenland and Antarctic ice sheets (2025 release), Arctic Data Center, 2025,
[doi:10.18739/A2M61BR5M](https://doi.org/10.18739/A2M61BR5M).

SUMup asks to cite also the original studies of the data used (the `reference` of each
measurement).

## Licence

CC0 1.0 (Arctic Data Center).

## Original data

Two NetCDF files of the release on the Arctic Data Center (no login), downloaded by
`prepare.jl`:

- `SUMup_2025_SMB_greenland.nc` (7 MB, datamanifest key `sumup2025_smb_greenland`);
- `SUMup_2025_SMB_antarctica.nc` (1.4 MB, `sumup2025_smb_antarctica`).

Each has a group `DATA` (one value per measurement: SMB and its error in m w.e., start
and end dates or years, latitude, longitude, elevation, and the keys of the name,
method and reference) and a group `METADATA` (the strings of the keys). The release
also has the SMB as CSV, a ReadMe (`SUMup_2025_ReadMe.pdf`), and the density (firn
and snow density by depth, 2.87 million measurements) and subsurface temperature
(2.87 million measurements at stations and depths) data, not used here: they would be
records of profiles (featureType profile or timeSeriesProfile).

## Prepare and record

```bash
julia --project=SUMup_smb SUMup_smb/prepare.jl
julia fesmdata.jl record SMBObs SUMup2025
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/SUMup_smb/SUMup2025_SMB.nc` (about 50 MB, see
`Records/README.md`), the measurements of both ice sheets, one per observation
(featureType point, dimension `obs`): `lat`, `lon`, `z_srf` (m, mostly missing),
`time` (days since 1900-01-01, the middle of the measurement interval) with
`time_bnds`, `smb_total` and `smb_total_sd` (kg m-2, the SMB of the interval), `smb`
and `smb_sd` (kg m-2 yr-1, the mean rate over the interval), and the keys `name_key`, `method_key`,
`reference_key` into the tables `name`, `method`, `reference` and `reference_short`
(along `name_table`, `method_table`, `reference_table`, with the keys
`<table>_key`).

Notes:

- SUMup gives the SMB accumulated over an interval (m w.e.), not a rate: from
  `start_date` to `end_date` where these are given, otherwise over the years
  `start_year` to `end_year`. The interval is written as `time_bnds` (from 1 January of
  `start_year` to 1 January after `end_year` when there are no dates). `smb_total` is
  the SMB of SUMup in kg m-2 (1000 × m w.e.), and `smb` the mean rate over the
  interval, `smb_total` / duration (kg m-2 yr-1, with years of 365.25 days). The
  intervals range from one day (daily ablation, 19681 measurements) to 197 years; the
  rates of the short ones are large (down to -70 000 kg m-2 yr-1 for a day of melt).
- `smb_total_sd` and `smb_sd` are the error of SUMup converted in the same way, as an
  absolute value (179 errors are negative in the source). They are missing for 60% of
  the measurements.
- The 12 measurements over an interval of length zero (stake readings of 0 in
  Greenland) are left out.
- The keys are those of SUMup; `method_key` is missing (-9999) for 16208 measurements
  (method "NA").
