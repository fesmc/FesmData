# Greenland temperature and precipitation, 20 ka to present (Badgeley et al., 2020)

Annual mean surface air temperature and precipitation over Greenland from 20 ka to
present, as 50-year means, from assimilating ice-core δ18O and accumulation records into
the TraCE-21ka simulation (offline ensemble Kalman filter). Temperature is an anomaly
and precipitation a fraction, both relative to 1850-2000 CE. The fields are on the T31
grid of TraCE-21ka (3.75° x ~3.7°, 86.25°W-3.75°W, 53.8-87.2°N). From:

Badgeley, J. A., Steig, E. J., Hakim, G. J., and Fudge, T. J.: Greenland temperature and
precipitation over the last 20 000 years using data assimilation, Clim. Past, 16,
1325-1346, 2020, [doi:10.5194/cp-16-1325-2020](https://doi.org/10.5194/cp-16-1325-2020).

Data: Badgeley, J. A., Steig, E. J., Hakim, G. J., and Fudge, T. J.: Reconstructions of
mean-annual Greenland temperature and precipitation for the past 20,000 years and the
ice-core records used to create the reconstructions, Arctic Data Center, 2020,
[doi:10.18739/A2599Z26M](https://doi.org/10.18739/A2599Z26M).

## Licence

CC0 1.0 (public domain dedication), as stated on the Arctic Data Center. Please cite
the article.

## Original data

From the Arctic Data Center, https://arcticdata.io/catalog/view/doi:10.18739/A2599Z26M
(no login), downloaded by `prepare.jl` (datamanifest keys `badgeley2020_tas_main`,
`badgeley2020_pr_main`, `badgeley2020_pr_low`, `badgeley2020_pr_high`):

- `tas_main_Badgeley_etal_2020.nc`: the main temperature reconstruction;
- `pr_main_Badgeley_etal_2020.nc`, `pr_low_...`, `pr_high_...`: the precipitation
  reconstructions from the moderate (main), low and high accumulation scenarios of the
  ice cores.

Each file has the posterior mean and its 5th and 95th percentiles on (time, lat, lon),
and the prior. The package also has four temperature sensitivity experiments
(`tas_S1` to `tas_S4`, other δ18O-temperature relationships) and the ice-core records
(CSV), not used here.

## Prepare and remap

```bash
julia --project=Badgeley2020_recon Badgeley2020_recon/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Badgeley2020_recon/Badgeley2020.nc GRL-8KM GRL-16KM GRL-32KM --name=Paleoclimate-Badgeley2020
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Badgeley2020_recon/Badgeley2020.nc` (see
`Remap/README.md`) with the posterior means on (lon, lat, time):

- `tas_anom` (K): temperature anomaly relative to 1850-2000 CE;
- `pr_frac`, `pr_frac_low`, `pr_frac_high` (1): precipitation relative to 1850-2000 CE,
  from the moderate, low and high accumulation scenarios.

Notes:

- `time` is the age in years BP (before 1950 CE), 20000 to 0 in steps of 50 years,
  oldest first. The original files give its units as "ka", but the values are years.
- Longitudes are converted from 0:360 to -180:180.
- The latitudes are the Gaussian latitudes of T31, spaced 3.68° to 3.71° (not exactly
  uniform), kept as they are.
- The grid covers 88.1°W to 1.9°W (cell edges): the corners of the Greenland domain
  east of 1.9°W and west of 88.1°W are left missing (`f_valid` < 1).
- The source cells are about 400 km wide, so grids finer than 8 km add nothing; the
  remapped files are about 20 MB on GRL-32KM and 0.3 GB on GRL-8KM.
