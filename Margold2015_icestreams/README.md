# Ice streams of the Laurentide Ice Sheet (Margold et al., 2015; Stokes et al., 2016)

Outlines of the ice streams of the Laurentide Ice Sheet mapped from their geomorphological
imprint:

Margold, M., Stokes, C. R., Clark, C. D. and Kleman, J.: Ice streams in the Laurentide Ice
Sheet: a new mapping inventory, J. Maps, 11, 380-395, 2015,
[doi:10.1080/17445647.2014.912036](https://doi.org/10.1080/17445647.2014.912036).

with the timing of their activity during the deglaciation, from the source data of Fig. 1
and 2 of

Stokes, C. R., Margold, M., Clark, C. D. and Tarasov, L.: Ice stream activity scaled to ice
sheet volume during Laurentide Ice Sheet deglaciation, Nature, 530, 322-326, 2016,
[doi:10.1038/nature16947](https://doi.org/10.1038/nature16947) (see `../Stokes2016_icestreams/`).

## Licence

The shapefiles are a supplement of the article (open access), published on figshare under
CC BY 4.0 ([doi:10.6084/m9.figshare.1033955.v3](https://doi.org/10.6084/m9.figshare.1033955.v3)).
The ages are from the source data of a Nature article (Springer Nature terms, no open
licence stated); we assume that derived products may be published with a citation.

## Original data

`IS shp.zip` (300 kB, no login) from figshare, <https://ndownloader.figshare.com/files/1507383>
(linked from the figure page of the article at Taylor & Francis),
`margold2015_icestreams` in `datamanifest.toml`: `IS_polygons.shp` (130 polygons, field
`Stable_ID`, the number of the ice stream; Lambert conformal conic, NAD83) is used, not
`IS_flowline.shp`. The ages are read from
`../Stokes2016_icestreams/41586_2016_BFnature16947_MOESM67_ESM.xlsx`.

## Prepare and remap

```bash
julia -t 8 --project=Margold2015_icestreams Margold2015_icestreams/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Margold2015_icestreams/Margold2015_ICESTREAMS.nc Laurentide North --name=IceHistory-Margold2015
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Margold2015_icestreams/Margold2015_ICESTREAMS.nc`
(see `Remap/README.md`) on a 1 km grid on the polar stereographic projection of the North
domain, covering all its grids (x -4917 to 3901 km, y -5417 to 3401 km), with

- `f_stream` (1): area fraction of the mapped ice streams (all 130 polygons);
- `f_stream_lgm` (1): area fraction of the ice streams active at the LGM: those whose
  best-estimate start is 21.8 ka, the start of the chronology of Stokes et al. (2016)
  (50 streams, 57 polygons);
- `age_stream_start`, `age_stream_end` (years ago, before 1950 CE): best-estimate start and
  end of the activity of the ice streams covering each cell (cal ka BP in the source);
  where streams overlap, the oldest start and the youngest end. Missing outside dated
  streams.

The fractions are from 4 x 4 samples per cell (250 m); the ages are given to every cell
that a stream touches. The fractions are 0 outside the mapped streams, also outside the
Laurentide Ice Sheet, which the inventory does not cover.

Notes on the ages (sheet `Fig. 1 & 2`, columns ID, best-estimate start and end):

- The 130 polygons are 116 ice streams, all in the table. 125 polygons have ages; the 5
  polygons of the streams dated only as "pre-LGM" or "pre-OIS 2" (IDs 135, 150, 157, 162)
  have none.
- Two streams have two phases of activity (23, Cumberland Sound; 117, Frobisher Bay): they
  get the start of the first and the end of the last.
- The list of LGM streams of v1 (`lgm_ice_streams_Stokes2016.txt`, written by hand) differs
  from the rule above by 5 streams: it includes 14, 15 and 151 (best-estimate start
  20.5 ka) and leaves out 23 and 108 (start 21.8 ka).

The v1 files (`ISshp/`, a copy of the shapefiles; `map_icestreams.jl` and its 10 km and
LIS-16KM masks; the LGM list) are replaced by `prepare.jl` and remapping.
