# Relative sea level indicators of Greenland, GAPSLIP (Gowan, 2023)

The relative sea level indicators of Greenland (1019 dated samples at 47 locations, up
to about 44 ka) in the Global Archive of Paleo Sea Level Indicators and Proxies
(GAPSLIP), version 2.1. From:

Gowan, E. J.: Paleo sea-level indicators and proxies from Greenland in the GAPSLIP
database and comparison with modelled sea level from the PaleoMIST ice-sheet
reconstruction, GEUS Bulletin, 53, 2023,
[doi:10.34194/geusb.v53.8355](https://doi.org/10.34194/geusb.v53.8355).

Data: Gowan, E. J.: evangowan/paleo_sea_level: Version 2.1, Zenodo, 2023,
[doi:10.5281/zenodo.10121689](https://doi.org/10.5281/zenodo.10121689)
(GitHub repository evangowan/paleo_sea_level).

## Licence

CC BY-SA 4.0 (`LICENSE.txt` of the repository); the Zenodo record of version 2.1 states
CC BY 4.0. Derived products may have to be shared under CC BY-SA 4.0.

## Original data

The archive of version 2.1 on Zenodo,
https://zenodo.org/records/10121689/files/evangowan/paleo_sea_level-V2.1.zip (16 MB, no
login), downloaded and extracted by `prepare.jl` (datamanifest key `gapslip_v2_1`). In
`sea_level_data/Greenland/`, `location_list.txt` lists the locations and their sector,
and each location has `calibrated.txt`, written by the calibration scripts of GAPSLIP
(radiocarbon ages calibrated with OxCal 4.4.4, IntCal20, SHCal20 and Marine20): sample
id, latitude, longitude, age (cal yr BP, the middle of the 2σ range), half the 2σ age
range, indicator type, RSL (m), its upper and lower 2σ uncertainty, references.

## Prepare and record

```bash
julia --project=Gowan2023_GAPSLIP_GrIS Gowan2023_GAPSLIP_GrIS/prepare.jl
julia fesmdata.jl record RSL GAPSLIP
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Gowan2023_GAPSLIP_GrIS/GAPSLIP_Greenland.nc`
(see `Records/README.md`), one observation per sample (featureType point, dimension
`obs`): `lat`, `lon`, `time` (years before 1950 CE) with `time_min`, `time_max` (2σ
range), `rsl` with `rsl_min`, `rsl_max` (m, 2σ range), `type` (-1 marine limiting: sea
level was above `rsl_min`; 0 index point; 1 terrestrial limiting: sea level was below
`rsl_max`), and the strings `lab_id`, `site_name` (location), `sector` and `reference`
(bibtex keys of GAPSLIP).

The v1 files `rsl_dataset.nc` and `rsl_dataset_reduced.nc` grouped the samples by the
cells of the GRL-8KM grid and by location for one model; they are not made any more
(see `Records/README.md`: inputs derived for one model stay with the model).
