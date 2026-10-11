# Global 3D mantle viscosity from GLAD-M25 (Lloyd et al., 2024)

Global 3D mantle viscosity on a 0.5° lon-lat grid at 201 depths from the surface to the
core-mantle boundary (2891 km), inferred from the shear-wave speeds of the global
adjoint tomography model GLAD-M25 (Richards et al., 2020, calibration to 400 km;
Austermann et al., 2021, below), from the supporting information of:

Lloyd, A. J., Crawford, O., Al-Attar, D., Austermann, J., Hoggard, M. J., Richards, F. D.
and Syvret, F.: GIA imaging of 3-D mantle viscosity based on palaeo sea level
observations - Part I: Sensitivity kernels for an Earth with laterally varying
viscosity, Geophys. J. Int., 236, 1139-1171, 2024,
[doi:10.1093/gji/ggad455](https://doi.org/10.1093/gji/ggad455).

## Licence

The article and its supporting information are open access under CC BY 4.0. (The same
model is also distributed by the British Geological Survey with NERC terms; we use the
supporting information.)

## Original data

`ggad455_supplemental_files.zip` (203 MB, no login), the supporting information of the
article, entry `lloyd2024_visc` of `../datamanifest.toml`. Manual download: Europe PMC
assembles the zip (which holds `ggad455_supplemental_files.zip` and the figures of the
article) for several minutes before sending it, longer than DataManifest waits:

```bash
mkdir -p $DATAMANIFEST_DATASETS_DIR/lloyd2024_visc && cd $DATAMANIFEST_DATASETS_DIR/lloyd2024_visc
curl -L -o supp.zip "https://www.ebi.ac.uk/europepmc/webservices/rest/PMC10753356/supplementaryFiles"
unzip supp.zip ggad455_supplemental_files.zip && rm supp.zip
```

`prepare.jl` extracts `3D_visc_infer_GLAD-M25.nc` from it (through
`3D_visc_infer_GLAD-M25.nc.tar.gz`): `log10eta`, log10 of the viscosity in Pa s, on lon
-180:0.5:180, lat -90:0.5:90 and `depth` (km, 0-2891 km).

## Prepare and remap

```bash
julia --project=Lloyd2024_visc Lloyd2024_visc/prepare.jl
julia fesmdata.jl remap SolidEarth Lloyd2024
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Lloyd2024_visc/Lloyd2024_visc.nc` (see
`Remap/README.md`) with `log10_visc` (log10(Pa s)), log10 of the mantle viscosity, on
lon -180:0.5:179.5, lat -90:0.5:90 and `depth` (m, positive down, 201 levels, 1 km
apart near the surface). The top 10 km have a uniform viscosity (10^26.2 Pa s).

The column at 180° (the same meridian as -180°) is dropped; it differs from the column
at -180° at 15% of the points, by 0.003 on average.

The files `ANT-16KM_Lloyd2024.nc` and `ANT-32KM_Lloyd2024.nc` of the isostasy_data
repository (44 layers, with a lithosphere thickness) are not derived from this model:
see `../SolidEarth/README.md`.
