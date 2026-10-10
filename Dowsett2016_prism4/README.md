# PRISM4 Pliocene topography and ice sheets (Dowsett et al., 2016)

Topography and ice sheets of the mid-Piacenzian (Pliocene, about 3.2 Ma) on a 1°
lon-lat grid, from the PRISM4 reconstruction as given for the PlioMIP2 experiments
(enhanced: Pliocene land-sea mask; standard: modern land-sea mask), with the modern
topography they are based on (for anomalies):

Dowsett, H., Dolan, A., Rowley, D., Moucha, R., Forte, A. M., Mitrovica, J. X., Pound,
M., Salzmann, U., Robinson, M., Chandler, M., Foley, K., and Haywood, A.: The PRISM4
(mid-Piacenzian) paleoenvironmental reconstruction, Clim. Past, 12, 1519-1538, 2016,
[doi:10.5194/cp-12-1519-2016](https://doi.org/10.5194/cp-12-1519-2016).

Haywood, A. M., et al.: The Pliocene Model Intercomparison Project (PlioMIP) Phase 2:
scientific objectives and experimental design, Clim. Past, 12, 663-675, 2016,
[doi:10.5194/cp-12-663-2016](https://doi.org/10.5194/cp-12-663-2016).

## Licence

Published by the U.S. Geological Survey (PRISM, <https://geology.er.usgs.gov/egpsc/prism/>),
public domain; no licence is stated in the files, which were made at the University
of Leeds (A. M. Dolan) from the reconstruction of D. Rowley (University of Chicago).

## Original data

The PlioMIP2 boundary conditions from USGS (no login), `prism4_plio_enh`,
`prism4_plio_std` and `prism4_modern_std` in `datamanifest.toml`:

```bash
wget https://geology.er.usgs.gov/egpsc/prism/data/Plio_enh.zip
wget https://geology.er.usgs.gov/egpsc/prism/data/Plio_std.zip
wget https://geology.er.usgs.gov/egpsc/prism/data/Modern_std.zip
```

Of these, the topography (`*_topo_v1.0.nc`) and ice masks (`Plio_*_icemask_v1.0.nc`)
are used. The land-sea masks are not needed: they are the non-ocean cells of the ice
masks, and for the modern state the cells with positive topography.

## Prepare and remap

```bash
julia --project=Dowsett2016_prism4 Dowsett2016_prism4/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Dowsett2016_prism4/Dowsett2016_PRISM4.nc all --name=ICEHISTORY-PRISM4
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Dowsett2016_prism4/Dowsett2016_PRISM4.nc`
(see `Remap/README.md`) with

- `z_topo_enh`, `z_topo_std`, `z_topo_mod` (m): topography (surface on land and ice,
  sea floor in the ocean) of the enhanced and standard Pliocene experiments and of the
  modern state (ETOPO1 at 1°). The standard topography has no bathymetry (missing over
  the ocean) and is 0 where the Pliocene land was extended to the modern coastline;
- `mask_enh`, `mask_std` (integer): surface type, 0 ocean, 1 land, 2 ice.

The ice masks flag 0 (ocean) as `missing_value`; it is read as a class. The v1
product used `Plio_enh_icemask_v2.0.nc`, which is `Plio_enh_icemask_v1.0.nc` with the
missing value set to -9999 (`cdo setmissval`), i.e. the same mask.
