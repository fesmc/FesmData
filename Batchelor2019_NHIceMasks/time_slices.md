# Batchelor et al. (2019) time slices: conversion to model years

The 18 ice-extent snapshots of Batchelor et al. (2019, *Nat. Commun.* 10, 3713,
[doi:10.1038/s41467-019-11601-2](https://doi.org/10.1038/s41467-019-11601-2))
are labelled by marine isotope stage (MIS), palaeomagnetic chron or a nominal
age. The paper and the dataset README give an age *range* for each stage but no
single representative age (except the LGM, "approximately 26.5 ka", and the
four MIS 3 slices). `Batchelor2019_ice_masks.nc` therefore carries an index
time axis (1–18).

For transient forcing a single age per slice is needed. The table below is the
assignment used by `build_lgc_dataset.jl`. Ages are in years relative to
present (negative = before present), the convention of the CLIMBER-X transient
forcing files (e.g. `geo_ice_tarasov_deglac.nc`).

Rule: full-glacial stages are placed at the approximate glacial maximum of the
stage (the reconstructions are maximum extents, drawn from "peak climatic
coldness" evidence); interstadials (MIS 5a, 5c, 45 ka) at the approximate
peak warmth, as the paper states the reconstructions target; long stages
without a well-defined peak at the midpoint of the paper's range.

| # | Label | Paper age / range | Character (paper) | Assigned age | `time` [yr] | Rationale |
|---|---|---|---|---|---|---|
| 1 | Early Matuyama Chron | 1.78–2.6 Ma | onset of NH glaciation ~2.4–2.5 Ma | 2.2 Ma | -2200000 | midpoint of chron |
| 2 | Late Gauss Chron | 2.6–3.6 Ma | includes onset ~2.6–2.7 Ma | 3.1 Ma | -3100000 | midpoint of chron |
| 3 | MIS 20–24 | 790–928 ka | combined full-glacial | 860 ka | -860000 | midpoint |
| 4 | MIS 16 | 622–677 ka | full-glacial | 650 ka | -650000 | glacial maximum (~630–650 ka) |
| 5 | MIS 12 | 429–477 ka | full-glacial | 440 ka | -440000 | glacial maximum (~435–450 ka) |
| 6 | MIS 10 | 337–365 ka | full-glacial | 350 ka | -350000 | midpoint / maximum |
| 7 | MIS 8 | 243–279 ka | full-glacial | 260 ka | -260000 | glacial maximum (~250–270 ka) |
| 8 | MIS 6 | 132–190 ka | full-glacial (penultimate glacial maximum) | 140 ka | -140000 | PGM ~140–150 ka |
| 9 | MIS 5d | 108–117 ka | glacial substage | 112 ka | -112000 | peak of 5d |
| 10 | MIS 5c | 92–108 ka | interstadial, peak warmth | 100 ka | -100000 | peak of 5c |
| 11 | MIS 5b | 86–92 ka | glacial substage | 88 ka | -88000 | peak of 5b |
| 12 | MIS 5a | 72–86 ka | interstadial, peak warmth | 80 ka | -80000 | peak of 5a |
| 13 | MIS 4 | 58–72 ka | full-glacial | 65 ka | -65000 | peak of MIS 4 |
| 14 | 45 ka | 45 ka | interstadial, peak warmth | 45 ka | -45000 | as labelled |
| 15 | 40 ka | 40 ka | MIS 3 build-up | 40 ka | -40000 | as labelled |
| 16 | 35 ka | 35 ka | MIS 3 build-up | 35 ka | -35000 | as labelled |
| 17 | 30 ka | 30 ka | MIS 3 build-up | 30 ka | -30000 | as labelled |
| 18 | LGM | ~26.5 ka | maximum extent, mainly after Ehlers et al. (2011) | 26.5 ka | -26500 | as stated in the paper |

The numbering is the slice order in `Batchelor2019_ice_masks.nc` (the paper
lists them youngest first). It is oldest-first except for the first two: the
Early Matuyama slice (younger) precedes the Late Gauss slice (older), so the
assigned ages are not monotonic over the full file. They are monotonic from
slice 3 onward, and in particular over the last-glacial-cycle subset.

## Last glacial cycle file (`_lgc`)

`build_lgc_dataset.jl` writes `Batchelor2019_ice_masks_lgc.nc` with slices 8–18
(MIS 6 to LGM) on the `time` axis above, plus the LGM slice **repeated at
-21000 yr**. The LGM reconstruction is a maximum extent reached at different
times in different sectors within roughly 26–19 ka, so holding it from 26.5 ka
to 21 ka (the PMIP LGM date) is a fairer representation than a single instant,
and it gives a clean anchor for appending a deglacial dataset later. A model
interpolating linearly between slices thus sees the full LGM extent throughout
26.5–21 ka; before -140000 and after -21000 the extent is clamped to the first
and last slice respectively.

The file is used by CLIMBER-X as the target extent of the synthetic ice-sheet
geometry (`ice_syn_par.nml`, `mask_file`). It does **not** contain the
deglaciation or the present day; for a run past 21 ka a deglacial
reconstruction (e.g. GLAC-1D thickness thresholded via `var_thresh`) has to be
used instead.
