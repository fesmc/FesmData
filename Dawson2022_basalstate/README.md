# Basal thermal state of the Antarctic ice sheet (Dawson et al., 2022)

Basal temperature of the grounded Antarctic ice sheet from the thermal steady state of
the initialization of the Ice-sheet and Sea-level System Model (ISSM) by Dawson et al.
(2022), on its triangular mesh (0.3-50 km, median edge 7.7 km), and the basal thermal
state derived from it: frozen, thawable (frozen but within 2 K of the pressure melting
point) and thawed; also the basal melt rate of the thermal steady state and the basal
friction coefficient inferred by the model. From:

Dawson, E. J., Schroeder, D. M., Chu, W., Mantelli, E., and Seroussi, H.: Ice mass loss
sensitivity to the Antarctic ice sheet basal thermal state, Nat. Commun., 13, 4957,
2022, [doi:10.1038/s41467-022-32632-2](https://doi.org/10.1038/s41467-022-32632-2).

Data: Dawson, E. J.: ISSM Results for Antarctic Ice Sheet Basal Thaw Experiments,
Zenodo, 2022, [doi:10.5281/zenodo.6870567](https://doi.org/10.5281/zenodo.6870567).

## Licence

CC BY 4.0 (Zenodo).

## Original data

`Antarctica_Initialization.mat` (158 MB) from Zenodo (no login), downloaded by
`prepare.jl` into `$DATAMANIFEST_DATASETS_DIR/dawson2022/` (datamanifest key
`dawson2022_init`). It is a MATLAB 7.3 (HDF5) file with the ISSM model `md`, a MATLAB
object, read without MATLAB or ISSM by `issm_mat.jl`. The other files of the record
(the 100-year thaw experiments, 2.9 GB each, and the scripts of the figures) are not
used.

## Prepare and remap

```bash
julia --project=Dawson2022_basalstate Dawson2022_basalstate/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Dawson2022_basalstate/Dawson2022_BASALSTATE.nc Antarctica --name=BasalState-Dawson2022
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Dawson2022_basalstate/Dawson2022_BASALSTATE.nc`
(see `Remap/README.md`) on a 1 km polar stereographic grid (EPSG:3031), on the grounded
ice:

- `T_b` (K): the basal temperature, `md.results.ThermalSolution.Temperature` on the
  first (basal) layer of vertices;
- `T_b_pmp` (K): the basal temperature relative to the pressure melting point,
  `T_b + beta p - 273.15`, with `beta` = 9.8e-8 K Pa-1 (`md.materials.beta`) and the
  pressure `p` of `md.initialization.pressure`, as in the scripts of the article
  (`paper_figs.m`), at most 0;
- `basal_state` (integer classes): 1 frozen (`T_b_pmp` < -2.01 K), 2 thawable,
  3 thawed (`T_b_pmp` > -0.01 K), the thresholds of the scripts of the article and of
  its experiment 1 (thawable within 2 K of the pressure melting point; experiments 2-4
  use 5, 8 and 12 K);
- `bmelt_grnd` (m yr-1 ice equivalent, positive for melting, negative for refreezing):
  the basal melt rate of the thermal steady state,
  `md.results.ThermalSolution.BasalforcingsGroundediceMeltingRate` (ISSM results are
  in m yr-1 of ice). Mostly 0 (frozen bed), up to a few m yr-1 near fast-flowing
  outlets (single vertices up to 694 m yr-1, 25 m yr-1 on the 1 km grid); 21 Gt yr-1
  over the grounded ice in total (on ANT-16KM);
- `beta` (Pa yr m-1): the basal friction coefficient of a linear sliding law,
  tau_b = `beta` u_b, with u_b the basal velocity in m yr-1. The model uses the ISSM
  "Budd" friction law tau_b = C^2 N^(q/p) |u_b|^(1/p - 1) u_b with p = 1 and q = 0, i.e.
  the linear law tau_b = C^2 u_b (the Weertman-type law of the article, with its
  alpha = C), with C = `md.friction.coefficient` in (Pa s m-1)^(1/2) inferred by
  inversion of the surface velocity. So `beta` = C^2 / yts, with yts = 31536000 s yr-1,
  which is the `beta` of a linear law in Yelmo (Pa yr m-1). C is interpolated linearly
  on the mesh (it is linear there) and squared on the grid.

**Mesh to grid.** The fields of the model are linear on the triangles of its mesh,
so they are interpolated linearly (barycentric coordinates) at the centres of the
cells of a 1 km grid, about the finest spacing of the mesh; this gives the field of the
model, not a smoothed one. The grounded ice is where the interpolated level sets of
`md.mask` give grounded ice (12.2 million km2). The classes are those of the
interpolated `T_b_pmp`: by area 82% frozen, 8% thawable and 10% thawed.
