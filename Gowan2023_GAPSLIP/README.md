# Relative sea level indicators, GAPSLIP (Gowan, 2023)

The relative sea level indicators of the Global Archive of Paleo Sea Level Indicators
and Proxies (GAPSLIP), version 2.1, of all regions and of Greenland: the database with
which Gowan evaluates the PaleoMIST 1.0 ice-sheet reconstruction (Gowan et al., 2021; PaleoMIST
reports with GAPSLIP 2.0, Zenodo doi:10.5281/zenodo.7923553). From:

Gowan, E. J.: Paleo sea-level indicators and proxies from Greenland in the GAPSLIP
database and comparison with modelled sea level from the PaleoMIST ice-sheet
reconstruction, GEUS Bulletin, 53, 2023,
[doi:10.34194/geusb.v53.8355](https://doi.org/10.34194/geusb.v53.8355).

Gowan, E. J., Zhang, X., Khosravi, S., Rovere, A., Stocchi, P., Hughes, A. L. C.,
Gyllencreutz, R., Mangerud, J., Svendsen, J.-I. and Lohmann, G.: A new global ice sheet
reconstruction for the past 80000 years, Nature Communications, 12, 1199, 2021,
[doi:10.1038/s41467-021-21469-w](https://doi.org/10.1038/s41467-021-21469-w).

Data: Gowan, E. J.: evangowan/paleo_sea_level: Version 2.1, Zenodo, 2023,
[doi:10.5281/zenodo.10121689](https://doi.org/10.5281/zenodo.10121689)
(GitHub repository evangowan/paleo_sea_level, commit 1c72e2f). The individual data are
from the publications in the `reference` of each sample; GAPSLIP asks to cite them.

Two products of the records dataset RSL: `RSL-GAPSLIP_global` (all regions) and
`RSL-GAPSLIP` (the region Greenland: 1019 samples at 47 locations, up to about 44 ka).

## Licence

CC BY-SA 4.0 (`LICENSE.txt` of the repository), recorded here as the stricter of the
two: the Zenodo record of version 2.1 states CC BY 4.0. Derived products are to be
shared under CC BY-SA 4.0.

## Original data

The archive of version 2.1 on Zenodo,
https://zenodo.org/records/10121689/files/evangowan/paleo_sea_level-V2.1.zip (datamanifest
key `gapslip_v2_1`; 16 MB, no login), downloaded by `prepare.jl` and extracted to
`evangowan-paleo_sea_level-1c72e2f/`. In `sea_level_data/`, `region_list.txt` lists the
regions; each region has `location_list.txt` (location, sector, site, names for the
plots) and each location `calibrated.txt`, written by the calibration scripts of GAPSLIP
(radiocarbon ages calibrated with OxCal 4.4.4, IntCal20, SHCal20 and Marine20): sample
id, latitude, longitude, age (cal yr BP, the middle of the 2σ range), half the 2σ age
range, indicator type, RSL (m), its upper and lower 2σ uncertainty, references.

## Definitions (Gowan's)

- `rsl`: relative sea level relative to present, the elevation of the indicator
  corrected for its indicative meaning (m); `rsl_min`, `rsl_max`: its 2σ range (the
  elevation and indicative-range uncertainties).
- `time`: the age in years before 1950 CE (cal yr BP; "years ago" in FesmData), the
  middle of the 2σ range; `time_min`, `time_max`: the 2σ range.
- `type`: 0 index point (sea level was within `rsl_min` to `rsl_max`), -1 marine
  limiting (the sample formed below sea level: sea level was above `rsl_min`), 1
  terrestrial limiting (formed above sea level: sea level was below `rsl_max`).
- `region` (the data folders: North_America_Arctic, North_America_Atlantic, Caribbean,
  Greenland, Eurasian_Arctic, Europe, East_Asia, Southeast_Asia, South_Asia, Australia,
  Pacific_Islands, Antarctica), `sector` and `site` from `location_list.txt`; `site_name`
  is the location (folder).
- `alternative`: 1 for a location that is another reading of the samples of its `site`
  (Bonaparte Gulf and Sahul Shelf after Ishiwa et al. 2019 and Yokoyama et al. 2000,
  Huon Peninsula after de Gelder, Kikaijima with uplift rates of 1.7-2.3 mm/yr), 0 for the
  primary data. Use `alternative == 0` to count each sample once.

Left out: the region `Proxy_Based_Sea_Level` (sea level from δ18O proxies, kept apart
from the indicators by GAPSLIP) and the folder `Australia/Sahul_Shelf`, which is not in
`location_list.txt` (its two alternatives are).

## Prepare and record

```bash
julia --project=Gowan2023_GAPSLIP Gowan2023_GAPSLIP/prepare.jl
julia fesmdata.jl record RSL
```

`prepare.jl` writes, in `$FESMDATA_PREPARED/Gowan2023_GAPSLIP/` (see `Records/README.md`),
one observation per sample (featureType point, dimension `obs`):

- `GAPSLIP_global.nc` (`RSL-GAPSLIP_global`): `lat`, `lon`, `time`, `time_min`,
  `time_max`, `rsl`, `rsl_min`, `rsl_max`, `type`, `alternative`, and the strings
  `lab_id`, `site_name`, `site`, `sector`, `region` and `reference` (bibtex keys of
  GAPSLIP), sorted by region, location and age;
- `GAPSLIP_Greenland.nc` (`RSL-GAPSLIP`): the samples of the region Greenland, without
  `alternative`, `site` and `region` (all primary, site = location there).

Until RSL v2.1.0 the Greenland product had a source of its own,
`Gowan2023_GAPSLIP_GrIS`, with the same data. Its v1 files `rsl_dataset.nc` and
`rsl_dataset_reduced.nc` grouped the samples by the cells of the GRL-8KM grid and by
location for one model; they are not made any more (see `Records/README.md`: inputs
derived for one model stay with the model).
