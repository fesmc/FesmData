# CERES EBAF Ed4.2.1 radiative fluxes (Loeb et al., 2018)

Monthly climatology 2001-2020 of the top-of-atmosphere (TOA) and surface radiative fluxes
of CERES EBAF (Energy Balanced and Filled) Edition 4.2.1, on its global 1° grid:

Loeb, N. G., Doelling, D. R., Wang, H., Su, W., Nguyen, C., Corbett, J. G., Liang, L.,
Mitrescu, C., Rose, F. G., and Kato, S.: Clouds and the Earth's Radiant Energy System
(CERES) Energy Balanced and Filled (EBAF) Top-of-Atmosphere (TOA) Edition-4.0 Data Product,
J. Climate, 31, 895-918, 2018,
[doi:10.1175/JCLI-D-17-0208.1](https://doi.org/10.1175/JCLI-D-17-0208.1).

Surface fluxes: Kato, S., et al.: Surface Irradiances of Edition 4.0 Clouds and the Earth's
Radiant Energy System (CERES) Energy Balanced and Filled (EBAF) Data Product, J. Climate,
31, 4501-4527, 2018, [doi:10.1175/JCLI-D-17-0523.1](https://doi.org/10.1175/JCLI-D-17-0523.1).

Data: NASA/LARC/SD/ASDC, CERES EBAF Ed4.2.1,
[doi:10.5067/TERRA-AQUA-NOAA20/CERES/EBAF_L3B004.2.1](https://doi.org/10.5067/TERRA-AQUA-NOAA20/CERES/EBAF_L3B004.2.1)
and [doi:10.5067/TERRA-AQUA-NOAA20/CERES/EBAF-TOA_L3B004.2.1](https://doi.org/10.5067/TERRA-AQUA-NOAA20/CERES/EBAF-TOA_L3B004.2.1).

It replaces the v1 product `<GRID>_CERES_2001-2013.nc` (EBAF Ed2.8).

## Licence

NASA Earth science data are open, without restriction on use or redistribution (NASA
Earth Science Data and Information Policy); the data products and papers above should be
cited.

## Original data

On Levante, the monthly means are in the ICDC data pool,
`/pool/data/ICDC/atmosphere/ceres_ebaf/DATA/` (datamanifest key `ceres_ebaf_ed4_2_1`,
used in place):

- `CERES_EBAF_Ed4.2.1_Subset_200003-202512.nc` (TOA and surface fluxes)
- `CERES_EBAF-TOA_Ed4.2.1_Subset_200003-202601.nc` (TOA, for the incoming solar flux)

Elsewhere, order the same global monthly subsets (all fields, 1°) of "EBAF" and
"EBAF-TOA" Ed4.2.1 from https://ceres.larc.nasa.gov/data/ and put them into a folder
given as `storage_path` of `ceres_ebaf_ed4_2_1` in `datamanifest.toml`.

## Prepare and remap

```bash
julia --project=Loeb2018_ceres Loeb2018_ceres/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Loeb2018_ceres/Loeb2018_CERES-EBAF_2001-2020.nc all --name=Atmosphere-CERES-2001-2020
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Loeb2018_ceres/Loeb2018_CERES-EBAF_2001-2020.nc`
with 30 fields (lon, lat, month), all in W m-2 (CERES names without `_mon`):

- TOA: `solar` (incoming), `toa_sw_*` and `toa_lw_*` (outgoing), `toa_net_*` (net
  downward, `solar - sw - lw`), each for all-sky (`_all`) and clear-sky (`_clr_c`,
  `_clr_t`); cloud radiative effects `toa_cre_sw`, `toa_cre_lw`, `toa_cre_net`;
- surface: `sfc_sw_down_*`, `sfc_sw_up_*`, `sfc_lw_down_*`, `sfc_lw_up_*` and net
  downward `sfc_net_sw_*`, `sfc_net_lw_*`, `sfc_net_tot_*`, each `_all` and `_clr_t`;
  cloud radiative effects `sfc_cre_net_sw`, `sfc_cre_net_lw`, `sfc_cre_net_tot`.

Clear sky: `clr_c` is the flux of the cloud-free areas of a cell (observed, as `clr` of
the v1 files); `clr_t` is the flux of the whole cell with the clouds removed in the
radiative transfer, as climate models define it. The cloud radiative effects are all-sky
minus `clr_t`.

The climatology is the mean of the full years 2001-2020 for each month; CERES starts in
March 2000, so 1981-2010 and 1991-2020 are not possible. Longitudes are shifted to
-180:180; there are no missing values (EBAF is filled).
