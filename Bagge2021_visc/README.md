# Global 3D mantle viscosity (Bagge et al., 2021)

Global 3D viscosity structure of the Earth for glacial isostatic adjustment models
(VILMA) on a Gaussian grid (512 x 256, about 0.7°) and 164 layers from the surface to
the core-mantle boundary, derived from seismic tomography (SL2013sv and the 2010 update
of Grand, 2002) with geodynamic constraints, from:

Bagge, M., Klemann, V., Steinberger, B., Latinović, M. and Thomas, M.: Glacial-isostatic
adjustment models using geodynamically constrained 3D Earth structures, Geochem.
Geophys. Geosyst., 22, e2021GC009853, 2021,
[doi:10.1029/2021GC009853](https://doi.org/10.1029/2021GC009853).

Bagge, M., Klemann, V., Steinberger, B., Latinović, M. and Thomas, M.: 3D Earth
structures for glacial-isostatic adjustment models, V. 1.0, GFZ Data Services, 2020,
[doi:10.5880/GFZ.1.3.2020.004](https://doi.org/10.5880/GFZ.1.3.2020.004).

The data publication has 18 structures, `v_<r>_<RVP>`. The factor `r` (0.2857, 0.3,
0.4, 0.5, 0.75, 1.0) multiplies the activation enthalpy of the conversion from
temperature to viscosity: the higher `r`, the stronger the lateral variability. `r` =
1 is diffusion creep; `r` = 0.3-0.5 imitates dislocation creep with a Newtonian flow
(Christensen, 1983), and `r` = 0.4 is their reference value. The radial viscosity
profile `RVP` sets the steps between upper mantle, transition zone and lower mantle:
s16 has a viscosity increase at 410 km, sc06 a weaker transition zone (410-660 km), and
sc06b no step at 410 km, like the GIA models VM2 and VM5a.

We prepare the 8 structures that Bagge et al. (2021) use themselves with the NAICE ice
history (their Sect. 3 and Table S1): all six `r` with s16, and `r` = 0.4 with sc06 and
sc06b. They are along the dimension `structure`, in this order:

| `structure` | Name | `r` | `RVP` |
|---|---|---|---|
| 1 | `v_0.2857_s16` | 0.2857 | s16 |
| 2 | `v_0.3_s16` | 0.3 | s16 |
| 3 | `v_0.4_s16` | 0.4 | s16 (reference structure of the article) |
| 4 | `v_0.5_s16` | 0.5 | s16 |
| 5 | `v_0.75_s16` | 0.75 | s16 |
| 6 | `v_1.0_s16` | 1.0 | s16 (the structure of the isostasy_data repository, `bagge2021.nc`, identical) |
| 7 | `v_0.4_sc06` | 0.4 | sc06 |
| 8 | `v_0.4_sc06b` | 0.4 | sc06b |

The coordinate variable `structure` has their names (`structure_names`), factors
(`reduction_factor`) and profiles (`radial_viscosity_profile`) as attributes. The other
10 structures can be added by adding them to the list `STRUCTURES` in `prepare.jl`.

## Licence

CC BY 4.0 (GFZ Data Services). Cite the data publication and the article.

## Original data

`2020-004_Bagge_et-al_data.zip` (1.7 GB, no login) from
https://datapub.gfz.de/download/10.5880.GFZ.1.3.2020.004niur/, entry `bagge2021_visc`
of `../datamanifest.toml`, downloaded and extracted by `prepare.jl` to
`$FESMDATA_SOURCES/bagge2021_visc/`: one NetCDF file per structure, with
`lgvisc`, log10 of the viscosity in Pa s, on lon, lat (Gaussian) and `radius` (in m,
although its units attribute says km). The README of the data publication is
`2020-004_Bagge-et-al_README.pdf` in the same folder of the server.

## Prepare and remap

```bash
julia --project=Bagge2021_visc Bagge2021_visc/prepare.jl
julia fesmdata.jl remap SolidEarth Bagge2021
```

`prepare.jl` writes `$FESMDATA_PREPARED/Bagge2021_visc/Bagge2021_visc.nc` (see
`Remap/README.md`, 340 MB) with `log10_visc` (log10(Pa s)), log10 of the mantle
viscosity, on lon -180:0.703125:179.3, the 256 Gaussian latitudes with their cell edges
(`lat_bnds`, from the Gauss weights), `depth` (m, positive down) with its bounds
(`depth_bnds`) and `structure` (1-8, see above); all structures are on the same grid
and layers. The radii are the mid-points of the layers of VILMA (5 km thick down to 420 km depth,
10 km to 670 km, about 40 km below), so the depth of a layer is 6371 km (the Earth
radius of VILMA) minus its radius, and its bounds are halfway between the mid-points,
from the surface to the core-mantle boundary (3480 km radius).
