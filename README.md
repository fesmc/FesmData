# FesmData

Repository to manage data processing strategies to provide input to FESMs or for data analysis or comparison. Each source dataset is managed within its own sub-directory (which serves as the identifying "Key" in the tables below). Within a dataset's sub-directory, we should at least have:

1. A README.md file with general information, sources and references, the licence, instructions for how to obtain the original data and process them into a useable format (e.g. onto a desired grid) and any additional important notes (like unexpected behavior, exceptions, things to look out for, etc.).
2. Scripts/programs/tools needed to process the data as described in the README.

The data itself most often should not be stored in this repository itself. In fact, it is preferred if the first step of the instructions provided explain how to obtain the original data. As a rule of thumb, if the original dataset is < 10 Mb, consider including it directly within the repository for convenience, but please still document how it can be obtained. This will ensure the processed data can be recreated in the most reliable way possible. See Lucazeau2019_ghf as an example.

## Datasets

The v2 datasets (Topo, Regions, and the thematic datasets GHF, Velocity, SMB, ...) are
released on the grids of the model domains, from the base grid of each domain (25 m to
2 km) to 32 km, and on global lon-lat grids; the Records datasets (IceCores, RSL, ...)
hold non-gridded data. The [website](https://fesmc.github.io/FesmData/) lists them
([datasets](https://fesmc.github.io/FesmData/datasets.html),
[products](https://fesmc.github.io/FesmData/products.html),
[domains](https://fesmc.github.io/FesmData/domains.html)) and explains how to
[download](https://fesmc.github.io/FesmData/download.html) them.

## Code

In v2, every dataset is made from the original sources: a `prepare.jl` per source writes
its data in a simple standard form, which is then remapped onto the grids of the model
domains (thematic datasets such as GHF, defined by a `remap.toml`), merged by a pipeline
of its own (Topo, Regions), or copied as it is (Records). All commands go through
`julia fesmdata.jl` (`julia fesmdata.jl help`). The developer pages of the website
describe the [method and the code](https://fesmc.github.io/FesmData/developers.html), the
[machines and storage](https://fesmc.github.io/FesmData/machines.html),
[adding a dataset](https://fesmc.github.io/FesmData/adding.html) and
[releasing](https://fesmc.github.io/FesmData/releasing.html).

## Alternative and past approaches

In the past, we used the `gridding` ([https://github.com/alex-robinson/gridding](https://github.com/alex-robinson/gridding)) program to handle remapping (and preprocessing) of a wide variety of datasets that were relevant for ice-sheet modeling. This was how the original `ice_data` repository of gridded datasets was populated. It worked well, but was difficult to modify for new datasets, since it is entirely in Fortran, and requires configuration and compilation. For this reason, remapping via conservative interpolation using `cdo` became the favored approach for individual datasets. What was not included then was the preprocessing steps needed before applying interpolation. The v2 method reproduces the `ice_data` datasets from their original sources, with each step documented.

## Source folders (alphabetical order)

| Category | Key | Description | Ref(s) |
|----------|-----|-------------|--------|
| paleo    | Ahn2017_ProbStack           | Probabilistic benthic d18O stack, 5 Myr          | Ahn et al. (2017)              |
| ice      | ATL15_dzdt                  | Surface elevation change rate, ICESat-2 ATL15 v6 | Smith et al. (2026)            |
| paleo    | Badgeley2020_recon          | Greenland temperature and precipitation, 20 ka to present | Badgeley et al. (2020) |
| geo      | Bagge2021_visc              | Global 3D mantle viscosity                       | Bagge et al. (2021)            |
| geo      | Baranov2021_sed             | Antarctic sediment thickness, ANTASed            | Baranov et al. (2021)          |
| paleo    | Barker2011_GLTsyn           | Synthetic Greenland record GLT_syn, 800 kyr      | Barker et al. (2011)           |
| paleo    | Batchelor2019_NHIceMasks    | Northern Hemisphere ice extents, 18 time slices  | Batchelor et al. (2019)        |
| paleo    | Batchelor2019_PaleoMIST_lgc | Global ice extents of the last glacial cycle (Batchelor north, PaleoMIST south) | Batchelor et al. (2019), Gowan et al. (2021) |
| paleo    | Bereiter2015_CO2            | Antarctic ice core CO2 composite, 800 kyr        | Bereiter et al. (2015)         |
| paleo    | Berends2021_sealevel        | Sea level and CO2 of an ice-sheet-climate model, 3.6 Myr | Berends et al. (2021)          |
| paleo    | Bintanja2008_sealevel       | Sea level, NH ice volume and temperature, 3 Myr  | Bintanja and van de Wal (2008) |
| paleo    | Bouchet2023_AICC2023        | AICC2023 ice core chronology (EDC, EDML, NGRIP, TALDICE, Vostok) | Bouchet et al. (2023)          |
| paleo    | Buizert2018                 | Greenland seasonal temperatures, 22 ka to present | Buizert et al. (2018)         |
| paleo    | Buizert2018_cores           | Seasonal temperatures at Greenland ice core sites, 22 ka | Buizert et al. (2018)          |
| climate  | CMIP                        | Working with CMIP data (CMIP5/CMIP6/etc)         | Unpublished                    |
| geo      | Colgan2021_ghf              | Geothermal heat flow of Greenland                | Colgan & Wansing (2021)        |
| geo      | Colgan2021_topocorr         | Topographic correction of geothermal heat flow   | Colgan et al. (2021)           |
| geo      | Davies2013_ghf              | Global geothermal heat flow                      | Davies (2013)                  |
| ice      | Dawson2022_basalstate       | Antarctic ice sheet basal thermal state          | Dawson et al. (2022)           |
| paleo    | deBoer2014_sealevel         | Sea level and ice sheet contributions, 5.3 Myr   | de Boer et al. (2014)          |
| paleo    | Dowsett2016_prism4          | PRISM4 Pliocene topography and ice sheets        | Dowsett et al. (2016)          |
| paleo    | EPICA2006_EDML              | EDML d18O, 150 kyr                               | EPICA Community Members (2006) |
| climate  | ERA5                        | Monthly ERA5 for radiation + moist-stack valid. (v1) | Hersbach et al. (2020)     |
| smb      | Fettweis2017_mar314         | Greenland SMB and surface climate, MAR v3.14 (ERA5) | Fettweis et al. (2017)      |
| geo      | FoxMaule2005_ghf            | Geothermal heat flow from satellite magnetic data | Fox Maule et al. (2005)       |
| topo     | GEBCO2025                   | GEBCO 2025 global bath. and topo data (v1)       | GEBCO Compilation Group (2025) |
| paleo    | Gkinis2020_NEEMwateriso     | NEEM ice core high-resolution water isotopes     | Gkinis et al. (2020)           |
| geo      | Gowan2019_sed               | Surface sediment properties of North America and Greenland | Gowan et al. (2019) |
| paleo    | Gowan2021_PaleoMIST1.0      | PaleoMIST 1.0 global ice sheet reconstruction, 80 ka to present | Gowan et al. (2021) |
| paleo    | Gowan2021_PaleoMIST_esl     | Sea level from the ice sheets of PaleoMIST 1.0, 80 kyr | Gowan et al. (2021)            |
| paleo    | Gowan2023_GAPSLIP_GrIS      | Relative sea level data for Greenland            | Gowan (2023)                   |
| paleo    | Grant2014_RedSea            | Red Sea relative sea level, 492 kyr              | Grant et al. (2014)            |
| geo      | Hazzard2023_visc            | Antarctic mantle viscosity and lithosphere thickness | Hazzard et al. (2023)      |
| geo      | HazzardRichards2024_ghf     | Antarctic geothermal heat flow                   | Hazzard & Richards (2024)      |
| climate  | Hersbach2020_era5           | ERA5 monthly climatologies                       | Hersbach et al. (2020)         |
| climate  | Jackson2022                 | NAHosMIP freshwater hosing                       | Jackson et al. (2022)          |
| ice      | Joughin2018                 | Greenland ice surface velocity                   | Joughin et al. (2018)          |
| ocean    | Jourdain2020_ismip6         | ISMIP6 Antarctic ocean climatology (deprecated, see Zhou2026_ismip7ocean) | Jourdain et al. (2020) |
| paleo    | Jouzel2007_EDC              | EPICA Dome C deuterium and temperature, 800 kyr  | Jouzel et al. (2007)           |
| paleo    | Kindler2014                 | NGRIP temperature reconstruction, 10-120 kyr b2k | Kindler et al. (2014)          |
| paleo    | Koehler2017_GHG             | CO2, CH4, N2O splines and radiative forcing, 156 kyr | Köhler et al. (2017)           |
| paleo    | Lambeck2014_esl             | Ice-volume equivalent sea level, 35 ka to present | Lambeck et al. (2014)          |
| paleo    | Lambert2012_EDCdust         | EPICA Dome C dust flux, 800 kyr                  | Lambert et al. (2012)          |
| paleo    | Laskar2004_orbital          | Orbital elements (La2004) and insolation, 5 Ma to +1 Ma | Laskar et al. (2004)           |
| geo      | Laske2013_crust1            | Sediment thickness of CRUST1.0                   | Laske et al. (2013)            |
| paleo    | Leger2024_PaleoGris         | Retreat chronology of the Greenland Ice Sheet    | Leger et al. (2024)            |
| paleo    | Lisiecki2005_LR04           | LR04 benthic d18O stack, 5.3 Myr                 | Lisiecki and Raymo (2005)      |
| geo      | Lloyd2024_visc              | Global 3D mantle viscosity from GLAD-M25         | Lloyd et al. (2024)            |
| climate  | Loeb2018_ceres              | CERES EBAF Ed4.2.1 radiative fluxes              | Loeb et al. (2018)             |
| geo      | Loesing2021_ghf             | Geothermal heat flow of Antarctica               | Lösing & Ebbing (2021)         |
| ice      | Lokkegaard2023_temp_profile | Greenland and Canadian Arctic ice temperature profiles | Løkkegaard et al. (2023) |
| paleo    | Loulergue2008_CH4           | EPICA Dome C methane, 800 kyr                    | Loulergue et al. (2008)        |
| geo      | Lucazeau2019_ghf            | Global geothermal heat flow                      | Lucazeau (2019)                |
| ice      | MacGregor2025_strat         | Radiostratigraphy and age structure of the Greenland Ice Sheet | MacGregor et al. (2025) |
| ice      | Margold2015_icestreams      | Ice stream outlines                              | Margold et al. (2015)          |
| geo      | Martos2017_ghf              | Antarctic geothermal heat flow                   | Martos et al. (2017)           |
| geo      | Martos2018_ghf              | Geothermal heat flux of Greenland                | Martos et al. (2018)           |
| paleo    | Montoya2008_climber3a       | CLIMBER-3α present-day and LGM (weak, strong AMOC) climatologies | Montoya & Levermann (2008) |
| geo      | Mooney2023_ecm1             | Sediment thickness of ECM1                       | Mooney et al. (2023)           |
| geo      | Pan2022_litho               | Global lithosphere thickness and mantle viscosity | Pan et al. (2022)             |
| paleo    | Peltier2004_ice5g           | ICE-5G v1.2 ice-sheet reconstruction             | Peltier (2004)                 |
| paleo    | Peltier2015_ice6g           | ICE-6G_C (VM5a) ice-sheet and topography reconstruction | Peltier et al. (2015)   |
| paleo    | Peltier2018_ice6gd          | ICE-6G_D (VM5a) ice thickness and topography of Antarctica | Peltier et al. (2018) |
| paleo    | Petit1999_Vostok            | Vostok deuterium and temperature, 420 kyr        | Petit et al. (1999)            |
| paleo    | PMIP3_cvdp                  | PMIP3 climatologies (CMIP5 lgm, midHolocene, piControl) | Braconnot et al. (2012)  |
| paleo    | PMIP4_cmip6                 | PMIP4 climatologies (CMIP6 lgm, midHolocene, piControl) | Kageyama et al. (2018)  |
| paleo    | Rasmussen2014_GICC05        | NGRIP, GRIP, GISP2 d18O and calcium, GICC05modelext | Rasmussen et al. (2014)        |
| masks    | Regions                     | Regions v2: region tree, shelf zone, ice-sheet basins, 25 m-32 km | Multiple (see Regions/README.md) |
| masks    | regions_legacy              | Ice relevant regions (v1, deprecated)            | Robinson et al.  - no ref      |
| ice      | Rignot2011_vel              | Antarctic ice surface velocity                   | Rignot et al. (2011)           |
| ocean    | Rignot2013_bmelt            | Basal melt rates of Antarctic ice shelves        | Rignot et al. (2013)           |
| paleo    | Rohling2021_sealevel        | Sea level and ice sheet volumes, 5.3 Myr         | Rohling et al. (2021)          |
| paleo    | RSL_GrIS                    | Relative sea level reconstructions in Greenland  | Multiple                       |
| topo     | RTOPO2                      | RTopo2 global topography data                    | Schaffer et al. (2016)         |
| paleo    | Schilt2010_N2O              | EPICA Dome C nitrous oxide, 800 kyr              | Schilt et al. (2010)           |
| masks    | Schmidt2025_fwf             | Freshwater flux series of the ice sheets by region | Schmidt et al. (2025)        |
| ocean    | Schmidtko2014_ocean         | Antarctic shelf bottom water                     | Schmidtko et al. (2014)        |
| geo      | Schumacher2018_gps          | GPS vertical velocities (GIA uplift rates), global | Schumacher et al. (2018)     |
| geo      | Shapiro2004_ghf             | Global geothermal heat flow                      | Shapiro & Ritzwoller (2004)    |
| ice      | Smith2020_dzdt              | Elevation and thickness change rates, ICESat to ICESat-2 | Smith et al. (2020)    |
| paleo    | Spratt2016_sealevel         | Sea-level stacks, 798 kyr                        | Spratt and Lisiecki (2016)     |
| geo      | Stal2020_ghf                | Geothermal heat flow of Antarctica, Aq1          | Stål et al. (2021)             |
| paleo    | Stenni2011_TALDICE          | TALDICE d18O on AICC2012, 153 kyr                | Stenni et al. (2011)           |
| paleo    | Stokes2016_icestreams       | Laurentide ice sheet, ice-stream timing          | Stokes et al. (2016)           |
| geo      | Straume2019_globsed         | Total sediment thickness of the oceans, GlobSed v3 | Straume et al. (2019)        |
| smb      | SUMup_smb                   | SMB measurements, SUMup 2025                     | Vandecrux et al. (2025)        |
| paleo    | Tarasov2012_glac1d          | GLAC-1D ice-sheet reconstruction, 120 ka to present | Tarasov et al. (2012), Briggs et al. (2014) |
| topo     | Topo                        | Topography v2: GEBCO2026 + BedMachine/Bedmap3, 25 m-32 km | Multiple (see Topo/README.md) |
| paleo    | Uemura2018_DomeFuji         | Dome Fuji water isotopes and temperatures, 720 kyr | Uemura et al. (2012, 2018)     |
| smb      | vanDalum2025_racmo24        | Antarctic SMB and surface climate, RACMO2.4p1    | van Dalum et al. (2025)        |
| smb      | vanWessem2023_racmo23       | Antarctic SMB and surface climate, RACMO2.3p2    | van Wessem et al. (2018, 2023) |
| paleo    | Vinther2009_elevations      | Elevations at the ice core locations             | Vinther et al. (2009)          |
| paleo    | Waelbroeck2002_sealevel     | Sea level from benthic foraminifera, 430 kyr     | Waelbroeck et al. (2002)       |
| paleo    | WAIS2015_WDC                | WAIS Divide d18O, 68 kyr                         | WAIS Divide Project Members (2015) |
| geo      | Wiens2022_visc              | Antarctic upper-mantle viscosity                 | Wiens et al. (2022)            |
| ocean    | Zhou2026_ismip7ocean        | ISMIP7 Antarctic ocean climatology               | Zhou et al. (2026)             |
| ocean    | Zuo2019_oras5               | Ocean temperature and salinity from ORAS5        | Zuo et al. (2019)              |
