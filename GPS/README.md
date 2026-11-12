# GPS: vertical land motion

Vertical velocities of GPS (GNSS) stations, to test and constrain models of glacial
isostatic adjustment (GIA) with present-day uplift rates. GPS is a records dataset
(non-gridded data, see [Records](https://fesmc.github.io/FesmData/records_overview.html)):
its products, defined in `GPS/records.toml`, are prepared files in the form of the CF
discrete sampling geometries, written to `$FESMDATA/Records/GPS/GPS-<product>.nc`.
Gridded uplift rates (the land uplift model NKG2016LU of Fennoscandia) are in
[SolidEarth](https://fesmc.github.io/FesmData/datasets/solidearth.html).

## Products

| Product | Source | Sites | Elastic part | Frame |
|---|---|---|---|---|
| `GPS-Schumacher2018` | Schumacher et al. (2018), [doi:10.1594/PANGAEA.889923](https://doi.org/10.1594/PANGAEA.889923) | 4072 stations worldwide | removed | CM (see the article) |
| `GPS-MIDAS` | Blewitt et al. (2016): MIDAS velocities of the Nevada Geodetic Laboratory, snapshot of 2026-11-12, [doi:10.1002/2015JB012552](https://doi.org/10.1002/2015JB012552) | 21 892 stations worldwide | not removed | IGS20 |
| `GPS-BIFROST2015` | Kierulf et al. (2021): BIFROST2015, Fennoscandia, 2000-2015, [doi:10.1016/j.jog.2021.101845](https://doi.org/10.1016/j.jog.2021.101845) | 164 stations | not removed, given (`uplift_rate_elastic`) | ITRF2008 |
| `GPS-GNET` | Berg et al. (2024): GNET, Greenland, to 2022, [doi:10.1029/2023GL104851](https://doi.org/10.1029/2023GL104851), as distributed by Lewright et al. (2025), [doi:10.5281/zenodo.16878392](https://doi.org/10.5281/zenodo.16878392) | 55 stations | not removed, given (`uplift_rate_elastic`) | IGS14 |
| `GPS-MartinEspanol2016` | Martín-Español et al. (2016): Antarctica, 2009-2014, [doi:10.1002/2016JB013154](https://doi.org/10.1002/2016JB013154) | 67 stations | removed (Antarctic ice) | ITRF2008 |

Stations by region (Fennoscandia: 55-72°N, 4-33°E; Greenland; North America: 25-85°N,
170-50°W without Greenland; Antarctica: south of 60°S):

| Product | Fennoscandia | Greenland | North America | Antarctica |
|---|---|---|---|---|
| `GPS-Schumacher2018` | 90 | 56 | 1907 | 65 |
| `GPS-MIDAS` | 927 | 94 | 8880 | 209 |
| `GPS-BIFROST2015` | 143 (164 with the Baltic countries and Central Europe) | | | |
| `GPS-GNET` | | 55 | | |
| `GPS-MartinEspanol2016` | | | | 67 |

## Variables

One value per station (featureType point, dimension `station`, with `lat`, `lon` and
`site_name`), the rates being trends over the GPS series, without a time axis:

- `uplift_rate`, `uplift_rate_sd` (mm yr-1): the vertical velocity and its uncertainty
  (1 sigma).
- `uplift_rate_elastic` (and `uplift_rate_elastic_sd`), mm yr-1, where the source gives
  it: the modelled elastic vertical velocity over the observation period (the response
  to present changes of ice, and in BIFROST2015 also of water and the atmosphere). The
  GIA estimate is then `uplift_rate - uplift_rate_elastic`.
- `time_start`, `time_end` (decimal years): the first and last epoch of the series,
  where the source gives them.

**Elastic correction.** The attribute `elastic_correction` of `uplift_rate` (and the
global attribute of the same name) says whether the elastic response to present ice
changes is removed from `uplift_rate` (`"removed"`: an estimate of the GIA uplift rate)
or not (`"not removed"`: the observed total vertical land motion); its long name says
it too, also in the text form. In Greenland, Antarctica and, less, Fennoscandia the
elastic part is large (in Greenland most of the observed uplift), so a model without
the present-day ice changes is compared with the products that remove or give it. The
global attribute `reference_frame` gives the frame of the velocities (frames differ by
up to about 1 mm/yr in the vertical, through the rate of their origin).

The products overlap: MIDAS has most stations of the others (with longer series, and
uncorrected), and Schumacher2018 is based on the NGL series as well.

## Licences

| Source | Licence |
|---|---|
| Schumacher et al. (2018) | CC BY 3.0 (PANGAEA) |
| Blewitt et al. (2016), MIDAS of NGL | CC BY 4.0 (data products policy of the Nevada Bureau of Mines and Geology) |
| Kierulf et al. (2021) | CC BY 4.0 (supplement of the open-access article) |
| Berg et al. (2024), Lewright et al. (2025) | CC BY 4.0 (Lewright et al., Zenodo) and CC0 (Berg et al., Dryad/Zenodo) |
| Martín-Español et al. (2016) | CC BY 4.0 (supporting information of the open-access article) |

## Making the dataset

```bash
julia fesmdata.jl record GPS
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA/Records/GPS/` (`--overwrite` to replace them).
