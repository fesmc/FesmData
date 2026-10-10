# Topographic correction of geothermal heat flow (Colgan et al., 2021)

A dimensionless correction of any large-scale geothermal heat flow field for the
effect of the bed topography (more heat flow in valleys, less on ridges), and its
uncertainty, on the BedMachine grids of Greenland (150 m) and Antarctica (500 m):

Colgan, W., MacGregor, J. A., Mankoff, K. D., Haagenson, R., Rajaram, H., Martos, Y. M.,
Morlighem, M., Fahnestock, M. A. and Kjeldsen, K. K.: Topographic correction of
geothermal heat flux in Greenland and Antarctica, J. Geophys. Res. Earth Surf., 126,
e2020JF005598, 2021, [doi:10.1029/2020JF005598](https://doi.org/10.1029/2020JF005598).

Data: Colgan, W.: Topographic Correction for Geothermal Heat Flow in Greenland and
Antarctica, GEUS Dataverse, V1, 2021,
[doi:10.22008/FK2/BQGYYG](https://doi.org/10.22008/FK2/BQGYYG).

**The correction is relative and multiplies a heat flow field as 1 + correction:**
corrected heat flow = (1 + `ghf_corr`) × heat flow, for any GHF product (e.g. on the
same grid, `ghf` of `GHF-Martos2018` times 1 + `ghf_corr` of
`GHF-Colgan2021-topocorr-GRL`). `ghf_corr` is the relative anomaly ΔG/G of Colgan et
al. (2021, Eq. 1), G' = G (1 + ΔG/G): it is about 0 on average (mostly within ±0.1 in
Antarctica and ±0.3 in Greenland, extremes -1.8 and 3.8), so it is not a factor
around 1. Where it is below -1 the corrected heat flow would be negative.
`ghf_corr_unc` is its uncertainty σ(ΔG/G) (about 0.18), also dimensionless.

## Licence

CC0 1.0 (GEUS Dataverse).

## Original data

`TopoHeat_Antarctica_20210224.nc` and `TopoHeat_Greenland_20210224.nc` (about 1 GB
each), downloaded by `prepare.jl` (datamanifest keys `colgan2021_topocorr_antarctica`,
`colgan2021_topocorr_greenland`) from
<https://dataverse.geus.dk/api/access/datafile/19029> and `.../19030` (no login).

## Prepare and remap

```bash
julia --project=Colgan2021_topocorr Colgan2021_topocorr/prepare.jl   # about 4 GB of memory, 2 min
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Colgan2021_topocorr/Colgan2021_topocorr_GRL.nc Greenland --name=GHF-Colgan2021-topocorr-GRL
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Colgan2021_topocorr/Colgan2021_topocorr_ANT.nc Antarctica --name=GHF-Colgan2021-topocorr-ANT
```

`prepare.jl` writes `ghf_corr` and `ghf_corr_unc` (dimensionless) on the original
grids to `$FESMDATA_WORK/prepared/Colgan2021_topocorr/Colgan2021_topocorr_<ANT|GRL>.nc`
(see `Remap/README.md`). The fields are those of the original files (`correction`,
`correction_uncertainty`), renamed. The coordinates, stored as 32-bit floats in the
original files, are rebuilt as exact regular axes. The original files give their
projection as `+init=epsg:3031` and `+init=epsg:3413` (BedMachine), which is used,
although the CF attributes of the Antarctic file name the Hughes ellipsoid.
