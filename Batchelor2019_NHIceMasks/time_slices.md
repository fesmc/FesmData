# Batchelor et al. (2019) time slices: assigned ages

The 18 ice-extent snapshots of Batchelor et al. (2019, *Nat. Commun.* 10, 3713,
[doi:10.1038/s41467-019-11601-2](https://doi.org/10.1038/s41467-019-11601-2))
are labelled by marine isotope stage (MIS), palaeomagnetic chron or a nominal
age. The paper and the dataset README give an age *range* for each stage but no
single representative age (except the LGM, "approximately 26.5 ka", and the
four MIS 3 slices).

For a time axis a single age per slice is needed. The table below is the
assignment used by `prepare.jl` (the `time` of the prepared file, in years ago,
before 1950 CE) and by `../Batchelor2019_PaleoMIST_lgc/prepare.jl`.

Rule: full-glacial stages are placed at the approximate glacial maximum of the
stage (the reconstructions are maximum extents, drawn from "peak climatic
coldness" evidence); interstadials (MIS 5a, 5c, 45 ka) at the approximate
peak warmth, as the paper states the reconstructions target; long stages
without a well-defined peak at the midpoint of the paper's range.

| # | Label | Paper age / range | Character (paper) | Assigned age | `time` [years ago] | Rationale |
|---|---|---|---|---|---|---|
| 1 | Early Matuyama Chron | 1.78–2.6 Ma | onset of NH glaciation ~2.4–2.5 Ma | 2.2 Ma | 2200000 | midpoint of chron |
| 2 | Late Gauss Chron | 2.6–3.6 Ma | includes onset ~2.6–2.7 Ma | 3.1 Ma | 3100000 | midpoint of chron |
| 3 | MIS 20–24 | 790–928 ka | combined full-glacial | 860 ka | 860000 | midpoint |
| 4 | MIS 16 | 622–677 ka | full-glacial | 650 ka | 650000 | glacial maximum (~630–650 ka) |
| 5 | MIS 12 | 429–477 ka | full-glacial | 440 ka | 440000 | glacial maximum (~435–450 ka) |
| 6 | MIS 10 | 337–365 ka | full-glacial | 350 ka | 350000 | midpoint / maximum |
| 7 | MIS 8 | 243–279 ka | full-glacial | 260 ka | 260000 | glacial maximum (~250–270 ka) |
| 8 | MIS 6 | 132–190 ka | full-glacial (penultimate glacial maximum) | 140 ka | 140000 | PGM ~140–150 ka |
| 9 | MIS 5d | 108–117 ka | glacial substage | 112 ka | 112000 | peak of 5d |
| 10 | MIS 5c | 92–108 ka | interstadial, peak warmth | 100 ka | 100000 | peak of 5c |
| 11 | MIS 5b | 86–92 ka | glacial substage | 88 ka | 88000 | peak of 5b |
| 12 | MIS 5a | 72–86 ka | interstadial, peak warmth | 80 ka | 80000 | peak of 5a |
| 13 | MIS 4 | 58–72 ka | full-glacial | 65 ka | 65000 | peak of MIS 4 |
| 14 | 45 ka | 45 ka | interstadial, peak warmth | 45 ka | 45000 | as labelled |
| 15 | 40 ka | 40 ka | MIS 3 build-up | 40 ka | 40000 | as labelled |
| 16 | 35 ka | 35 ka | MIS 3 build-up | 35 ka | 35000 | as labelled |
| 17 | 30 ka | 30 ka | MIS 3 build-up | 30 ka | 30000 | as labelled |
| 18 | LGM | ~26.5 ka | maximum extent, mainly after Ehlers et al. (2011) | 26.5 ka | 26500 | as stated in the paper |

The numbering is the slice order of the v1 file `Batchelor2019_ice_masks.nc`
(the paper lists them youngest first): oldest first except for the first two,
the Early Matuyama slice (younger) before the Late Gauss slice (older). The
prepared file of `prepare.jl` has the slices in the order of their age (Late
Gauss first), so that its time axis is monotonic.

## Last glacial cycle (`Batchelor2019_PaleoMIST_lgc`)

The hybrid masks of the last glacial cycle (`../Batchelor2019_PaleoMIST_lgc/`),
which replace the v1 `Batchelor2019_ice_masks_lgc.nc` (`build_lgc_dataset.jl`,
used by CLIMBER-X), have the slices from MIS 5a to the LGM at the ages above,
80000 to 26500 years ago, with the LGM **repeated at 21000 years ago**. The
LGM reconstruction is a maximum extent reached at different times in different
sectors within roughly 26–19 ka, so holding it from 26.5 ka to 21 ka (the PMIP
LGM date) is a fairer representation than a single instant, and it gives a
clean anchor for appending a deglacial dataset later. The v1 file started at
MIS 6 (140 ka); the older slices are left out of the hybrid, since PaleoMIST,
used in the Southern Hemisphere, starts at 80 ka.
