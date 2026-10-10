# FesmData

Repository to manage data processing strategies to provide input to FESMs or for data analysis or comparison. Each source dataset is managed within its own sub-directory (which serves as the identifying "Key" in the tables below). Within a dataset's sub-directory, we should at least have:

1. A README.md file with general information, sources and references, the licence, instructions for how to obtain the original data and process them into a useable format (e.g. onto a desired grid) and any additional important notes (like unexpected behavior, exceptions, things to look out for, etc.).
2. Scripts/programs/tools needed to process the data as described in the README.

The data itself most often should not be stored in this repository itself. In fact, it is preferred if the first step of the instructions provided explain how to obtain the original data. As a rule of thumb, if the original dataset is < 10 Mb, consider including it directly within the repository for convenience, but please still document how it can be obtained. This will ensure the processed data can be recreated in the most reliable way possible. See Lucazeau2019_ghf as an example.

## v2 method

In v2, every dataset is made in two steps (see `Remap/README.md`):

1. **Prepare**: the source folder (e.g. `Lucazeau2019_ghf/`) has a `prepare.jl` that gets the original files (listed in `datamanifest.toml`) and writes them as a NetCDF file on their own grid, in a simple standard form, to `$FESMDATA_WORK/prepared/<Key>/`.
2. **Remap**: `julia fesmdata.jl remap <file>` puts a prepared file onto the grids of the model domains, in `$ICE_DATA/v2/<Domain>/<GRID>/<GRID>_<Dataset>-<Product>.nc`. Remapping is conservative (with smoothing where the target grid is coarser), and handles extra dimensions (month, time, depth, ...), integer fields (dominant class) and vectors (rotated to the grid axes).

A **thematic dataset** (e.g. `GHF/`) groups the products of several sources in its `remap.toml`: `julia fesmdata.jl remap GHF` makes all of them, and they are released together.

## Shared resources

`shared` : code and settings shared by the v2 pipelines: the model domains and their grids (`domains.toml`), the machine environments (`machines/<machine>.env`), the NetCDF output (`io.jl`), the original datasets (`manifest.jl`, with `datamanifest.toml`), the provenance attributes (`provenance.jl`) and the gridding of equal-area points (`ringgrid.jl`).

`Remap` : the generic remapping of prepared files and thematic datasets (`julia fesmdata.jl remap`), with the jobs to run it on Levante.

`maps` : predefined grid description files following the `cdo` conventions (v1).
`grid` : tools to generate files corresponding to specific grid definitions as in `maps` (v1).

Every NetCDF file written by a v2 pipeline has the global attributes `source` (this repository), `fesmdata_version` (`git describe` against the release tags of the dataset, e.g. `topo-v2.0.0`, with `-dirty` for uncommitted changes), `fesmdata_commit` and `history` (time, script and arguments).

`Publish` : the released products are stored on [GitLab (DKRZ)](https://gitlab.dkrz.de/fesmc/fesmdata-products/-/packages), one package per domain, dataset and grid, optionally archived on [Zenodo](https://zenodo.org/communities/fesmc) for a DOI, and listed in `registry/` and on the [project website](https://fesmc.github.io/FesmData/); find, download and release them with `julia fesmdata.jl` (e.g. `julia fesmdata.jl list`, `julia fesmdata.jl fetch Antarctica Topo ANT-16KM`; `julia fesmdata.jl help` for all commands, `Publish/README.md` for details).

## Alternative and past approaches

In the past, we used the `gridding` ([https://github.com/alex-robinson/gridding](https://github.com/alex-robinson/gridding)) program to handle remapping (and preprocessing) of a wide variety of datasets that were relevant for ice-sheet modeling. This was how the original `ice_data` repository of gridded datasets was populated. It worked well, but was difficult to modify for new datasets, since it is entirely in Fortran, and requires configuration and compilation. For this reason, remapping via conservative interpolation using `cdo` became the favored approach for individual datasets. What was not included then was the preprocessing steps needed before applying interpolation. The v2 method above reproduces the `ice_data` datasets from their original sources, with each step documented.

## v2 datasets

| Key | Contents | Sources |
|-----|----------|---------|
| Topo         | Bed topography, surface elevation, ice thickness, ice/ocean fractions, 0.5-32 km | GEBCO 2026, BedMachine, Bedmap3, IceBoost (see Topo/README.md) |
| Regions      | Region tree, shelf zone, ice-sheet basins, 0.5-32 km | Marine Regions, HydroBASINS, Zwally, Mouginot, IMBIE (see Regions/README.md) |
| GHF          | Geothermal heat flow (mW m-2), topographic correction | Colgan2021_ghf, Colgan2021_topocorr, Davies2013_ghf, FoxMaule2005_ghf, HazzardRichards2024_ghf, Loesing2021_ghf, Lucazeau2019_ghf, Martos2017_ghf, Martos2018_ghf, Shapiro2004_ghf, Stal2020_ghf |
| Sediment     | Sediment thickness | Laske2013_crust1, Straume2019_globsed |
| IceHistory   | Ice sheets and topography of the past | Dowsett2016_prism4, Peltier2004_ice5g, Peltier2015_ice6g |
| Velocity     | Ice surface velocity | Joughin2018, Rignot2011_vel |
| Stratigraphy | Age structure of the ice | MacGregor2025_strat |
| BasalMelt    | Ice-shelf basal melt rates | Rignot2013_bmelt |
| Ocean        | Ocean temperature and salinity | Schmidtko2014_ocean, Zhou2026_ismip7ocean, Zuo2019_oras5 |
| Atmosphere   | Reanalysis and satellite climatologies | Hersbach2020_era5, Loeb2018_ceres |
| SMB          | Surface mass balance and surface climate | Fettweis2017_mar314, vanDalum2025_racmo24 |
| Paleoclimate | Simulations and reconstructions of past climates | Badgeley2020_recon, Buizert2018, PMIP3_cvdp, PMIP4_cmip6 |

## Source folders (alphabetical order)

| Category | Key | Description | Ref(s) |
|----------|-----|-------------|--------|
| paleo    | Badgeley2020_recon          | Greenland temperature and precipitation, 20 ka to present | Badgeley et al. (2020) |
| topo     | Batchelor2019_NHIceMasks    | Northern Hemisphere ice extent masks             | Batchelor et al. (2019)        |
| paleo    | Buizert2018                 | Greenland seasonal temperatures, 22 ka to present | Buizert et al. (2018)         |
| climate  | CMIP                        | Working with CMIP data (CMIP5/CMIP6/etc)         | Unpublished                    |
| geo      | Colgan2021_ghf              | Geothermal heat flow of Greenland                | Colgan & Wansing (2021)        |
| geo      | Colgan2021_topocorr         | Topographic correction of geothermal heat flow   | Colgan et al. (2021)           |
| geo      | Davies2013_ghf              | Global geothermal heat flow                      | Davies (2013)                  |
| ice      | Dawson2022_AntarcticaBasalState | Antarctic ice sheet basal thermal state      | Dawson et al. (2022)           |
| paleo    | Dowsett2016_prism4          | PRISM4 Pliocene topography and ice sheets        | Dowsett et al. (2016)          |
| geo      | ECM1_geo                    | Global sediment thickness data (ECM1)            | Mooney et al. (2023)           |
| climate  | ERA5                        | Monthly ERA5 for radiation + moist-stack valid. (v1) | Hersbach et al. (2020)     |
| smb      | Fettweis2017_mar314         | Greenland SMB and surface climate, MAR v3.14 (ERA5) | Fettweis et al. (2017)      |
| geo      | FoxMaule2005_ghf            | Geothermal heat flow from satellite magnetic data | Fox Maule et al. (2005)       |
| topo     | GEBCO2025                   | GEBCO 2025 global bath. and topo data            | GEBCO Compilation Group (2025) |
| paleo    | Gkinis2020_NEEMwateriso     | NEEM ice core high-resolution water isotopes     | Gkinis et al. (2020)           |
| geo      | Gowan2019_sed               | Geological sediment properties for North America | Gowan et al. (2019)            |
| paleo    | Gowan2023_GAPSLIP_GrIS      | Relative sea level data for Greenland            | Gowan (2023)                   |
| geo      | HazzardRichards2024_ghf     | Antarctic geothermal heat flow                   | Hazzard & Richards (2024)      |
| climate  | Hersbach2020_era5           | ERA5 monthly climatologies                       | Hersbach et al. (2020)         |
| climate  | Jackson2022                 | NAHosMIP freshwater hosing                       | Jackson et al. (2022)          |
| ice      | Joughin2018                 | Greenland ice surface velocity                   | Joughin et al. (2018)          |
| ocean    | Jourdain2020_ismip6         | ISMIP6 Antarctic ocean climatology (deprecated, see Zhou2026_ismip7ocean) | Jourdain et al. (2020) |
| paleo    | Kindler2014                 | NGRIP temperature reconstruction, 10-120 kyr b2k | Kindler et al. (2014)          |
| geo      | Laske2013_crust1            | Sediment thickness of CRUST1.0                   | Laske et al. (2013)            |
| paleo    | Leger2024_PaleoGris         | Retreat chronology of the Greenland Ice Sheet    | Leger et al. (2024)            |
| climate  | Loeb2018_ceres              | CERES EBAF Ed4.2.1 radiative fluxes              | Loeb et al. (2018)             |
| geo      | Loesing2021_ghf             | Geothermal heat flow of Antarctica               | Lösing & Ebbing (2021)         |
| ice      | Lokkegaard2023_temp_profile | Greenland and Canadian Arctic ice temperature profiles | Løkkegaard et al. (2023) |
| geo      | Lucazeau2019_ghf            | Global geothermal heat flow                      | Lucazeau (2019)                |
| ice      | MacGregor2025_strat         | Radiostratigraphy and age structure of the Greenland Ice Sheet | MacGregor et al. (2025) |
| ice      | Margold2015_icestreams      | Ice stream outlines                              | Margold et al. (2015)          |
| geo      | Martos2017_ghf              | Antarctic geothermal heat flow                   | Martos et al. (2017)           |
| geo      | Martos2018_ghf              | Geothermal heat flux of Greenland                | Martos et al. (2018)           |
| geo      | Pan2022_litho               | Global lithospheric thickness data               | Pan et al. (2022)              |
| paleo    | Peltier2004_ice5g           | ICE-5G v1.2 ice-sheet reconstruction             | Peltier (2004)                 |
| paleo    | Peltier2015_ice6g           | ICE-6G_C (VM5a) ice-sheet and topography reconstruction | Peltier et al. (2015)   |
| paleo    | PMIP3_cvdp                  | PMIP3 climatologies (CMIP5 lgm, midHolocene, piControl) | Braconnot et al. (2012)  |
| paleo    | PMIP4_cmip6                 | PMIP4 climatologies (CMIP6 lgm, midHolocene, piControl) | Kageyama et al. (2018)  |
| masks    | Regions                     | Regions v2: region tree, shelf zone, ice-sheet basins, 0.5-32 km | Multiple (see Regions/README.md) |
| masks    | regions_legacy              | Ice relevant regions (v1, deprecated)            | Robinson et al.  - no ref      |
| ice      | Rignot2011_vel              | Antarctic ice surface velocity                   | Rignot et al. (2011)           |
| ocean    | Rignot2013_bmelt            | Basal melt rates of Antarctic ice shelves        | Rignot et al. (2013)           |
| paleo    | RSL_GrIS                    | Relative sea level reconstructions in Greenland  | Multiple                       |
| topo     | RTOPO2                      | RTopo2 global topography data                    | Schaffer et al. (2016)         |
| masks    | Schmidt2025_fwf             | Runoff basins GrIS and AIS, plus fwf time series | Schmidt et al. (2025)          |
| ocean    | Schmidtko2014_ocean         | Antarctic shelf bottom water                     | Schmidtko et al. (2014)        |
| geo      | Schumacher2018_GIA_GrIS     | GIA measurements in Greenland                    | Schumacher et al. (2018)       |
| geo      | Shapiro2004_ghf             | Global geothermal heat flow                      | Shapiro & Ritzwoller (2004)    |
| geo      | Stal2020_ghf                | Geothermal heat flow of Antarctica, Aq1          | Stål et al. (2021)             |
| paleo    | Stokes2016_icestreams       | Laurentide ice sheet, ice-stream timing          | Stokes et al. (2016)           |
| geo      | Straume2019_globsed         | Total sediment thickness of the oceans, GlobSed v3 | Straume et al. (2019)        |
| smb      | SUMup_smb                   | Global SMB database                              | Vandecrux et al.               |
| topo     | Topo                        | Topography v2: GEBCO2026 + BedMachine/Bedmap3, 0.5-32 km | Multiple (see Topo/README.md) |
| smb      | vanDalum2025_racmo24        | Antarctic SMB and surface climate, RACMO2.4p1    | van Dalum et al. (2025)        |
| paleo    | Vinther2009_elevations      | Elevations at the ice core locations             | Vinther et al. (2009)          |
| ocean    | Zhou2026_ismip7ocean        | ISMIP7 Antarctic ocean climatology               | Zhou et al. (2026)             |
| ocean    | Zuo2019_oras5               | Ocean temperature and salinity from ORAS5        | Zuo et al. (2019)              |
