# Laurentide and Innuitian ice sheets before the LGM, 115-25 ka (Dalton et al., 2022)

The extent of the Laurentide and Innuitian ice sheets every 5000 years from 115 to 25 ka,
as a best estimate with a minimum and a maximum, reconstructed from a compilation of
geochronological data (735 ages) and stratigraphic records, informed qualitatively by
numerical ice-sheet modelling, insolation and estimates of global mean sea level (Pico et
al., 2017; Spratt and Lisiecki, 2016). Each slice carries a confidence (low, medium, high) in
the article. The Cordilleran ice is that of Batchelor et al. (2019), shown for completeness:

Dalton, A. S., Stokes, C. R. and Batchelor, C. L.: Evolution of the Laurentide and Innuitian
ice sheets prior to the Last Glacial Maximum (115 ka to 25 ka), Earth-Sci. Rev., 224,
103875, 2022, [doi:10.1016/j.earscirev.2021.103875](https://doi.org/10.1016/j.earscirev.2021.103875).

## Licence

The article is open access under CC BY 4.0. No licence is stated for the supplementary
data; we assume, as for Batchelor et al. (2019), that derived products may be published
with a citation of the article.

## Original data

The supplementary data of the article (Elsevier, `1-s2.0-S0012825221003767-mmc3.zip`, 62
MB, no login), `dalton2022_prelgm` in `datamanifest.toml`:
`<age>ka_{BEST,MIN,MAX}_North_American_ice_Dalton_et_al_ESR.shp` for the 19 slices, 115 to
25 ka. The slices 115-30 ka are on a north polar Lambert azimuthal equal-area projection,
25 ka in longitude-latitude (WGS84); all polygons are ice (attribute `Area_Km2` or
`AreaKm2`). The other supplementary files are the maps (mmc1, PDF) and the dates (mmc2,
Excel).

## Prepare and remap

```bash
julia -t 16 --project=Dalton2022_preLGM Dalton2022_preLGM/prepare.jl
julia fesmdata.jl remap IceHistory Dalton2022
```

`prepare.jl` writes `$FESMDATA_PREPARED/Dalton2022_preLGM/Dalton2022_PRELGM.nc` (see
`Remap/README.md`) with `f_ice` (the best estimate), `f_ice_min` and `f_ice_max` (1), the
area fraction of each cell inside the extent, on (x, y, time).

- Grid: the 2 km grid of the North domain of `Batchelor2019_NHIceMasks`
  (`../shared/outlines.jl`), whose cell edges are on those of the North grids, so that
  remapping onto them is exact.
- Fractions: from 8 x 8 samples per cell (250 m); a polygon covers a sample if its centre
  is inside it (even-odd rule over the rings of each polygon, union of the polygons). The
  edges are densified (1 km, or 0.01° for the geographic 25 ka files) before projecting.
- Time: `time` in years ago (before 1950 CE; the ages of the slices), oldest first.
