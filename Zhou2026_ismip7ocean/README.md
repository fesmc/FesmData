# ISMIP7 Antarctic ocean climatology (Zhou et al., 2026)

Observational climatology (1972-2024) of the ocean around Antarctica used by ISMIP7, on
the ISMIP7 8 km polar stereographic grid (EPSG:3031) with 30 layers of 60 m (30 to
1770 m depth): potential temperature, practical salinity and thermal forcing, and the
16 IMBIE2 basins extended into the ocean (for basal melt parameterizations). It
supersedes the ISMIP6 climatology of Jourdain et al. (2020) (`Jourdain2020_ismip6/`).

The climatology is the updated OCEAN ICE climatology of conservative temperature and
absolute salinity (version `zhou_annual_06_nov`, provided by S. Zhou to ISMIP7):

Zhou, S., Dutrieux, P., Giulivi, C., Meijers, A., Lee, W. S., Kim, T.-W., Hattermann, T.
and Janout, M.: The OCEAN ICE hydrography profiles compilation and climatology, Earth
Syst. Sci. Data Discuss., 2026,
[doi:10.5194/essd-2025-727](https://doi.org/10.5194/essd-2025-727) (in review; the
earlier public version of the climatology is
[doi:10.17882/103946](https://doi.org/10.17882/103946)).

It was put on the ISMIP7 grid, extrapolated and converted by ISMIP7 with
[i7aof](https://github.com/ismip/ismip7-antarctic-ocean-forcing), described in:

Reese, R., Jourdain, N. C., Asay-Davis, X. S., et al.: A protocol for calibrating basal
melt rates in the ISMIP7 Antarctic ice sheet projections, EGUsphere, 2026,
[doi:10.5194/egusphere-2026-5337](https://doi.org/10.5194/egusphere-2026-5337).

## Licence

No licence is stated for the ISMIP7 forcing files (ISMIP: "We welcome the use of ISMIP
datasets"; cite the datasets and acknowledge ISMIP7). The OCEAN ICE climatology they
are made from is CC BY 4.0 (SEANOE), and i7aof is MIT. We assume we may publish.

## Original data

Public HTTPS access to the ISMIP7 Globus endpoint (no login), base
`https://g-ab4495.8c185.08cc.data.globus.org/ISMIP7/AIS/obs/ocean/`:

- `climatology/zhou_annual_06_nov/thetao/v4/thetao_AIS_obs_ocean_climatology_zhou_annual_06_nov_v4_1972-2024.nc`
- `climatology/zhou_annual_06_nov/so/v4/so_AIS_obs_ocean_climatology_zhou_annual_06_nov_v4_1972-2024.nc`
- `climatology/zhou_annual_06_nov/tf/v3/tf_AIS_obs_ocean_climatology_zhou_annual_06_nov_v3_1972-2024.nc`
- `IMBIE-basins/v3/IMBIE-basins_AIS_obs_ocean_v3.nc`

These are the latest versions found (there is no listing; `thetao` and `so` v3 and `tf`
v4 do not exist). They are the datamanifest entries `ismip7_ais_ocean_{thetao,so,tf}`
and `ismip7_ais_imbie_basins`, downloaded by `prepare.jl` to
`$DATAMANIFEST_DATASETS_DIR/ismip7_ais_ocean/`. The `thetao` and `so` files are identical to
`ANT-8KM/meltMIP/ANT-8KM_OI_Climatology_{thetao,so}_extrap.nc` in
`/work/ba1442/ice_data/ISMIP7/Antarctica/`; the files named `thetao` and `so` under
`raw_data/obs/ocean/climatology/` there are copies of the `tf` file.

## Prepare and remap

```bash
julia --project=Zhou2026_ismip7ocean Zhou2026_ismip7ocean/prepare.jl
julia -t 8 fesmdata.jl remap $FESMDATA_WORK/prepared/Zhou2026_ismip7ocean/ISMIP7_OCEAN_1972-2024.nc Antarctica --name=Ocean-ISMIP7
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Zhou2026_ismip7ocean/ISMIP7_OCEAN_1972-2024.nc`
(130 MB) with `to` (potential temperature, degC), `so` (practical salinity, PSU) and
`tf` (thermal forcing, degC) on `(x, y, z)`, and `basin` (integer, 0-15, names in
`flag_meanings`) on `(x, y)`.

## Notes

- ISMIP7 extrapolated the climatology (CT and SA) horizontally and vertically into every
  cell, also under ice shelves and grounded ice and below the sea floor, before averaging
  it to the 60 m layers: no cell is missing, and there is no public version without the
  extrapolation.
- `to` and `so` were converted back from CT and SA by ISMIP7 (`gsw.pt_from_CT`,
  `gsw.SP_from_SA`). `tf` is conservative temperature minus the freezing conservative
  temperature (TEOS-10, no dissolved air), so it differs from `to` minus a freezing
  point by up to 0.1 K.
- `z` is the height of the layer centres (negative below sea level), with the layer
  edges in `z_bnds`, as in the source.
- The basins are the IMBIE2 basins (v1.6) with E-Ep and Ep-F merged into E-F and J-Jpp
  and Jpp-K into J-K, numbered 0 (A-Ap) to 15 (K-A), extended over the ocean.
- Compared with the v1 ISMIP6 file (Jourdain et al., 2020) on ANT-16KM, the level means
  differ by less than 0.07 K (`to`, `tf`) and 0.05 PSU (`so`), with RMS differences of
  0.25-0.46 K and 0.12-0.15 PSU.
