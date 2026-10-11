# Boreholes: ice temperature profiles

Temperature profiles measured in boreholes through ice sheets and ice caps. Boreholes
is a records dataset (non-gridded data, see `Records/README.md`): its products, defined
in `Boreholes/records.toml`, are prepared files in the form of the CF discrete sampling
geometries, written to `$ICE_DATA/v2/Records/Boreholes/Boreholes-<product>.nc`.

## Products

| Product | Source | Sites | Variables |
|---|---|---|---|
| `Boreholes-Lokkegaard2023` | Løkkegaard et al. (2023), database V4.1, [doi:10.22008/FK2/3BVF9V](https://doi.org/10.22008/FK2/3BVF9V) | 95 boreholes in Greenland and the Canadian Arctic | `T_ice` (K) on a 1 m depth axis (1-3053 m); by borehole `H_ice`, `depth_top`, `depth_bottom` (m), `coverage` (%), `date`, sources and notes |

One profile per borehole (featureType profile, dimensions `depth` (m, positive down) and
`station`, with `lat`, `lon` and `site_name`).

## Licences

| Source | Licence |
|---|---|
| Løkkegaard et al. (2023) | CC0 1.0 (GEUS Dataverse) |

## Making the dataset

```bash
julia fesmdata.jl record Boreholes
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$ICE_DATA/v2/Records/Boreholes/` (`--overwrite` to replace them).
