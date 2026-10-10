# ICE-5G v1.2 ice-sheet reconstruction (Peltier, 2004)

Global ice thickness, ice mask and topography from 21 ka to present (39 time slices:
every 0.5 kyr from 17 ka, every 1 kyr before) on a 1° lon-lat grid, version 1.2 of the
ICE-5G (VM2) glacial isostatic adjustment model:

Peltier, W. R.: Global glacial isostasy and the surface of the ice-age Earth: the
ICE-5G (VM2) model and GRACE, Annu. Rev. Earth Planet. Sci., 32, 111-149, 2004,
[doi:10.1146/annurev.earth.32.082503.144359](https://doi.org/10.1146/annurev.earth.32.082503.144359).

## Licence

No licence is stated by the provider. Users of the data are asked to cite Peltier
(2004), and for a region also the regional study it is based on (listed on the data
page). We assume that derived products may be published with this citation.

## Original data

From the data page of W. R. Peltier,
<https://www.atmosp.physics.utoronto.ca/~peltier/data.php>, the archive of the 1°
files (no login), `ice5g_v1_2_1deg` in `datamanifest.toml`:

```bash
curl -k -O https://www.atmosp.physics.utoronto.ca/~peltier/datasets/Ice5G_1.2/ice5g_v1.2_0-21k_1deg.tar.gz
```

The server does not send its intermediate TLS certificate, so the certificate cannot
be verified (`curl -k`); `prepare.jl` downloads with `JULIA_SSL_NO_VERIFY_HOSTS` set
to that host. The same files are in the old PIK archive,
`hpc:/data/sicopolis/data/ICE-5G/ice5g_v1.2_0-21k_1deg/`.

## Prepare and remap

```bash
julia --project=Peltier2004_ice5g Peltier2004_ice5g/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Peltier2004_ice5g/Peltier2004_ICE5G.nc all --name=ICEHISTORY-ICE5G
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Peltier2004_ice5g/Peltier2004_ICE5G.nc`
(see `Remap/README.md`) with the dimension `time` (age in ka BP, oldest first) and

- `z_topo` (m): the source's surface altitude `orog`, which is the ice or land surface
  on land and the sea floor in the ocean (ETOPO2 at present);
- `H_ice` (m): ice thickness (`sftgit`);
- `f_ice` (1): ice mask (`sftgif`, 0 or 100 %) as a fraction, 0 or 1.

The grid cells are centred on whole degrees of longitude (0, 1, ..., 359°, shifted by
half a cell from ICE-6G_C); the longitudes are reordered to -180:179. The source has
one cell with an ice thickness of 6544 m at 18 ka (12°E, 56.5°N; about 800 m around
it), kept as it is.
