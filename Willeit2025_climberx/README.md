# CLIMBER-X Dansgaard-Oeschger and Heinrich events (Willeit et al., 2025)

Output of the Earth system model of intermediate complexity CLIMBER-X v1.0 (5° x 5°)
from two simulations of Willeit et al. (2025): their reference simulation `HS4`, 8000
years under mid-glacial (MIS3) conditions with self-sustained Dansgaard-Oeschger
oscillations of the Atlantic overturning and a Heinrich event, and a preindustrial
control (`piControl`). From them, the climate states of interstadials, stadials and the
Heinrich stadial, with their anomalies relative to the preindustrial control, and the
transient output of both runs with their time series.

- Willeit, M., Ganopolski, A., Kaufhold, C., Dalmonech, D., Liu, B., and Ilyina, T.:
  Earth system response to Heinrich events explained by a bipolar convection seesaw,
  Nat. Geosci., 18, 1159-1166, 2025,
  [doi:10.1038/s41561-025-01814-0](https://doi.org/10.1038/s41561-025-01814-0).
- Model: Willeit, M., Ganopolski, A., Robinson, A., and Edwards, N. R.: The Earth system
  model CLIMBER-X v1.0 - Part 1: Climate model description and validation, Geosci.
  Model Dev., 15, 5905-5948, 2022,
  [doi:10.5194/gmd-15-5905-2022](https://doi.org/10.5194/gmd-15-5905-2022).

## Licence

CC BY 4.0, as the article: cite both papers. The model output is not public; it was
provided by M. Willeit (2026) for FesmData.

## Original data

The output as written by CLIMBER-X, one folder per run, on Levante in
`/work/ba1442/data/Willeit2025/` (137 GB; `$FESMDATA_SOURCES/willeit2025_climberx` links
to it, `datamanifest.toml` entry `willeit2025_climberx`, no download):

| Run | Folder | Set-up (`run_info.txt`) |
|---|---|---|
| `HS4` | `HS4_Hamp_1.0/` | MIS3 ice sheets and topography (`geo_ice_mis3.nc`), orbit fixed at 40 ka, CO2 interactive from 200 ppm (198-215 ppm), CH4 425 ppb, N2O 230 ppb; freshwater noise over the North Atlantic (50-80N, amplitude 0.5 kg m-2 d-1); Heinrich event: freshwater hosing over 40-60N, 70-10W from model year 2500 (`Calov_Heinrich2_x1.0.nc`, up to 0.13 Sv); model years -40000 to -32000 |
| `piControl` | `ice_tarasov_0ka_co2_280ppm/` | present-day ice sheets, CO2 280 ppm, the same noise; hosing from model year 5000 (`Calov_Heinrich2.nc`); model years 1 to 10000 |

Each run has the 2D output of its components (`atm.nc`, `ocn.nc`, `sic.nc`, ...: the
monthly means of one model year, and their annual mean as month 13, written every 10
years for `HS4` and every 1000 years for `piControl`; `cmn.nc` every 1000 years) and
annual time series (`*_ts.nc`). The atmosphere, ocean and sea ice share the 5° grid
(lon -177.5:177.5, lat -87.5:87.5), that of `GLOBAL-5DEG`. The ocean has 23 levels to
about 5000 m, whose depths differ between the runs by up to 0.6%.

## Prepare and remap

```bash
julia --project=Willeit2025_climberx Willeit2025_climberx/prepare.jl
julia fesmdata.jl remap Paleoclimate
```

`prepare.jl` writes, to `$FESMDATA_PREPARED/Willeit2025_climberx/`, on the model grid:

- `CLIMBERX_Willeit2025_<run>_transient.nc`: the 2D records of the run every 100 years
  (`time`; `HS4`: every 10th record, single model years; `piControl`: all):
  `t2m_mon` (2 m air temperature, `t2a`), `pr_mon` (precipitation, `prc`), `sst_mon`,
  `f_sic_mon` (sea-ice fraction, over the ocean), monthly; the boundary conditions
  `z_srf` (surface elevation of the atmosphere, `zsa`), `f_land`, `f_ice`; the state of
  each record (`state`) and the smoothed overturning it is classified by
  (`amoc_smooth`); and the annual time series (`time_ann`): `amoc`, `amoc26N`, `aabw`,
  `hosing`, `buoy_na55` (buoyancy flux north of 55N, see the article), `sst_glob`,
  `to_deep`, `t2m_glob`, `t2m_nh`, `t2m_sh`, `t2m_grl` (NGRIP), `t2m_ant`, `t2m_natl`,
  `co2`, and the monthly sea-ice extent `sic_ext_nh`, `sic_ext_sh`.
- `CLIMBERX_Willeit2025_<run>_transient_ocean.nc`: `to` (potential temperature), `so`
  (salinity), annual means on `depth`, and the Atlantic overturning streamfunction
  `moc_atl` on latitude (`lat_moc`) and depth (`depth_w`, tops of the levels).
- `CLIMBERX_Willeit2025_<state>.nc`, `..._<state>_ocean.nc`: the climate states, means
  of the 2D records of each state: the fields above (monthly and annual, `*_mon`,
  `*_ann`), and for the states of `HS4` their anomalies relative to `piControl`
  (`*_anom`, state minus piControl; ocean by model level).

Time: `HS4` in years ago (the model calendar: -40000 is 40 ka), `piControl` in model
years. Units: degC, mm d-1, psu, Sv.

### Climate states

The 2D records are classified by the maximum of the Atlantic overturning
streamfunction, as its centred 51-year running mean (the annual series `amoc`), the
interstadials and stadials only without freshwater hosing (below 0.01 Sv; after the
Heinrich event, the hosing file leaves 0.001 Sv):

| State | Rule | Records (years) |
|---|---|---|
| `interstadial` | AMOC >= 16 Sv | 343 |
| `stadial` | 6 <= AMOC <= 13 Sv | 243 |
| `heinrich` | AMOC < 3 Sv (Heinrich stadial, collapsed overturning) | 162 |
| `piControl` | the records of `piControl` before its hosing starts (model years 1000-5000) | 5 |

The overturning has three modes in `HS4` (about 25-35 Sv, 8-12 Sv and below 2 Sv); the
records between them (the transitions, 52) are in no state. A state is the mean over its
records, each a single model year: the stadial and interstadial means average over
the internal variability of the noise and of the oscillations themselves (e.g. the
gradual cooling of the interstadials).

They are remapped as the products `Paleoclimate-CLIMBERX-Willeit2025-<state>` and
`...-<state>-ocean` (`../Paleoclimate/remap.toml`), and the transient files as
`...-<run>-transient` and `...-<run>-transient-ocean` on `GLOBAL-5DEG` only (the model
grid, unchanged up to the rounding), for models to remap online. The fields are
remapped as they are, without a lapse-rate correction: use `z_srf` to correct the
temperatures for the surface elevation of the model (that of the MIS3 ice sheets in
`HS4`).
