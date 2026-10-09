# Regions: region masks, zones and basins (v2)

Masks of geographic regions, of present-day land, continental shelf and open ocean,
and of ice-sheet drainage basins, for each model domain on all its grids
(`../shared/domains.toml`, as for the topography v2 pipeline in `../Topo`).

- **Regions** are a tree defined once, globally, in `regions.toml`, from standard
  datasets (countries and EEZs, IHO seas, oceans, HydroBASINS, IMBIE basins), so the
  same region has the same code in every domain. Each level of the tree covers the
  globe without gaps or overlaps.
- **Zones** separate present-day land, the continental shelf (up to the shelf break)
  and the open ocean, from the bed elevation of the topography product.
- **Basins** (`basins.toml`) are the drainage basins of the ice sheets, extended over
  the land and shelf of their region up to the shelf break.

Everything is computed on the base grid of a domain (ANT-1KM, GRL-PAL-500M, NH-2KM,
PYR-500M, SRG-250M) and then mapped onto all other grids and crops, as for the
topography.

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
  and Iceland come first; oceans (GOaS) take the rest.
- Russia is split between Western Eurasia and Asia at the divide between the
  rivers draining to the Kara and Laptev seas (HydroBASINS), and at sea at the
  boundary between the Kara and Laptev seas (IHO).
- The NA subregions follow HydroBASINS and IHO seas; Hudson Bay and Strait include
  only the coastal basins draining into them, not the large rivers.
- The Antarctic subregions are the IMBIE regions, extended to fill all of 2.1.

The mountain domains lie within single regions of level 2: PYR in 1.2 Western
Eurasia (land and EEZs of Spain, France and Andorra) and 1.52 North Atlantic Ocean
(beyond the EEZs, if any), SRG in 2.2 Latin America and the Caribbean.

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
domain (the mountain domains PYR and SRG), has only land and shelf, and
`dist_shelfbreak` is -Inf everywhere (as noted in the `comment` attribute of the
variable).

## Basins

| Set | Domains | Source |
|---|---|---|
| Mouginot2019 | GRL-PAL, NH | Greenland glacier basins, 260 basins in 7 regions (Mouginot & Rignot, 2019) |
| Zwally2012 | GRL-PAL, NH; ANT | GSFC drainage systems (Zwally et al., 2012); Greenland sub-systems 11 = 1.1 |
| IMBIE2016, IMBIE2016-refined | ANT | IMBIE 2016 and refined basins (Mouginot et al., 2017, NSIDC-0709 v2) |
| SanRafael | SRG | San Rafael Glacier (RGI2000-v7.0-G-17-12835), its RGI 7.0 outline as the footprint of its IceBoost v2 tile |

Each file has `basin`, `basin_mask` (1 within the original basins) and, for sets
with groups (e.g. Mouginot regions, IMBIE regions, Zwally systems), `basin_group`. The
islands in the ice shelves of IMBIE2016-refined keep their extent but are not
extended, so the ice shelves around them go to the neighbouring grounded basins.

SanRafael is a single basin (1), the cells at least half covered by the glacier, not
extended: the part of the SRG domain that evolves freely in yelmox, while the rest
relaxes to the present-day state (in v1, `regions = 1` of SRG-250M_REGIONS.nc). PYR
has no basins.

## Layout

| Location | Contents |
|---|---|
| `$DATAMANIFEST_DATASETS_DIR` | Original datasets (see `../datamanifest.toml`) |
| `$ICE_DATA/v2/<Domain>/<GRID>/` | Output: `<GRID>_REGIONS.nc`, `<GRID>_BASINS-<set>.nc` |
| `$FESMDATA_WORK/regions/` | Intermediate files (base grids) and check plots |

The machine environments are in `../shared/machines`, and the Julia setup is that of
`../Topo` (see its README).
Install the packages once (on Levante on a login node):

```bash
source shared/machines/levante.env
julia --project=Regions -e 'using Pkg; Pkg.instantiate()'
```

## Steps

All commands are run from the FesmData root after sourcing the machine environment.
Each step can be submitted as a job on a Levante compute node:

```bash
sbatch --job-name=<name> Regions/jobs/run_step.sbatch <script> <args...>
```

and `Regions/jobs/submit_domain.sh DOMAIN [FIRST_STEP]` submits steps 1-5 as a chain
of jobs. The topography product of the domain (Topo, step 3) is needed from step 2.

### 0. Original datasets

The datasets are listed and downloaded with the Topo script (on a login node):

```bash
julia --project=Topo Topo/scripts/00_sources.jl --download
```

The Marine Regions layers (EEZ-land union v4, IHO Sea Areas v3, GOaS v1) are fetched
from its WFS server, HydroBASINS, the Zwally drainage systems and the ISO 3166/M49
table directly. Two need a manual download into the folder printed by the script:

- **Mouginot & Rignot (2019)** basins: the `Greenland_Basins_PS_v1.4.2.*` files from
  [Dryad](https://doi.org/10.7280/D1WT11).
- **NSIDC-0709 v2** (NASA Earthdata login, see Topo): the `.shp`, `.shx`, `.dbf` and
  `.prj` files of `Basins_IMBIE_Antarctica_v02` and `Basins_Antarctica_v02`, from the
  `uri` in `../datamanifest.toml`.

### 1. Regions

```bash
sbatch --job-name=regions-NH Regions/jobs/run_step.sbatch 01_regions.jl NH
```

Writes `region_1`-`region_3` on the base grid. The job log lists the cells of each
region, and the cells that were filled with the nearest region.

### 2. Zones

```bash
sbatch --job-name=zone-NH Regions/jobs/run_step.sbatch 02_zone.jl NH
```

### 3. Basins

```bash
sbatch --job-name=basins-ANT Regions/jobs/run_step.sbatch 03_basins.jl ANT [SET]
```

### 4. All grids

```bash
sbatch --job-name=grids-all-NH Regions/jobs/run_step.sbatch 04_grids.jl NH
```

Region codes, zones and basins on each grid are the class covering most of a cell,
nested level by level (a cell's `region_3` lies within its `region_2`; basins within
their group). `dist_shelfbreak` is the cell mean.

### 5. Checks

```bash
sbatch --job-name=plots-NH Regions/jobs/run_step.sbatch 05_plots.jl NH [GRID]
```

Writes maps of the regions, zones and basins to `$FESMDATA_WORK/regions/plots/`.

## Sources

- Flanders Marine Institute (2024). Union of the ESRI Country shapefile and the
  Exclusive Economic Zones (version 4). doi:10.14284/698
- Flanders Marine Institute (2018). IHO Sea Areas, version 3. doi:10.14284/323
- Flanders Marine Institute (2021). Global Oceans and Seas, version 1. doi:10.14284/542
- Lehner, B. and Grill, G. (2013). Global river hydrography and network routing:
  baseline data and new approaches to study the world's large river systems.
  Hydrological Processes, 27(15), 2171-2186 (HydroBASINS v1c).
- ISO 3166 countries with UN M49 regions:
  github.com/lukes/ISO-3166-Countries-with-Regional-Codes
- Mouginot, J. and Rignot, E. (2019). Glacier catchments/basins for the Greenland Ice
  Sheet. Dryad. doi:10.7280/D1WT11
- Mouginot, J., Scheuchl, B. and Rignot, E. (2017). MEaSUREs Antarctic Boundaries for
  IPY 2007-2009 from Satellite Radar, Version 2. NSIDC. doi:10.5067/AXE4121732AD
- Zwally, H. J., Giovinetto, M. B., Beckley, M. A. and Saba, J. L. (2012). Antarctic
  and Greenland Drainage Systems. GSFC Cryospheric Sciences Laboratory.
