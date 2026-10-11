# Timing of the ice streams of the Laurentide Ice Sheet (Stokes et al., 2016)

Start and end of the activity of each ice stream of the inventory of Margold et al. (2015)
during the deglaciation of the Laurentide Ice Sheet (21.8 to 7 cal ka BP):

Stokes, C. R., Margold, M., Clark, C. D. and Tarasov, L.: Ice stream activity scaled to ice
sheet volume during Laurentide Ice Sheet deglaciation, Nature, 530, 322-326, 2016,
[doi:10.1038/nature16947](https://doi.org/10.1038/nature16947).

The ages are used with the outlines of Margold et al. (2015) in `../Margold2015_icestreams/`
(the ice streams active at the LGM, and the start and end of activity of each stream).

## Licence

Source data of a Nature article (Springer Nature terms, no open licence stated); we assume
that derived products may be published with a citation.

## Original data

The source data of the article (no login), kept in this folder:

- `41586_2016_BFnature16947_MOESM67_ESM.xlsx`: Fig. 1 and 2, the earliest, best-estimate
  and latest start and end of each ice stream (cal kyr BP), by ID (`Stable_ID` of
  Margold et al., 2015). Read by `../Margold2015_icestreams/prepare.jl`.
- `41586_2016_BFnature16947_MOESM69_ESM.xlsx`: the same table.
- `41586_2016_BFnature16947_MOESM71_ESM.xlsx`: Fig. 3 (number of ice streams, streaming
  width, ice sheet volume and discharge through time).

From <https://www.nature.com/articles/nature16947> (Source data), e.g.

```bash
wget https://static-content.springer.com/esm/art%3A10.1038%2Fnature16947/MediaObjects/41586_2016_BFnature16947_MOESM67_ESM.xlsx
```

The v1 list of the ice streams active at the LGM (`lgm_ice_streams.txt`, written by hand
from the table) is replaced by the rule in `../Margold2015_icestreams/README.md`.
