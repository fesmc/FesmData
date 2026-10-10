# ISMIP6 Antarctic ocean climatology (Jourdain et al., 2020)

Observed climatology (1995-2017) of the ocean around Antarctica used by ISMIP6, on the
ISMIP6 8 km polar stereographic grid with 60 m layers (30 levels, 30 to 1770 m depth):
potential temperature, practical salinity and thermal forcing (in situ temperature minus
in situ freezing point), and the basin values of DeltaT and gamma0 of the ISMIP6 melt
parameterizations (local and non-local quadratic; MeanAnt and PIGL calibrations, 5th,
50th and 95th percentiles) with the IMBIE2 basins they apply to. From:

Jourdain, N. C., Asay-Davis, X., Hattermann, T., Straneo, F., Seroussi, H., Little, C. M.
and Nowicki, S.: A protocol for calculating basal melt rates in the ISMIP6 Antarctic ice
sheet projections, The Cryosphere, 14, 3111-3134, 2020,
[doi:10.5194/tc-14-3111-2020](https://doi.org/10.5194/tc-14-3111-2020).

## Licence

The ISMIP6 forcing datasets are listed on Zenodo under CC BY 4.0
([doi:10.5281/zenodo.11176009](https://doi.org/10.5281/zenodo.11176009)), but the files
themselves are not there (see below).

## Original data

Only from the Globus endpoint GHub-ISMIP6-Forcing, after logging in at GHub
(<https://theghub.org/resources?id=4743>, Download tab). The files needed are:

- `AIS/Ocean_Forcing/climatology_from_obs_1995-2017/`:
  `obs_temperature_1995-2017_8km_x_60m.nc`, `obs_salinity_1995-2017_8km_x_60m.nc`,
  `obs_thermal_forcing_1995-2017_8km_x_60m.nc`;
- `AIS/Ocean_Forcing/parameterizations/`: `coeff_gamma0_DeltaT_quadratic_local_*.nc`,
  `coeff_gamma0_DeltaT_quadratic_non_local_*.nc`;
- `AIS/Ocean_Forcing/imbie2/`: `imbie2_basin_numbers_8km.nc`.

They are not prepared here yet: no copy of the thermal forcing, the parameters and the
basin numbers was found on Levante or in the old PIK archive. Copies of the temperature
and salinity files (renamed) are in
`/work/ba1442/ice_data/ISMIP6/Antarctica/ANT-8KM/ANT-8KM_{temperature,salinity}_1995-2017_J20.nc`.
The tools that made the climatology are at
[doi:10.5281/zenodo.6587885](https://doi.org/10.5281/zenodo.6587885) (code only).

The v1 files `ANT-<RES>_OCEAN_ISMIP6_J20.nc` have `to`, `so`, `tf` and `mask_ocn` on the
30 levels `z` and the DeltaT of each basin as maps (`dT_l`, `dT_nl`, `dT_l_pigl`,
`dT_nl_pigl`, each also with `_5` and `_95`). The v1 ANT-8KM file was interpolated from
ANT-16KM, so it is not the original data.
