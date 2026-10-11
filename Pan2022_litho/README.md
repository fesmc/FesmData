# Lithosphere thickness and mantle viscosity (Pan et al., 2022)

Global lithosphere thickness and 3D mantle viscosity on a 0.5° lon-lat grid, the
laterally varying Earth structure used in the glacial isostatic adjustment model
(Seakon) of:

Pan, L., Milne, G. A., Latychev, K., Goldberg, S. L., Austermann, J., Hoggard, M. J.
and Mitrovica, J. X.: The influence of lateral Earth structure on inferences of global
ice volume during the Last Glacial Maximum, Quat. Sci. Rev., 290, 107644, 2022,
[doi:10.1016/j.quascirev.2022.107644](https://doi.org/10.1016/j.quascirev.2022.107644).

## Licence

The data are not published by the authors (we found no data availability statement or
repository). They were obtained by personal communication by J. Swierczek-Jereczek for
FastIsostasy (Swierczek-Jereczek et al., 2024, doi:10.5194/gmd-17-5263-2024), most
likely from K. Latychev, coauthor of both papers, and are in the isostasy_data repository, archived on
Zenodo under CC BY 4.0, a licence set by the archive, not by the authors. No licence
is stated by the authors: cite Pan et al. (2022). We assume that publishing derived
products with this citation is allowed; ask the authors before a release.

## Original data

The files of isostasy_data v0.2.0 (Swierczek-Jereczek, 2024,
[doi:10.5281/zenodo.11175418](https://doi.org/10.5281/zenodo.11175418), no login;
also https://github.com/JanJereczek/isostasy_data), entry `isostasy_data_v0_2` of
`../datamanifest.toml`, downloaded and extracted by `prepare.jl`:

- `earth_structure/lithothickness/pan2022.llz`: text, lon, lat, lithosphere thickness
  (km) on lon 0:0.5:360, lat 90:-0.5:-90;
- `earth_structure/viscosity/pan2022.nc`: `eta`, log10 of the viscosity in Pa s (the
  units attribute says "Pascal seconds"), on lon -179.5:0.5:180 (0 repeated), lat
  -90:0.5:90 and 64 radii `r` (m) from 3530 km to 6347 km.

## Prepare and remap

```bash
julia --project=Pan2022_litho Pan2022_litho/prepare.jl
julia fesmdata.jl remap SolidEarth Pan2022-litho
julia fesmdata.jl remap SolidEarth Pan2022-visc
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Pan2022_litho/Pan2022_EarthStructure.nc`
(see `Remap/README.md`) on lon -180:0.5:179.5, lat -90:0.5:90 with

- `z_litho` (m): lithosphere thickness (converted from km);
- `log10_visc` (log10(Pa s)): log10 of the mantle viscosity, on `depth` (m, positive
  down, 64 levels from 24 km to 2841 km), the depth being 6371 km (the Earth radius of
  the model, e.g. 5971 km = 400 km and 5701 km = 670 km depth) minus the radius.

The repeated longitude columns (360° in the lithosphere, a second 0° in the viscosity,
both identical to the first) are dropped. The radii are points of the model, not
layers, so no depth bounds are written.
