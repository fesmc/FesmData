# Antarctic geothermal heat flow (Hazzard and Richards, 2024)

Geothermal heat flow of the Antarctic continent and its standard deviation on a 0.5°
lon-lat grid, inferred from the seismic velocities of the ANT-20 tomographic model,
together with the crustal thermal conductivity and upper-crustal heat production fitted
at the same time (HR24), from:

Hazzard, J. A. N. and Richards, F. D.: Antarctic geothermal heat flow, crustal
conductivity and heat production inferred from seismological data, Geophys. Res.
Lett., 51, e2023GL106274, 2024,
[doi:10.1029/2023GL106274](https://doi.org/10.1029/2023GL106274).

## Licence

The article is open access under CC BY 4.0. The grids are on OSF
(https://osf.io/54zam) with no licence set. We assume that publishing products derived
from them, with citation, is allowed.

## Original data

`HR24_grids.zip` (8.7 MB) from the OSF project https://osf.io/54zam (no login), entry
`hazzardrichards2024_ghf` of `../datamanifest.toml`, downloaded and extracted by
`prepare.jl` to `$DATAMANIFEST_DATASETS_DIR/hazzardrichards2024_ghf/`. It holds GMT
grids (NetCDF) in `model_output/`: `HR24_<field>_<mean|std>.grd` on lon 0:0.5:360,
lat -90:0.5:-60, and the same projected to 5 km polar stereographic (`*_PS.grd`, not
used), for `GHF` (mW m-2), `k` and `h`.

## Prepare and remap

```bash
julia --project=HazzardRichards2024_ghf HazzardRichards2024_ghf/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/HazzardRichards2024_ghf/HazzardRichards2024_GHF.nc Antarctica --name=GHF-HazzardRichards2024
```

`prepare.jl` writes, from the lon-lat grids,
`$FESMDATA_WORK/prepared/HazzardRichards2024_ghf/HazzardRichards2024_GHF.nc` with
(see `Remap/README.md`):

- `ghf`, `ghf_sd`: geothermal heat flow and its standard deviation (mW m-2);
- `k_crust`, `k_crust_sd`: crustal thermal conductivity at 0 °C and 0 GPa, k0 of the
  paper (W m-1 K-1);
- `h_upper_crust`, `h_upper_crust_sd`: upper-crustal radiogenic heat production,
  h*cu of the paper (µW m-3).

The column at 360° repeats 0° and is dropped; longitudes are shifted to -180:180.
Values exist on the continent only (missing elsewhere).
