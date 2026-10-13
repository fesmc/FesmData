# SMBObs: surface mass balance observations

Point measurements of the surface mass balance of the ice sheets. SMBObs is a records
dataset (non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)): its products,
defined in `SMBObs/records.toml`, are prepared files in the form of the CF discrete
sampling geometries, written to `$FESMDATA_PRODUCTS/Records/SMBObs/SMBObs-<product>.nc`.

## Products

| Product | Source | Measurements | Variables |
|---|---|---|---|
| `SMBObs-SUMup2025` | SUMup 2025 (Vandecrux et al., 2025), [doi:10.18739/A2M61BR5M](https://doi.org/10.18739/A2M61BR5M) | 2.74 million in Greenland and Antarctica (cores, pits, stakes, radar, ...), 871-2025 CE | `smb_total`, `smb_total_sd` (kg m-2, SMB of the measurement interval `time_bnds`), `smb`, `smb_sd` (kg m-2 yr-1, mean rate over the interval), `z_srf`, keys and tables of the name, method and reference |

Each measurement is an observation (featureType point, dimension `obs`) with its `lat`,
`lon` and `time` (days since 1900-01-01, the middle of the interval). SUMup gives the
SMB accumulated over the interval (`smb_total`); `smb` is `smb_total` / duration (see
[SUMup_smb](https://github.com/fesmc/FesmData/blob/main/SUMup_smb/README.md)). The
density and subsurface temperature data of SUMup are not included.

## Licences

| Source | Licence |
|---|---|
| SUMup 2025 | CC0 1.0 (Arctic Data Center); cite also the original studies (`reference`) |

## Making the dataset

```bash
julia fesmdata.jl record SMBObs
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA_PRODUCTS/Records/SMBObs/` (`--overwrite` to replace them).
