# Basal shear stress of PaleoMIST 1.0 (Gowan et al., 2021)

The basal shear stress with which ICESHEET 2.0 made the ice sheets of PaleoMIST 1.0
(perfectly plastic, |∇z_s| = τ_b / (ρ_i g H) along flowlines from the margins): domains
(polygons) and the value of each domain at each time slice (80-0 ka every 2.5 kyr), so
that a plastic ice sheet model can reproduce PaleoMIST with the margins of
`IceHistory-PaleoMIST`:

Gowan, E. J., Zhang, X., Khosravi, S., Rovere, A., Stocchi, P., Hughes, A. L. C.,
Gyllencreutz, R., Mangerud, J., Svendsen, J.-I. and Lohmann, G.: A new global ice sheet
reconstruction for the past 80 000 years, Nat. Commun., 12, 1199, 2021,
[doi:10.1038/s41467-021-21469-w](https://doi.org/10.1038/s41467-021-21469-w).

Gowan, E. J., Tregoning, P., Purcell, A., Lea, J., Fransner, O. J., Noormets, R. and
Dowdeswell, J. A.: ICESHEET 1.0: a program to produce paleo-ice sheet reconstructions
with minimal assumptions, Geosci. Model Dev., 9, 1673-1682, 2016,
[doi:10.5194/gmd-9-1673-2016](https://doi.org/10.5194/gmd-9-1673-2016).

## Licence

GPL-3.0-only: the domains and values are input files of ICESHEET 2.0
(<https://github.com/evangowan/icesheet>, E. J. Gowan, GNU General Public License v3),
and the prepared and remapped files (`IceHistory-PaleoMIST_taub`, released with
IceHistory) are derived from them under the same licence. Cite both papers.

## Original data

The GitHub archive of ICESHEET 2.0 at its last commit (641d172, 2022), no login,
`gowan2021_icesheet` in `datamanifest.toml` (pinned to that commit), in
`$FESMDATA_SOURCES/gowan2021_icesheet/icesheet-641d172230c76fc44ec9ea40ab1a0e9f76d0f42f/`,
downloaded and extracted by `prepare.jl` if missing, of which `global/<region>/shear_stress/` is
used, for North_America (with Greenland), Eurasia and Antarctica (Patagonia is left
out); and the 5 km regional reconstructions of PaleoMIST 1.0 (`gowan2021_paleomist`,
see `../Gowan2021_PaleoMIST1.0/`; `$FESMDATA_SOURCES/gowan2021_paleomist/`), for their
grids and ice. Per region:

- `shear_stress_domains.gmt` (Antarctica: `shear_stress_domains3.gmt`, as named in
  `projection_info.sh`): the domains, polygons in the GMT text format exported by QGIS,
  on the projection of the region with x and y from the projection centre (Lambert
  azimuthal equal-area at 60°N 94°W and at the North Pole; polar stereographic, true
  scale at 71°S), each with its domain number and a shear stress (Pa);
- `domains_max.txt`, `domains_min.txt`: `domain value` (Pa), the base and the minimum
  shear stress of the domains;
- `adjust_0.txt`: `domain t_max t_min ss_min`, the changes in time (years ago).

## The shear stress of PaleoMIST 1.0

`create_ss_grid` (ICESHEET 2.0, `create_ss_grid.f90`), called by
`global/<region>/shear_stress/create_bin_var.sh` (lines 82-92) for each time slice, with
the time in years ago (from `global/prepare_icesheet.sh`, lines 220-234, which copies the
domain file, `domains_max.txt`, `domains_min.txt` and the adjustment file of `run.sh`),
makes the shear stress grid of a time slice (line numbers of `create_ss_grid.f90`):

1. Each domain gets the shear stress of its polygon in the GMT file (lines 146-158; the
   last polygon of a domain wins), replaced by that of `domains_max.txt` (lines 213-227,
   always given): the base value, `taub` (= `taub_max`).
2. Its minimum is that of `domains_min.txt`, else 5000 Pa (lines 229-244): `taub_min`.
3. The lines of `adjust_0.txt`, in the order of the file, change the value of their
   domain at the times t with min(t_max, t_min) ≤ t ≤ max(t_max, t_min) (lines 247-300):
   for ss_min ≥ 0, linearly between (t_min, ss_min) and (t_max, current value), with
   ss_min = 0 meaning `taub_min`, rounded to whole Pa; for ss_min < 0, `taub_min`. A
   later line uses the value left by an earlier one. Outside these times the domain keeps
   its base value. So the shear stress depends on time: `taub_t`.
4. Each node of the 5 km grid of the region gets the value of the last polygon that
   contains it (even-odd rule, lines 332-388), 5000 Pa outside all polygons (line 330).

The published reconstruction used `adjust_0.txt` in all regions: in both MIS 3
scenarios of North America, the minimal one (runs 72-75 of ICESHEET, with the
deformation `icesheet_Evan_ehgr_71_67_64_65` of the PANGAEA archive) and the maximal one
(runs 82-85, `a1` margins); `adjust_a1.txt` and `adjust_a1_high_ss.txt` were tests (runs
77-78 and 86-87). This is in the git history of ICESHEET 2.0: `global/run.sh` at the
commits of these runs (a754a87: run 72, `adjust_0.txt` written into `run_parameters`;
5e64d18: run 82, `shear_adjustment="adjust_0.txt"`), and the shear stress files have not
changed since run 71 (3f9f86d). Gowan's plots of the shear stress of both scenarios
(`local_plots/` and `local_plots_a1/` of the PANGAEA archive) are the same, e.g. at
50 ka, where `adjust_a1.txt` would differ. How the values were chosen (Gowan et al., 2021, Methods):
domains from topography (higher in mountainous terrain) and surficial geology (lower on
continuous sediment, and for major ice streams), values tuned to the sea-level and GIA
data, raised to maximise the LGM ice volume and lowered during deglaciation; for
Greenland and Antarctica, first fitted to the present ice surface (Gowan et al., 2016),
with low values on the Antarctic shelf.

## Prepare and remap

```bash
julia --project=Gowan2021_PaleoMIST_taub Gowan2021_PaleoMIST_taub/prepare.jl
julia fesmdata.jl remap IceHistory PaleoMIST_taub
```

`prepare.jl` writes three files to `$FESMDATA_PREPARED/Gowan2021_PaleoMIST_taub/`
(see `Remap/README.md`), `Gowan2021_PaleoMIST_taub_<region>.nc` (NorthAmerica, Eurasia,
Antarctica), each on the 5 km grid of the region: the nodes of the shear stress grids of
ICESHEET, those of the regional reconstructions of PaleoMIST
(`ice_reconstruction_files/<region>/thickness/`), with x and y in km from the centre of
the projection, with

- `taub_domain`: the domain of each node as in step 4 (the polygons shifted from the
  projection centre to the corner of the grid, as `create_ss_grid` does); the domain ids
  are 1000 × region + the domain number of ICESHEET, region 1 North_America, 2 Eurasia,
  3 Antarctica. The nodes with ice in any time slice of the regional reconstruction but
  outside all polygons are in the domain 1000 × region (domain 0, 5000 Pa at all times,
  as in ICESHEET): mainly the eastern margin of the Eurasian ice sheet in MIS 4-3 (Kara
  Sea, 52.5-72.5 ka, about 10 400 nodes of 5 km), which the polygons do not reach. The
  other nodes within 150 km of that ice get the nearest domain (FesmUtils
  `extend_labels`, distance along the grid): the ice of `IceHistory-PaleoMIST` on the
  model grids reaches beyond the 5 km margins (the 25 km Gaussian filter of the 0.25°
  grids of the author, their cells, the smoothing of the remapping), and each of its
  cells needs a domain. Elsewhere `taub_domain` is missing;
- `taub_map` (Pa): the base value of the domain of each node;
- `mask_extended`: 1 where the domain is the nearest one (outside the polygons and the
  ice), 0 in the polygons and the ice, missing elsewhere;

and, in each file, all domains of the three regions (dimension `domain`, variables off
the grid): `domain_id`, `region`, `taub` and `taub_max` (Pa, the base value), `taub_min`
(Pa), and `taub_t` (Pa, on `time`, years ago before 1950 CE, 80000 to 0, oldest first, as
`IceHistory-PaleoMIST`), the value at each time slice (steps 1-3).

Remapping makes the product `IceHistory-PaleoMIST_taub` (`IceHistory/remap.toml`):
`taub_domain` is remapped as classes (the domain covering most of each cell) and
`taub_map` conservatively (the mean over the domains covering the cell), `mask_extended`
as classes. A model takes `taub_t` of the domain of each
cell at the time, or `taub_map` as a time-independent value.

Notes:

- `prepare.jl` logs per region the polygons, domains, nodes in overlapping polygons and
  the nodes with ice in any time slice of PaleoMIST outside all polygons. Gowan's plots of
  the shear stress (`local_plots/<region>/shear_stress/` of the PANGAEA archive) show the
  same: e.g. Eurasia at 55 ka, ice beyond the eastern domains at the lowest value.
- The projections are those of PROJ (as `../Gowan2021_PaleoMIST1.0/prepare.jl`);
  ICESHEET placed the margins with GMT, whose Lambert azimuthal projection may differ by
  a few km far from the centre.
