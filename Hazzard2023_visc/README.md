# Antarctic mantle viscosity and lithosphere thickness (Hazzard et al., 2023)

Mantle viscosity of Antarctica at 75-400 km depth and lithosphere thickness, with their
standard deviations, on a 0.5° lon-lat grid south of 45°S (lithosphere: 60°S),
inferred from the seismic model ANT-20 by a Bayesian calibration of anelasticity
(mean and standard deviation of the posterior ensemble), from:

Hazzard, J. A. N., Richards, F. D., Goes, S. D. B. and Roberts, G. G.: Probabilistic
assessment of Antarctic thermomechanical structure: impacts on ice sheet stability, J.
Geophys. Res. Solid Earth, 128, e2023JB026653, 2023,
[doi:10.1029/2023JB026653](https://doi.org/10.1029/2023JB026653).

These are the published grids behind the "HR24" viscosity files of the isostasy_data
repository (`ANT-*_GIA_HR24.nc`, `ANT-*_stdvisc_Hazzard2024.nc`), see
`../SolidEarth/README.md`. The heat flow of Hazzard and Richards (2024) is in
`../HazzardRichards2024_ghf/`.

## Licence

The article is open access under CC BY 4.0. The grids are on OSF
(https://osf.io/f4ntr) with no licence set. We assume that publishing products derived
from them, with citation, is allowed.

## Original data

`summary_grids.zip` (57 MB, no login) from the OSF project "Antarctica Thermomechanical
Structure", https://osf.io/f4ntr, entry `hazzard2023_visc` of `../datamanifest.toml`,
downloaded and extracted by `prepare.jl` to
`$DATAMANIFEST_DATASETS_DIR/hazzard2023_visc/summary_grids/` (with `readme.pdf`). GMT
grids (NetCDF) on lon 0:0.5:360:

- `viscosity_grids/<d>_viscosity_<mean|std>.grd`, d = 75, 100, ..., 400 km, lat
  -90:0.5:-45: log10 of the viscosity in Pa s, mean and standard deviation;
- `LAB_depth/LAB1200_<mean|std>_filtered.grd`, lat -90:0.5:-60: depth of the
  lithosphere-asthenosphere boundary (1200 °C isotherm, km), filtered;
- also temperature, density and heat flow (not used).

The project also has `MAP_grids.zip`, the maximum a posteriori model (viscosity and
temperature at 0-400 km, with the lithosphere set to 10^40 Pa s), not used.

## Prepare and remap

```bash
julia --project=Hazzard2023_visc Hazzard2023_visc/prepare.jl
julia fesmdata.jl remap SolidEarth Hazzard2023-visc
julia fesmdata.jl remap SolidEarth Hazzard2023-litho
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Hazzard2023_visc/Hazzard2023_visc.nc` (see
`Remap/README.md`) on lon -180:0.5:179.5, lat -90:0.5:-45 with

- `log10_visc`, `log10_visc_sd` (log10(Pa s)): log10 of the mantle viscosity (mean) and
  its standard deviation, on `depth` (m, positive down, below sea level: 75-400 km every
  25 km);
- `z_litho`, `z_litho_sd` (m): lithosphere thickness (depth of the 1200 °C isotherm)
  and its standard deviation, converted from km, missing north of 60°S.

The column at 360° repeats 0° and is dropped. As stated in the readme of the data, the
viscosity grids are "raw": the shallow depths (to 75 km) are not corrected for crustal
velocities bleeding downward, and the mean reaches 10^40 Pa s in places at 75-100 km,
where members of the ensemble are lithosphere.
