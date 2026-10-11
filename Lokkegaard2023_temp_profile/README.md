# Greenland and Canadian Arctic ice temperature profiles (Løkkegaard et al., 2023)

Ice temperature profiles of 95 boreholes in the Greenland ice sheet and the ice caps of
Greenland and the Canadian Arctic, on a common 1 m depth axis, with their metadata.
From:

Løkkegaard, A., Mankoff, K. D., Zdanowicz, C., Clow, G. D., Lüthi, M. P., Doyle, S. H.,
Thomsen, H. H., Fisher, D., Harper, J., Aschwanden, A., Vinther, B. M., Dahl-Jensen, D.,
Zekollari, H., Meierbachtol, T., McDowell, I., Humphrey, N., Solgaard, A., Karlsson,
N. B., Khan, S. A., Hills, B., Law, R., Hubbard, B., Christoffersen, P., Jacquemart, M.,
Seguinot, J., Fausto, R. S., and Colgan, W. T.: Greenland and Canadian Arctic ice
temperature profiles database, The Cryosphere, 17, 3829-3845, 2023,
[doi:10.5194/tc-17-3829-2023](https://doi.org/10.5194/tc-17-3829-2023).

Data: Mankoff, K., Løkkegaard, A., Colgan, W., et al.: Greenland and Canadian Arctic ice
temperature profiles database, GEUS Dataverse, V4.1, 2022,
[doi:10.22008/FK2/3BVF9V](https://doi.org/10.22008/FK2/3BVF9V).

## Licence

CC0 1.0 (GEUS Dataverse).

## Original data

Two files of version 4.1 of the GEUS Dataverse dataset (no login), downloaded by
`prepare.jl`:

- `Temperature profiles/temperature.csv` (datamanifest key
  `lokkegaard2023_temperature`, https://dataverse.geus.dk/api/access/datafile/74938):
  temperature (°C) by depth (1 to 3053 m) and borehole;
- `meta.csv` (`lokkegaard2023_meta`, https://dataverse.geus.dk/api/access/datafile/84072):
  location, date, ice thickness, depth range, sources and notes of each borehole.

The dataset also has the profiles on a normalised depth axis
(`temperature_dnorm.csv`) and the locations as `boreholes.gpkg`/`.kml`, not used.

## Prepare and record

```bash
julia --project=Lokkegaard2023_temp_profile Lokkegaard2023_temp_profile/prepare.jl
julia fesmdata.jl record Boreholes Lokkegaard2023
```

`prepare.jl` writes
`$FESMDATA_WORK/prepared/Lokkegaard2023_temp_profile/Lokkegaard2023_boreholes.nc` (see
`Records/README.md`), one profile per borehole (featureType profile): `T_ice` (K) on
(`depth`, `station`), and by station `lat`, `lon`, `site_name` (borehole id), `H_ice`,
`depth_top`, `depth_bottom` (m), `coverage` (%), and the strings `date`, `place_name`,
`location`, `site_type`, `data_source`, `data_doi`, `reference`, `reference_doi`,
`location_source`, `H_ice_source`, `note`.

Notes:

- `T_ice` is converted from °C (+ 273.15). It is missing where there is no measurement
  and below the base of the ice (-999 in `temperature.csv`).
- `date` is a string: a year or a date, depending on the borehole.
