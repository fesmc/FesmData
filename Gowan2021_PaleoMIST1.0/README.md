# PaleoMIST 1.0: global ice sheets of the past 80 000 years (Gowan et al., 2021)

Global reconstruction of the ice sheets, with the topography and sea level consistent with
them (glacial isostatic adjustment), from 80 ka to present every 2.5 kyr:

Gowan, E. J., Zhang, X., Khosravi, S., Rovere, A., Stocchi, P., Hughes, A. L. C.,
Gyllencreutz, R., Mangerud, J., Svendsen, J.-I. and Lohmann, G.: A new global ice sheet
reconstruction for the past 80 000 years, Nat. Commun., 12, 1199, 2021,
[doi:10.1038/s41467-021-21469-w](https://doi.org/10.1038/s41467-021-21469-w).

Data: Gowan, E. J. et al.: Global ice sheet reconstruction for the past 80000 years,
PANGAEA, [doi:10.1594/PANGAEA.905800](https://doi.org/10.1594/PANGAEA.905800), 2021.

## Licence

CC BY 4.0 (PANGAEA).

## Original data

`Gowan_ice_reconstruction.zip` (3.5 GB, no login) from PANGAEA,
<https://hs.pangaea.de/Maps/Global_Ice_Sheets/Gowan_ice_reconstruction.zip>,
`gowan2021_paleomist` in `datamanifest.toml`. Used are, in `ice_reconstruction/`:

- `global_grid/reconstruction_0.25_degree.nc`: the global 0.25° grids made by the author
  from the regional reconstructions (smoothed with a 25 km Gaussian filter);
- `ice_reconstruction_files/<region>/thickness/<age>.nc`: the ice thickness of the 5 km
  regional reconstructions (North_America, which includes Greenland, Eurasia, Patagonia
  and Antarctica; GMT grids on the projections of `projection_info.sh`).

These are the minimal MIS 3 scenario for North America (an ice-free Hudson Bay at times);
the files of the maximal scenario end in `a1` (not prepared).

## Prepare and remap

```bash
julia --project=Gowan2021_PaleoMIST1.0 Gowan2021_PaleoMIST1.0/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Gowan2021_PaleoMIST1.0/Gowan2021_PaleoMIST.nc all --name=IceHistory-PaleoMIST
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Gowan2021_PaleoMIST1.0/Gowan2021_PaleoMIST.nc`
(see `Remap/README.md`) on the 0.25° grid with the dimension `time` (years ago, before
1950 CE, 80000 to 0, oldest first) and

- `z_topo` (m): topography (`paleo_topography`), the ice surface on the ice sheets and the
  bed elsewhere, relative to the sea level of the time;
- `z_bed` (m): bed elevation (`base_topography`, the deformed topography without ice);
- `H_ice` (m): grounded ice thickness (`ice_thickness`); the small negative values next to
  the ice margins, left by the smoothing of the author, are set to 0;
- `dz_sl` (m): sea-level change from present (`sea_level`, from the sea-level equation);
- `f_ice` (1): ice area fraction, the fraction of 5 x 5 samples per 0.25° cell where the
  5 km regional reconstruction has ice (thickness > 0). It is derived from the unsmoothed
  regional grids, so it follows the reconstructed margins rather than the smoothed
  thickness. Outside the regional grids there is no ice.

The 0.25° grid is gridline registered (latitudes -90 to 90); the longitude 180°, which
repeats -180°, is left out. The regional grids are placed with the parameters of their
`projection_info.sh` (Lambert azimuthal equal-area with x and y from the lower-left
corner of the region, polar stereographic with true scale at 71°S for Antarctica, WGS84).
