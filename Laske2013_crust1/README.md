# Sediment thickness of CRUST1.0 (Laske et al., 2013)

Sediment thickness on land and in the oceans on a 1x1° lon-lat grid, from the global
crustal model CRUST1.0:

Laske, G., Masters, G., Ma, Z. and Pasyanos, M.: Update on CRUST1.0 - A 1-degree global
model of Earth's crust, Geophys. Res. Abstr., 15, EGU2013-2658, 2013,
<https://igppweb.ucsd.edu/~gabi/crust1.html>.

CRUST1.0 has three sediment layers (upper, middle and lower sediments). Its sediments
follow the global sediment map of Laske and Masters (1997), used for the v1 product
SED-L97: on the 16 km grids of Antarctica, Greenland and the Laurentide domain the two
agree closely (correlation 0.98-0.99, same mean).

## Licence

No licence or terms of use are stated. The authors ask to cite Laske et al. (2013) and
to refer to the REM web site (<https://igppweb.ucsd.edu/~gabi/rem.html>). We assume that
derived products may be published with this citation.

## Original data

`crust1.0.tar.gz` from <https://igppweb.ucsd.edu/~gabi/crust1/crust1.0.tar.gz> (no login),
of which `crust1.bnds` is used. It is in `datamanifest.toml` (`crust1`) and downloaded and
extracted by `prepare.jl` if missing.

## Prepare and remap

```bash
julia --project=Laske2013_crust1 Laske2013_crust1/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Laske2013_crust1/Laske2013_CRUST1_sed.nc all --name=Sediment-CRUST1
```

`prepare.jl` writes `z_sed`, the total sediment thickness, and the thickness of each
sediment layer, `z_sed_upper`, `z_sed_middle` and `z_sed_lower` (m), to
`$FESMDATA_WORK/prepared/Laske2013_crust1/Laske2013_CRUST1_sed.nc` (see `Remap/README.md`).
The thickness of a layer is the difference between its top and the top of the next
layer in `crust1.bnds` (km, converted to m), as in `getCN1maps.f` of CRUST1.0.
