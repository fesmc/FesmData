# ERA5 monthly-averaged data (radiation + moist stack)

Monthly-averaged ERA5 reanalysis for building and validating the model's
radiation scheme and moist column. Two Copernicus CDS datasets, regular
2.5°×2.5° lat-lon (plenty for T31), NetCDF, over **1991–2020**. We regrid /
interpolate to our sigma levels on ingest.

- `reanalysis-era5-pressure-levels-monthly-means` — all 37 pressure levels (1000→1 hPa)
- `reanalysis-era5-single-levels-monthly-means`

Data is downloaded to `~/data/era5/` (not stored in this repo).

## Source

Copernicus Climate Data Store (CDS): https://cds.climate.copernicus.eu

- Pressure levels: https://cds.climate.copernicus.eu/datasets/reanalysis-era5-pressure-levels-monthly-means
- Single levels: https://cds.climate.copernicus.eu/datasets/reanalysis-era5-single-levels-monthly-means

## One-time setup

1. Create a free CDS account and accept the ERA5 licence (once per dataset,
   via the "Download" tab of each dataset page above).

2. Install the client:

   ```bash
   pip install cdsapi
   ```

3. Create `~/.cdsapirc` with your personal API key (find it on your CDS
   profile page, https://cds.climate.copernicus.eu/profile):

   ```
   url: https://cds.climate.copernicus.eu/api
   key: <YOUR-API-KEY>
   ```

   > Note: the current (post-2024) CDS uses just the raw API key — no `UID:`
   > prefix like the retired legacy CDS.

## Download

[`download_era5.py`](download_era5.py) drives the CDS API. It downloads **one
NetCDF file per variable**, skips files that already exist (so it is safely
restartable — CDS requests queue and can take a while), and covers all 30 years
× 12 months (360 timesteps per file).

```bash
# Everything (both datasets, tiers 1 and 2)  -> 37 files
python download_era5.py

# Tier 1 only (radiation stack) -- minimal set to unblock radiation  -> 23 files
python download_era5.py --tier 1

# Just the pressure-level fields, tier 2
python download_era5.py --dataset pressure --tier 2

# Preview the exact CDS requests, download nothing
python download_era5.py --dry-run

# Skip the optional wind components (u, v)
python download_era5.py --no-optional
```

Output layout:

```
~/data/era5/monthly-pressure-levels/era5_monthly-pressure-levels_<short>_1991-2020.nc
~/data/era5/monthly-single-levels/era5_monthly-single-levels_<short>_1991-2020.nc
```

## Climatology (12 monthly means)

The CDS monthly-means products only serve **per-year-month** means; there is no
native 1991–2020 climatology. So we download all 30 years and collapse to the
12-month climatology on ingest:

```bash
./make_climatology.sh
```

This runs `cdo ymonmean` on each `*_1991-2020.nc` and writes `*_1991-2020_clim.nc`
(12 timesteps) alongside it. Idempotent.

## Ingest notes

- **Fluxes** come as accumulations in **J/m²** (accumulated over the monthly-mean
  time step). Convert to **W/m²** on ingest by dividing by the accumulation
  period in seconds (for these monthly means, the per-day accumulation window,
  i.e. 86400 s). Verify sign conventions against the CDS variable documentation.
- **Geopotential** (`z`) on single levels is invariant → divide by g₀ for surface
  **orography**.
- **Cloud radiative effect** = all-sky − clear-sky (e.g. `ttr − ttrc`).

## Variables

Priority: **Tier 1** alone unblocks building and validating radiation. **Tier 2**
is for turning on clouds and validating the moist column.

### Pressure levels (all 37 levels)

| Tier | CDS name | short |
|------|----------|-------|
| 1 | `temperature` | t |
| 1 | `specific_humidity` | q |
| 1 | `ozone_mass_mixing_ratio` | o3 |
| 1 | `geopotential` | z |
| 2 | `fraction_of_cloud_cover` | cc |
| 2 | `specific_cloud_liquid_water_content` | clwc |
| 2 | `specific_cloud_ice_water_content` | ciwc |
| 2 | `relative_humidity` | r |
| 2 | `u_component_of_wind` (optional) | u |
| 2 | `v_component_of_wind` (optional) | v |

### Single levels

**Tier 1 — surface state**

| CDS name | short | note |
|----------|-------|------|
| `surface_pressure` | sp | |
| `skin_temperature` | skt | |
| `2m_temperature` | t2m | |
| `geopotential` | z | invariant → orography |
| `land_sea_mask` | lsm | |
| `forecast_albedo` | fal | |

**Tier 1 — flux validation targets** (validate radiation against these)

| CDS name | short | note |
|----------|-------|------|
| `top_net_thermal_radiation` | ttr | → OLR |
| `top_net_solar_radiation` | tsr | |
| `toa_incident_solar_radiation` | tisr | |
| `surface_net_thermal_radiation` | str | |
| `surface_net_solar_radiation` | ssr | |
| `surface_thermal_radiation_downwards` | strd | |
| `surface_solar_radiation_downwards` | ssrd | |
| `top_net_thermal_radiation_clear_sky` | ttrc | clear-sky |
| `top_net_solar_radiation_clear_sky` | tsrc | clear-sky |
| `surface_net_thermal_radiation_clear_sky` | strc | clear-sky |
| `surface_net_solar_radiation_clear_sky` | ssrc | clear-sky |
| `surface_thermal_radiation_downward_clear_sky` | strdc | clear-sky |
| `surface_solar_radiation_downward_clear_sky` | ssrdc | clear-sky |

**Tier 2 — moist stack / surface**

| CDS name | short |
|----------|-------|
| `total_precipitation` | tp |
| `evaporation` | e |
| `total_column_water_vapour` | tcwv |
| `total_cloud_cover` | tcc |
| `surface_sensible_heat_flux` | sshf |
| `surface_latent_heat_flux` | slhf |
| `sea_ice_cover` | siconc |
| `snow_depth` | sd |
