# Total sediment thickness of the oceans, GlobSed v3 (Straume et al., 2019)

Total sediment thickness of the world's oceans and marginal seas on a 5 arc-min
lon-lat grid (missing on land), from:

Straume, E. O., Gaina, C., Medvedev, S., Hochmuth, K., Gohl, K., Whittaker, J. M.,
Abdul Fattah, R., Doornenbal, J. C. and Hopper, J. R.: GlobSed: Updated total sediment
thickness in the world's oceans, Geochem. Geophys. Geosyst., 20, 1756-1772, 2019,
[doi:10.1029/2018GC008115](https://doi.org/10.1029/2018GC008115).

GlobSed updates the NOAA NCEI grid (Divins, 2003; Whittaker et al., 2013) with regional
maps of the NE Atlantic, Arctic, Mediterranean, Weddell Sea and the West Antarctic margin.

## Licence

CC BY 4.0, as archived at PANGAEA by the authors (Straume et al., 2025,
[doi:10.1594/PANGAEA.982339](https://doi.org/10.1594/PANGAEA.982339)). The same file is
also at CaltechDATA under CC0 ([doi:10.22002/k4070-ngc79](https://doi.org/10.22002/k4070-ngc79)).

## Original data

NOAA NCEI distributed GlobSed until it retired the page on 2025-05-12. `GlobSed.zip`
(65 MB, no login) from PANGAEA,
<https://download.pangaea.de/dataset/982339/files/GlobSed.zip>, of which
`GlobSed/GlobSed_package3/GlobSed-v3.nc` is used. It is in `datamanifest.toml`
(`globsed_v3`) and downloaded and extracted by `prepare.jl` if missing.

## Prepare and remap

```bash
julia --project=Straume2019_globsed Straume2019_globsed/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Straume2019_globsed/Straume2019_GlobSed.nc all --name=Sediment-GlobSed
```

`prepare.jl` writes `z_sed` (m) to
`$FESMDATA_WORK/prepared/Straume2019_globsed/Straume2019_GlobSed.nc` (see `Remap/README.md`).
`GlobSed-v3.nc` is gridline registered, with nodes from -180° to 180° and -90° to 90°:
the column at 180°, which repeats the one at -180°, is dropped, and the nodes are taken
as the centres of the cells.
