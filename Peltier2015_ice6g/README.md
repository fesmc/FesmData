# ICE-6G_C (VM5a) ice-sheet and topography reconstruction (Peltier et al., 2015)

Global ice thickness, topography and ice and land fractions from 26 ka to present
(48 time slices: every 0.5 kyr from 21 ka, every 1 kyr before) on a 1° lon-lat grid,
from the ICE-6G_C (VM5a) glacial isostatic adjustment model:

Peltier, W. R., Argus, D. F. and Drummond, R.: Space geodesy constrains ice age
terminal deglaciation: The global ICE-6G_C (VM5a) model, J. Geophys. Res. Solid Earth,
120, 450-487, 2015, [doi:10.1002/2014JB011176](https://doi.org/10.1002/2014JB011176).

Argus, D. F., Peltier, W. R., Drummond, R. and Moore, A. W.: The Antarctica component
of postglacial rebound model ICE-6G_C (VM5a) based on GPS positioning, exposure age
dating of ice thicknesses, and relative sea level histories, Geophys. J. Int., 198,
537-563, 2014, [doi:10.1093/gji/ggu140](https://doi.org/10.1093/gji/ggu140).

## Licence

No licence is stated by the provider. Users of the data are asked to cite both papers
above. We assume that derived products may be published with this citation.

## Original data

From the data page of W. R. Peltier,
<https://www.atmosp.physics.utoronto.ca/~peltier/data.php> (no login), the 48 files
`I6_C.VM5a_1deg.<age>.nc.gz` (age in ka: 26, 25, ..., 21, 20.5, 20, ..., 0.5, 0),
`ice6g_c_vm5a_1deg` in `datamanifest.toml`, e.g.:

```bash
curl -k -O https://www.atmosp.physics.utoronto.ca/~peltier/datasets/Ice6G_C_VM5a/I6_C.VM5a_1deg.21.nc.gz
```

The server does not send its intermediate TLS certificate, so the certificate cannot
be verified (`curl -k`); `prepare.jl` downloads with `JULIA_SSL_NO_VERIFY_HOSTS` set
to that host. The files are read gzipped. The same files (uncompressed) are in the
old PIK archive, `hpc:/data/sicopolis/data/ICE-6G_C/`.

## Prepare and remap

```bash
julia --project=Peltier2015_ice6g Peltier2015_ice6g/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Peltier2015_ice6g/Peltier2015_ICE6G_C.nc all --name=ICEHISTORY-ICE6G_C
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Peltier2015_ice6g/Peltier2015_ICE6G_C.nc`
(see `Remap/README.md`) with the dimension `time` (age in ka BP, oldest first) and

- `z_topo` (m): topography (`Topo`), the ice or land surface on land and the sea floor
  in the ocean and under ice shelves;
- `z_srf` (m): surface elevation (`orog`), 0 over the ocean and the ice surface of ice
  shelves;
- `dz_topo` (m): topography change from present (`Topo_Diff`);
- `H_ice` (m): ice thickness (`stgit`);
- `f_ice`, `f_land` (1): ice and land area fractions (`sftgif`, `sftlf`, converted from
  %).

The longitudes (cell centres 0.5:359.5°) are reordered to -179.5:179.5.
