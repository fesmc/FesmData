# GLAC-1D: ice sheets of the last glacial cycle (Tarasov et al., 2012)

The GLAC-1D ice-sheet reconstruction of L. Tarasov, from glaciological models calibrated
against paleo data (relative sea level, ice margins, present-day uplift):

- North America: Tarasov, L., Dyke, A. S., Neal, R. M. and Peltier, W. R.: A
  data-calibrated distribution of deglacial chronologies for the North American ice
  complex from glaciological modeling, Earth Planet. Sci. Lett., 315-316, 30-40, 2012,
  [doi:10.1016/j.epsl.2011.09.010](https://doi.org/10.1016/j.epsl.2011.09.010);
- Greenland: Tarasov, L. and Peltier, W. R.: Greenland glacial history and local
  geodynamic consequences, Geophys. J. Int., 150, 198-229, 2002,
  [doi:10.1046/j.1365-246X.2002.01702.x](https://doi.org/10.1046/j.1365-246X.2002.01702.x);
- Antarctica: Briggs, R. D., Pollard, D. and Tarasov, L.: A data-constrained large
  ensemble analysis of Antarctic evolution since the Eemian, Quat. Sci. Rev., 103,
  91-115, 2014, [doi:10.1016/j.quascirev.2014.09.003](https://doi.org/10.1016/j.quascirev.2014.09.003);
- Eurasia (PMIP4 files only): Tarasov, L., Hughes, A., Gyllencreutz, R., Lohne, O. S.,
  Mangerud, J. and Svendsen, J.-I.: The global GLAC-1c deglaciation chronology, meltwater
  pulse 1-a, and a question of missing ice, IGS Symposium on Contribution of Glaciers and
  Ice Sheets to Sea-Level Change, 2014.

The PMIP4 page also asks to cite Abe-Ouchi et al. (2013),
[doi:10.1038/nature12374](https://doi.org/10.1038/nature12374). GLAC-1D is one of the two
ice-sheet boundary conditions of the PMIP4 last glacial maximum and last deglaciation
experiments (Ivanovic et al., 2016,
[doi:10.5194/gmd-9-2563-2016](https://doi.org/10.5194/gmd-9-2563-2016)).

Tarasov notes that before the LGM the chronologies are hardly constrained (Greenland,
Antarctica) or not at all (North America), apart from the self-consistency of the
model, and that the Greenland component (GrB) is outdated.

## Licence

None stated by the providers; users are asked to cite the references above. As for the
other sources without a licence, we assume that products derived from them may be
redistributed with these citations.

## Original data

Entries of `../datamanifest.toml`, downloaded by `prepare.jl` (no login):

- `glac1d_tarasov`: the regional files of the data page of L. Tarasov,
  <https://www.physics.mun.ca/~lev/dataAccess.html> (the server does not send its
  intermediate TLS certificate, see `datamanifest.toml`), `GLAC1D<variant><region>120kto30k.nc`
  (every 1 kyr) and `...30kto0k.nc` (every 100 years), time in kyr (negative before
  present), on 1° x 0.5° grids: North America + Greenland (lon 169.5°W to 11.5°W, lat
  36.25°N to 84.75°N), variants `nn9927NAGrB` (better fit to the constraints, less ice at
  the LGM; `HICE`, ice thickness, and `DWATER`, lake water thickness) and `nn9894NAGrB`
  (more ice at the LGM; `HICE`), and Antarctica `nn4041ANT` (south of 59°S, `HICE`). The
  ice thickness includes the ice shelves.
- `glac1d_pmip4_topo`, `glac1d_pmip4_hice`: the global GLAC-1D files of PMIP4 (NA nn9894,
  Greenland GrB, Antarctica nn4041 and Eurasia),
  <https://pmip4.lsce.ipsl.fr/doku.php/data:ice_glac_1d>, from its public share,
  26-0 ka every 100 years: `TOPicemsk.GLACD26kN9894GE90227A6005GGrBgic.nc` (812 MB,
  1° x 0.5°; `HDC`, elevation relative to the sea level of the time, the surface of land
  and ice including ice shelves, and the sea floor in the open ocean; `HDCB`, the same
  but the base of the floating ice under ice shelves; `ICEM`, ice fraction) and
  `GLAC1DHiceF26.nc` (57 MB, 0.5° x 0.25°; `HGLOBH`, ice thickness).

`HGLOBH` has thin ice (up to about 85 m) over Siberia and Alaska, about the same at
all times (e.g. 21 ka and 0 ka), where `ICEM` is 0; it is kept as it is.

The PMIP4 page also has `TopoIcem-140-122k.nc`, which is not GLAC-1D but a sample of the
penultimate deglaciation (GLAC2-1E / Abe-Ouchi), and is not used.

## Prepare and remap

```bash
julia --project=Tarasov2012_glac1d Tarasov2012_glac1d/prepare.jl
julia fesmdata.jl remap IceHistory GLAC1D GLAC1D_nn9927 GLAC1D_nn9894
```

`prepare.jl` writes to `$FESMDATA_PREPARED/Tarasov2012_glac1d/` (see `Remap/README.md`),
each on the grid of its source with longitudes in -180:180 and the dimension `time`
(years ago, before 1950 CE, oldest first):

- `Tarasov2012_GLAC1D_NA_nn9927.nc`: `H_ice` (m, ice thickness, grounded and floating)
  and `H_lake` (m, lake water thickness) of North America + Greenland, 120-0 ka (391
  steps: every 1 kyr to 30 ka, then every 100 years; the step at 30 ka, in both files,
  is identical in both);
- `Tarasov2012_GLAC1D_NA_nn9894.nc`: `H_ice` of North America + Greenland, 120-0 ka;
- `Tarasov2012_GLAC1D_ANT_nn4041.nc`: `H_ice` of Antarctica, 120-0 ka;
- `Tarasov2012_GLAC1D_PMIP4_topo.nc`: `z_topo` (m, `HDCB`), `z_srf` (m, `HDC`) and
  `f_ice` (1, `ICEM`), global, 26-0 ka every 100 years;
- `Tarasov2012_GLAC1D_PMIP4_ice.nc`: `H_ice` (m, `HGLOBH`), global, 26-0 ka every 100
  years.

The products of `IceHistory/remap.toml` combine them: `GLAC1D` (the two PMIP4 files),
`GLAC1D_nn9927` and `GLAC1D_nn9894` (North America + Greenland of the variant with
Antarctica). The regional products cover only North America, Greenland and Antarctica:
`f_valid` is 0 elsewhere (Eurasia is not in the regional files).
