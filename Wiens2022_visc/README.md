# Antarctic upper-mantle viscosity (Wiens et al., 2022)

Upper-mantle viscosity of Antarctica at 100, 200 and 300 km depth on a 40 km polar
stereographic grid, inferred from the seismic model ANT-20, as provided by D. A. Wiens
for FastIsostasy (Swierczek-Jereczek et al., 2024, doi:10.5194/gmd-17-5263-2024, Fig.
2, where it is credited to Whitehouse et al., 2019, and Ivins et al., 2022). Cite:

Wiens, D. A., Shen, W. and Lloyd, A. J.: The seismic structure of the Antarctic upper
mantle, Geol. Soc. London Mem., 56, 195-212, 2023 (online 2021),
[doi:10.1144/M56-2020-18](https://doi.org/10.1144/M56-2020-18).

Ivins, E. R., van der Wal, W., Wiens, D. A., Lloyd, A. J. and Caron, L.: Antarctic upper
mantle rheology, Geol. Soc. London Mem., 56, 267-294, 2023 (online 2021),
[doi:10.1144/M56-2020-19](https://doi.org/10.1144/M56-2020-19).

## Licence

The maps are not published by the authors (both chapters are CC BY 4.0, but show the
viscosity only as figures, Ivins et al. at 150 and 300 km). The file was provided by
D. A. Wiens to J. Swierczek-Jereczek (acknowledged in Swierczek-Jereczek et al., 2024)
and is in the isostasy_data repository, archived on Zenodo under CC BY 4.0, a licence
set by the archive, not by the authors. We assume that publishing derived products
with the citations above is allowed; ask D. A. Wiens before a release.

## Original data

`earth_structure/viscosity/wiens2022.nc` of isostasy_data v0.2.0 (Swierczek-Jereczek,
2024, [doi:10.5281/zenodo.11175418](https://doi.org/10.5281/zenodo.11175418), no login;
also https://github.com/JanJereczek/isostasy_data), entry `isostasy_data_v0_2` of
`../datamanifest.toml`, downloaded and extracted by `prepare.jl`: `log10visc`, log10 of
the viscosity in Pa s (units attribute "Pascal seconds"), on x, y (m, -6440:40:6440 km)
and z (100, 200, 300 km), missing (NaN) away from Antarctica.

## Prepare and remap

```bash
julia --project=Wiens2022_visc Wiens2022_visc/prepare.jl
julia fesmdata.jl remap SolidEarth Wiens2022
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Wiens2022_visc/Wiens2022_visc.nc` (see
`Remap/README.md`) with `log10_visc` (log10(Pa s)), log10 of the upper-mantle viscosity,
on x, y and `depth` (m, positive down: 100, 200, 300 km).

The projection is not given in the file. We assume the usual Antarctic polar
stereographic projection (EPSG:3031, standard parallel 71°S, WGS84), as FastIsostasy
uses the file on such grids without reprojecting it.
