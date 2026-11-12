# GNET vertical velocities of Greenland and their elastic part (Berg et al., 2024)

Observed vertical velocities of 55 stations of the Greenland GNSS Network (GNET), over
the series of each station (most from 2007-2009, some from the 1990s, to 2022), in
IGS14, with the modelled elastic response to the present mass loss of the Greenland ice
sheet, its peripheral glaciers and the glaciers of Arctic Canada. In Greenland the
observed uplift is dominated by this elastic response (1.5-13.8 mm/yr at these stations,
for observed rates of 1.3-17.5 mm/yr): the GIA estimate is `uplift_rate -
uplift_rate_elastic`. From:

Berg, D. L., Barletta, V. R., Hassan, J., Lippert, E. Y. H., Colgan, W., Bevis, M.,
Steffen, R., and Khan, S. A.: Vertical land motion due to present-day ice loss from
Greenland's and Canada's peripheral glaciers, Geophys. Res. Lett., 51, e2023GL104851,
2024, [doi:10.1029/2023GL104851](https://doi.org/10.1029/2023GL104851). Data:
[doi:10.5061/dryad.9zw3r22n0](https://doi.org/10.5061/dryad.9zw3r22n0) (also Zenodo
record 10048911).

The rates per station are not in the data of Berg et al. (2024); they are taken from
the data of Lewright et al. (2025), who used them (observed and elastic rates of Berg et
al.) at 55 of the 57 stations, leaving out two in central East Greenland near
Kangerlussuaq Glacier (KUAQ and MIK2) as Adhikari et al. (2021):

Lewright, L. et al.: Projections of 21st-century sea-level fall along coastal Greenland,
Nat. Commun., 2025, [doi:10.1038/s41467-025-68182-6](https://doi.org/10.1038/s41467-025-68182-6).
Data: [doi:10.5281/zenodo.16878392](https://doi.org/10.5281/zenodo.16878392).

## Licence

CC BY 4.0 (Lewright et al., 2025, Zenodo) for the velocities; CC0 (Berg et al., 2024,
Dryad and Zenodo) for the station names, coordinates and series. The article of Berg et
al. (2024) is CC BY-NC-ND 4.0: its tables are not used.

## Original data

Downloaded and extracted by `prepare.jl` (no login):

- `lewright2025_vlm`: `Greenland_SL_Projections_model_output.zip` (59 MB) of Zenodo
  record 16878392, of which `Bayesian_Inversion/VLM_station_locations.nc` (station
  longitude and latitude, without names), `VLM_OBS_stations.nc` (`VLM_OBS`,
  `VLM_OBS_STD`) and `VLM_ELA_stations.nc` (`VLM_ELA`, `VLM_ELA_STD`), in mm/yr, on the
  dimension `station location` (55).
- `berg2024_gnet`: `GNET_NEU_v2022_5_31.zip` of Zenodo record 10048911 (the Dryad
  files): `COORDINATES.txt` (name, latitude, longitude of 58 stations) and
  `<NAME>_NEU.txt` (daily north, east and up positions, decimal years).

The stations of Lewright et al. are matched to the names of Berg et al. by their
longitude, which is that of Berg et al. rounded to 0.0001°; their latitudes are
0.02-0.07° north of those of Berg et al. and of the NGL station coordinates, which are
kept. The time span is that of the series of Berg et al. (v2022-05-31), over which
their rates are estimated.

## Prepare and record

```bash
julia --project=Berg2024_gnet Berg2024_gnet/prepare.jl
julia fesmdata.jl record GPS GNET
```

`prepare.jl` writes `$FESMDATA_PREPARED/Berg2024_gnet/Berg2024_GNET.nc`, one value per
station (featureType point, dimension `station`): `uplift_rate` and `uplift_rate_sd`
(observed, mm yr-1), `uplift_rate_elastic` and `uplift_rate_elastic_sd` (elastic part,
mm yr-1), `time_start` and `time_end` (first and last epoch of the series, decimal
years), `lat`, `lon` and `site_name`.
