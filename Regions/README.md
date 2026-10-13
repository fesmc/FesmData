# Regions: region masks, zones and basins

Masks of geographic regions, of present-day land, continental shelf and open ocean,
and of ice-sheet drainage basins, on every grid of every active domain (see
[Domains](https://fesmc.github.io/FesmData/domains.html)). Regions is made by a pipeline
of its own, from the bed elevation of the Topo product of each domain; the
[Products](https://fesmc.github.io/FesmData/products.html) page shows its versions on
each domain.

- **Regions** are a tree defined once, globally, in `regions.toml`, from standard
  datasets (countries and EEZs, IHO seas, oceans, HydroBASINS, IMBIE basins), so the
  same region has the same code in every domain. Each level of the tree covers the
  globe without gaps or overlaps.
- **Zones** separate present-day land, the continental shelf (up to the shelf break)
  and the open ocean, from the bed elevation of the topography product.
- **Basins** (`basins.toml`) are the drainage basins of the ice sheets, extended over
  the land and shelf of their region up to the shelf break.

## Products

| Product | Source | Fields | Domains |
|---|---|---|---|
| `REGIONS` | Marine Regions (EEZ-land union, IHO Sea Areas, Global Oceans and Seas), HydroBASINS, IMBIE basins (NSIDC-0709); the bed elevation of Topo | `region_1`, `region_2`, `region_3` (region codes), `zone` (0-3), `dist_shelfbreak` (km) | All |
| `BASINS-Mouginot2019` | Greenland glacier basins, 260 basins in 7 regions (Mouginot & Rignot, 2019, [doi:10.7280/D1WT11](https://doi.org/10.7280/D1WT11)) | `basin`, `basin_mask`, `basin_group` | GreenlandPaleo, North, with their crops and nests |
| `BASINS-Zwally2012` | GSFC drainage systems (Zwally et al., 2012); Greenland sub-systems 11 = 1.1 | `basin`, `basin_mask`, `basin_group` | GreenlandPaleo, North, Antarctica, with their crops and nests |
| `BASINS-IMBIE2016`, `BASINS-IMBIE2016-refined` | IMBIE 2016 and refined basins (Mouginot et al., 2017, NSIDC-0709 v2, [doi:10.5067/AXE4121732AD](https://doi.org/10.5067/AXE4121732AD)) | `basin`, `basin_mask`, `basin_group` | Antarctica, with its crops and nests |
| `BASINS-Schmidt2025` | Regions of the freshwater fluxes of the ice sheets (Schmidt et al., 2025, [doi:10.5281/zenodo.17386710](https://doi.org/10.5281/zenodo.17386710)): 7 Mouginot regions of Greenland, 18 IMBIE 2016 basins of Antarctica | `basin`, `basin_mask`, `basin_group` | GreenlandPaleo, North, Antarctica, with their crops and nests |
| `BASINS-SanRafael` | San Rafael Glacier (RGI2000-v7.0-G-17-12835), its RGI 7.0 outline as the footprint of its IceBoost v2 tile | `basin`, `basin_mask` | SRG |
| `BASINS-NEGIS-v1` | Northeast Greenland Ice Stream in three parts, drawn by hand for yelmox v1 on GRL-16KM (Ilaria Tabone, 2024) | `basin`, `basin_mask` | GreenlandPaleo, Greenland, NEGIS |
| `BASINS-NEGIS` | Northeast Greenland Ice Stream in three parts: centre and south from the surface speed (Joughin et al., 2018), north from NEGIS-v1 | `basin`, `basin_mask` | GreenlandPaleo, Greenland, NEGIS |

The files are `<GRID>_REGIONS.nc` and `<GRID>_BASINS-<set>.nc`. Everything is computed
on the base grid of a domain (e.g. ANT-1KM, GRL-PAL-500M, NH-2KM, PAT-250M, SRG-50M) and
then mapped onto all other grids and crops, as for the topography; a nest (e.g. SRG in
PAT) is computed on its own base grid. On each other grid, region codes, zones and
basins are the class covering most of a cell, nested level by level (a cell's
`region_3` lies within its `region_2`; basins within their group), and
`dist_shelfbreak` is the cell mean.

## Region codes

A region is named by its path in the tree: "1.3.1" is subregion 1 of region 3 of
region 1. Its code is the integer with two digits per level below the first:
"1" = 1, "1.3" = 103, "1.3.1" = 10301. The files have one variable per level,
`region_1`, `region_2`, `region_3`, each with the code of the deepest region at or
above that level, so a cell without a subregion keeps the code of its region. The
names of the codes are in the attributes `flag_values` and `flag_meanings`. Codes of
ocean regions start at 51. Helpers for codes are in FesmUtils.jl (`region_code`,
`region_path`, `region_ancestor`, `in_region`).

| Level 2 | Level 3 |
|---|---|
| 1.1 North America | 1.1.1 Canadian Arctic Archipelago, 1.1.2 Hudson Bay and Strait, 1.1.3 Cordillera and Alaska |
| 1.2 Western Eurasia | 1.2.1 Barents-Kara, 1.2.2 British Isles, 1.2.3 Svalbard, 1.2.4 Fennoscandia |
| 1.3 Greenland, 1.4 Asia, 1.5 Iceland, 1.6 Africa, 1.7 Latin America and the Caribbean, 1.8 Oceania | |
| 1.51 Arctic Ocean, 1.52 North Atlantic Ocean (with Baltic and Mediterranean), 1.53 North Pacific Ocean, 1.54 Indian Ocean, 1.55 South China and Eastern Archipelagic Seas | |
| 2.1 Antarctica (south of 60S) | 2.1.1 West Antarctica, 2.1.2 East Antarctica, 2.1.3 Antarctic Peninsula |
| 2.2 Latin America and the Caribbean, 2.3 Africa, 2.4 Asia, 2.5 Oceania, 2.51 South Atlantic, 2.52 South Pacific, 2.53 Indian Ocean, 2.54 South China and Eastern Archipelagic Seas | |

The rules of each region are documented in `regions.toml`. In short:

- Continents are the countries and their EEZs grouped by UN M49 region; Greenland
  and Iceland come first; oceans (GOaS) take the rest. The high seas of the Davis
  Strait, which GOaS puts in the Arctic Ocean, are in the North Atlantic, with the
  rest of the high seas of the Labrador Sea. The high seas of the Norwegian and
  Greenland seas, a pocket enclosed by the EEZs of Norway, the Faroe Islands, Iceland
  and Greenland that GOaS also puts in the Arctic Ocean, are in Western Eurasia.
- Russia is split between Western Eurasia and Asia at the divide between the
  rivers draining to the Kara and Laptev seas (HydroBASINS), and at sea at the
  boundary between the Kara and Laptev seas (IHO). Its EEZ in the Baltic and Black
  seas is in Western Eurasia.
- The NA subregions follow HydroBASINS and IHO seas; Hudson Bay and Strait include
  only the coastal basins draining into them, not the large rivers, and all their
  islands. Cordillera and Alaska includes the EEZs of North America in the Pacific.
- The Antarctic subregions are the IMBIE regions, extended to fill all of 2.1.
- Cells of a region enclosed by its subregions but covered by none of them (where the
  coastlines of the sources do not match) get the nearest subregion.

The mountain-glacier domains lie within few regions of level 2: e.g. PYR in 1.2 Western
Eurasia (land and EEZs of Spain, France and Andorra) and 1.52 North Atlantic Ocean
(beyond the EEZs, if any), PAT and its nests in 2.2 Latin America and the Caribbean.

## Zones

`zone` is 3 for present-day land (ice-free land and grounded ice), 2 for the
continental shelf (including floating ice), 1 for open ocean within `buffer` (50 km)
of the shelf break, and 0 for the open ocean beyond. `dist_shelfbreak` (km) is the
distance to the shelf break, positive in the open ocean, so other buffers are a
threshold on it.

The open ocean is the ice-free ocean connected to the abyss (deeper than
`z_abyss` = -2000 m) through cells deeper than the shelf-break depth `z_break`
(-500 m, -1000 m around Antarctica), after removing channels narrower than about
100 km (an opening of radius `r_open` = 50 km), which also smooths the shelf break. Deep troughs on the shelf that deepen
towards the ice sheet are therefore shelf. The parameters are in `regions.toml`.

A domain without open ocean, where no ocean deeper than `z_abyss` lies within the
domain (e.g. the mountain-glacier domains PYR and SRG), has only land and shelf, and
`dist_shelfbreak` is -Inf everywhere (as noted in the `comment` attribute of the
variable).

## Basins

Each file has `basin`, `basin_mask` (1 within the original basins) and, for sets
with groups (e.g. Mouginot regions, IMBIE regions, Zwally systems), `basin_group`. The
islands in the ice shelves of IMBIE2016-refined keep their extent but are not
extended, so the ice shelves around them go to the neighbouring grounded basins.

SanRafael is a single basin (1), the cells at least half covered by the glacier, not
extended: the part of the SRG domain that evolves freely in yelmox, while the rest
relaxes to the present-day state (in v1, `regions = 1` of SRG-250M_REGIONS.nc). PYR
has no basins.

### Schmidt2025

The regions to which the freshwater fluxes of the ice sheets are attributed in the
protocol of Schmidt et al. (2025) (`GL_regions_3413.gpkg`, `AQ_regions_3031.gpkg` of
Zenodo record 17386710), so that their time series (see `../Schmidt2025_fwf`) can be
mapped onto the grids. `basin` is the region number of the time series (names in
alphabetical order): Greenland 1-7 = CE, CW, NE, NO, NW, SE, SW; Antarctica 1-18 =
A-Ap, Ap-B, ..., K-A, grouped in `basin_group` by IMBIE region (East, Peninsula, West).

The polygons cover the ice sheets only (and not the ocean). In Greenland they are the
Mouginot (2019) regions without their peripheral ice caps (`ICE_CAPS_*`, 59 000 km2),
which go to the nearest region in the extension: the set is the same region as the
groups of Mouginot2019 on 99.99% of the cells of the polygons and 98% after the
extension. In Antarctica they are the IMBIE 2016 basins of NSIDC-0709 v2 (identical
geometry), so the set is identical to IMBIE2016.

The basins are extended as the other sets (over land and shelf up to the shelf break),
not as in the `*_regions_*_flood.nc` files of the record: these are the regions grown
over the whole rectangle around the ice sheet at 1 km (GRASS `r.grow`, nearest region
in straight line, over the open ocean and other land), and the Antarctic one is
numbered in another order than the time series (A-Ap = 7, Ap-B = 11, ...).

### NEGIS

The NEGIS sets split the Northeast Greenland Ice Stream into three parts, to tune basal
friction by part in yelmox: `basin` 1 centre (the trunk of 79N and Zachariae Isstrom
down to the coast), 2 south (the trunk upstream), 3 north (the northern arm), 0 outside.
They are not extended, so `basin_mask` is `basin != 0`, and have no groups (`negis.jl`).

**NEGIS-v1** are the parts of yelmox v1 (`basin_sub` 9.1, 9.2, 9.3 of
GRL-16KM_BASINS-nasa-negis-three.nc), drawn by hand by Ilaria Tabone (2024) on GRL-16KM.
They cannot be rebuilt, so the 248 cells are kept in the repository
(`sources/negis_v1_GRL-16KM.csv`). Each cell of the base grid takes the part of the
GRL-16KM cell containing its centre, so GRL-16KM reproduces v1 exactly (checked by
`06_negis.jl`, 0 cells differ), and the other grids are the majority as for all basins.

**NEGIS** builds the centre and south parts from the present-day surface speed, the
cell mean of the 250 m MEaSUREs velocity mosaic (NSIDC-0670 v1; Joughin et al., 2018) on
the base grid. The stream is the cells of Zwally drainage system 2 with grounded ice
(the topography of the zones) and a speed of at least 50 m/yr (30 m/yr south of the
cut), connected to the cell nearest to (400, -1162) km in the trunk of 79N. This leaves
out the separate fast cells of Storstrommen and L. Bistrup Brae. South is the stream
south of the cut line y = -1140 - 0.3 x (km, GRL polar stereographic), centre the rest.
The north part of v1 follows a palaeo ice stream that shut down in the Holocene (Franke
et al., 2022) and is slow today (4-50 m/yr), so neither a lower speed threshold nor a
band along the present flow reproduces it (IoU of the north part 0.50 and 0.73 at
best). Franke et al.
publish only the radar data (PANGAEA), not an outline, so the north part is that of
NEGIS-v1, and replaces the others where they overlap. The parameters are in
`basins.toml` ([basins.negis]).

The parameters give the best match of the v1 parts on GRL-16KM, among cut lines,
thresholds of the south part of 20-50 m/yr, and other splits (`06_negis.jl`):

| Part | Cells | v1 cells | IoU |
|---|---|---|---|
| centre | 82 | 94 | 0.80 |
| south | 101 | 96 | 0.86 |
| north | 58 | 58 | 1.00 |
| all | 241 | 248 | 0.90 |

The whole stream at 50 m/yr matches the single v1 NEGIS basin (basin 9 of
GRL-16KM_BASINS-nasa-negis.nc) with IoU 0.88. The v1 centre also has a few isolated
cells near Storstrommen, left out here. A cut at a surface elevation of 1450 m instead
of the line gives IoU 0.74 (centre) and 0.79 (south), and a cut at a distance along the
stream from the grounding line of 79N (200 km) 0.68 and 0.63. The Mouginot basins of
79N, Zachariae Isstrom and Storstrommen are far broader than the stream (IoU 0.23).

## Precision

Region codes, zones and basins are integers and exact. `dist_shelfbreak` (km) is rounded
on output to 3 significant digits (see [Precision and file
sizes](https://fesmc.github.io/FesmData/precision.html)); the intermediate files on
the base grid (steps 1-3) are not rounded.

## Sources and licences

| Source | Licence |
|---|---|
| Marine Regions: EEZ-land union v4, IHO Sea Areas v3, Global Oceans and Seas v1 (Flanders Marine Institute) | CC BY 4.0 |
| HydroBASINS v1c (Lehner and Grill, 2013) | HydroSHEDS licence: free use with attribution |
| ISO 3166 countries with UN M49 regions | See the repository |
| Mouginot and Rignot (2019), Dryad | CC0 1.0 (Dryad) |
| NSIDC-0709 v2 (Mouginot et al., 2017) and NSIDC-0670 v1 (Joughin et al., 2018) | NASA NSIDC DAAC: no restrictions on use (cite the data) |
| Zwally et al. (2012) | No licence stated (GSFC web page) |
| Schmidt et al. (2025), Zenodo | See the data record |
| NEGIS-v1 (Ilaria Tabone, 2024) | Kept in the repository (`sources/negis_v1_GRL-16KM.csv`) |

References:

- Franke, S., Bons, P. D., Westhoff, J., et al. (2022). Holocene ice-stream shutdown and
  drainage basin reconfiguration in northeast Greenland. Nature Geoscience, 15,
  995-1001. doi:10.1038/s41561-022-01082-2
- Flanders Marine Institute (2024). Union of the ESRI Country shapefile and the
  Exclusive Economic Zones (version 4). doi:10.14284/698
- Flanders Marine Institute (2018). IHO Sea Areas, version 3. doi:10.14284/323
- Flanders Marine Institute (2021). Global Oceans and Seas, version 1. doi:10.14284/542
- Joughin, I., Smith, B. E. and Howat, I. M. (2018). A complete map of Greenland ice
  velocity derived from satellite data collected over 20 years. Journal of Glaciology,
  64(243), 1-11. doi:10.1017/jog.2017.73 (MEaSUREs Multi-year Greenland Ice Sheet
  Velocity Mosaic, Version 1, NSIDC-0670, doi:10.5067/QUA5Q9SVMSJG)
- Lehner, B. and Grill, G. (2013). Global river hydrography and network routing:
  baseline data and new approaches to study the world's large river systems.
  Hydrological Processes, 27(15), 2171-2186 (HydroBASINS v1c).
- ISO 3166 countries with UN M49 regions:
  github.com/lukes/ISO-3166-Countries-with-Regional-Codes
- Mouginot, J. and Rignot, E. (2019). Glacier catchments/basins for the Greenland Ice
  Sheet. Dryad. doi:10.7280/D1WT11
- Mouginot, J., Scheuchl, B. and Rignot, E. (2017). MEaSUREs Antarctic Boundaries for
  IPY 2007-2009 from Satellite Radar, Version 2. NSIDC. doi:10.5067/AXE4121732AD
- Schmidt, G. A., Mankoff, K. D., Bamber, J. L., et al. (2025). Datasets and protocols
  for including anomalous freshwater from melting ice sheets in climate simulations.
  Geoscientific Model Development, 18, 8333-8361. doi:10.5194/gmd-18-8333-2025 (data:
  doi:10.5281/zenodo.17386710)
- Zwally, H. J., Giovinetto, M. B., Beckley, M. A. and Saba, J. L. (2012). Antarctic
  and Greenland Drainage Systems. GSFC Cryospheric Sciences Laboratory.

## Making the dataset

The machine environment is set up as described under
[Machines and storage](https://fesmc.github.io/FesmData/machines.html).

### Layout

| Location | Contents |
|---|---|
| `$FESMDATA_SOURCES` | Original datasets (see `../datamanifest.toml`) |
| `$FESMDATA_PRODUCTS/<Domain>/<GRID>/` | Output: `<GRID>_REGIONS.nc`, `<GRID>_BASINS-<set>.nc` |
| `$FESMDATA_WORK/regions/` | Intermediate files (base grids) and check plots |

### Steps

All commands are run from the FesmData root after sourcing the machine environment.
Each step can be submitted as a job on a Levante compute node:

```bash
sbatch --job-name=<name> Regions/jobs/run_step.sbatch <script> <args...>
```

and `Regions/jobs/submit_domain.sh DOMAIN [FIRST_STEP]` submits steps 1-5 as a chain
of jobs. The topography product of the domain (Topo, step 3) is needed from step 2.

#### 0. Original datasets

The datasets are listed and downloaded with the Topo script (on a login node):

```bash
julia --project=Topo Topo/scripts/00_sources.jl --download
```

The Marine Regions layers (EEZ-land union v4, IHO Sea Areas v3, GOaS v1) are fetched
from its WFS server, HydroBASINS, the Zwally drainage systems and the ISO 3166/M49
table directly. Two need a manual download into the folder printed by the script:

- **Mouginot & Rignot (2019)** basins: the `Greenland_Basins_PS_v1.4.2.*` files from
  [Dryad](https://doi.org/10.7280/D1WT11).
- **NSIDC-0709 v2** (NASA Earthdata login, see
  [Topo](https://fesmc.github.io/FesmData/datasets/topo.html#original-datasets)): the `.shp`, `.shx`, `.dbf` and
  `.prj` files of `Basins_IMBIE_Antarctica_v02` and `Basins_Antarctica_v02`, from the
  `uri` in `../datamanifest.toml`.
- **NSIDC-0670 v1** (NASA Earthdata login): `greenland_vel_mosaic250_vx_v1.tif` and
  `greenland_vel_mosaic250_vy_v1.tif` (NEGIS), from the `uri` in `../datamanifest.toml`.

#### 1. Regions

```bash
sbatch --job-name=regions-NH Regions/jobs/run_step.sbatch 01_regions.jl NH
```

Writes `region_1`-`region_3` on the base grid. The job log lists the cells of each
region, and the cells that were filled with the nearest region.

#### 2. Zones

```bash
sbatch --job-name=zone-NH Regions/jobs/run_step.sbatch 02_zone.jl NH
```

#### 3. Basins

```bash
sbatch --job-name=basins-ANT Regions/jobs/run_step.sbatch 03_basins.jl ANT [SET]
```

NEGIS reads the grounded ice of the topography of the zones (step 2).

#### 4. All grids

```bash
sbatch --job-name=grids-all-NH Regions/jobs/run_step.sbatch 04_grids.jl NH [SET]
```

With SET, only the files of that basin set are written.

#### 5. Checks

```bash
sbatch --job-name=plots-NH Regions/jobs/run_step.sbatch 05_plots.jl NH [GRID]
```

Writes maps of the regions, zones and basins to `$FESMDATA_WORK/regions/plots/`.

The NEGIS sets are checked against v1 on GRL-16KM (cells and IoU of each part, and a
map, `$FESMDATA_WORK/regions/plots/GRL-16KM_negis.png`):

```bash
sbatch --job-name=negis Regions/jobs/run_step.sbatch 06_negis.jl \
    /work/ba1442/ice_data/Greenland/GRL-16KM/GRL-16KM_BASINS-nasa-negis-three.nc
```

The v1 file is optional; with it, the script checks that NEGIS-v1 reproduces it.

### Adding a region, a basin set or a domain

**A region** is an entry of `regions.toml`, with its path, name and rules:

```toml
[[region]]
path = "1.2.3"
name = "Svalbard"
rules = [{ source = "eez_land", field = "territory1", values = ["Svalbard"] }]
```

A region covers the union of its rules, within its parent; siblings are applied in the
order of the file, so a cell taken by an earlier sibling stays with it. Cells of a
region that none of its subregions covers keep the code of the region, unless its
subregions enclose them. A rule selects features of a polygon source (`eez_land`,
`iho`, `goas`, `hydrobasins`, `imbie`) by the `values` of a `field`, or a lon/lat
`box`, and can be limited `within` or `without` other rules (see the header of
`regions.toml`). A region with `fill = true` gives its
cells outside all its subregions to the nearest subregion. Ocean regions are numbered
from 51. Changing the tree changes the codes of all domains, so it is a new release of
Regions; then run steps 1 and 4 (and 5) for every domain.

**A basin set** is an entry of `basins.toml`: its name, domains, the region it is
extended in (up to the shelf break), its polygon source, and the attribute identifying
the basins (`id_field`), optionally a grouping (`group_field`), selected `features`, or
basins that are not extended (`no_extension`); see the header of `basins.toml`. Then
run steps 3-5 for its domains (`03_basins.jl <DOMAIN> <SET>`, `04_grids.jl <DOMAIN>
<SET>`). Its files are released with the next release of Regions.

**A polygon source** is an entry of `../datamanifest.toml` (with its DOI), a branch in
`_read_source` and in `manifest_keys` in `sources.jl` (the polygons in lon/lat as
`Shape`s, with their attributes).

**A domain**: define it in `../shared/domains.toml` (see
[Overview and code](https://fesmc.github.io/FesmData/developers.html#domains)), make its
topography (Topo), and add the topography product of its zones to `[zone] products` in
`regions.toml` (and its shelf-break depth `z_break` if its region needs another one).
Add it to the `domains` of its basin sets, if any, and run all steps
(`jobs/submit_domain.sh <DOMAIN>`). The region tree is global, so a new domain needs no
new regions.

