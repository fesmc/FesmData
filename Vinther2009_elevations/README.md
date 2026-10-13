# Holocene surface elevation at Greenland ice core sites (Vinther et al., 2009)

Surface elevation changes over the Holocene (11.7 ka b2k to present, 20-year values) at
Camp Century, NGRIP, GRIP and DYE-3, from the δ18O of the ice cores compared with those
of small marginal ice caps, corrected for upstream effects. From:

Vinther, B. M., Buchardt, S. L., Clausen, H. B., Dahl-Jensen, D., Johnsen, S. J.,
Fisher, D. A., Koerner, R. M., Raynaud, D., Lipenkov, V., Andersen, K. K., Blunier, T.,
Rasmussen, S. O., Steffensen, J. P., and Svensson, A. M.: Holocene thinning of the
Greenland ice sheet, Nature, 461, 385-388, 2009,
[doi:10.1038/nature08355](https://doi.org/10.1038/nature08355).

Data: Vinther, B. M. et al.: Greenland Ice Sheet Holocene d18O, Temperature, and Surface
Elevation, IGBP PAGES/World Data Center for Paleoclimatology Data Contribution Series
\# 2011-053, NOAA NCDC, 2011.

## Licence

NOAA NCEI open data: no licence is stated and there are no restrictions on use; NCEI
asks to cite the publication. We assume the data may be published.

## Original data

`vinther2009greenland.txt` of the NCEI paleo archive,
https://www.ncei.noaa.gov/pub/data/paleo/icecore/greenland/vinther2009greenland.txt (no
login), downloaded by `prepare.jl` (datamanifest key `vinther2009_greenland`). It is the
text version of `vinther2009greenland.xls` (same folder); section 3 has the site
elevation changes (m) by age (years b2k, the bottom of each 20-year interval). The
other sections (δ18O, uplift-corrected δ18O of Agassiz and Renland, temperature) are not
used.

## Prepare and record

```bash
julia --project=Vinther2009_elevations Vinther2009_elevations/prepare.jl
julia fesmdata.jl record IceCores Vinther2009
```

`prepare.jl` writes
`$FESMDATA_PREPARED/Vinther2009_elevations/Vinther2009_elevations.nc` (see
`Records/README.md`), time series at four stations (featureType timeSeries):

- `dz_srf` (m): surface elevation change relative to the present (the interval 20-40
  b2k);
- `dz_srf_sd` (m): its 1σ uncertainty, 40 m at GRIP and NGRIP and 65 m at Camp Century
  and DYE-3 (Vinther et al., 2009, supplementary information);
- `z_srf` (m, by station): the present elevation of the site, so that the elevation is
  `z_srf + dz_srf` (the v1 file `vinther2009.nc` had this sum).

| Site | Location | Present elevation |
|---|---|---|
| Camp Century | 77°10'N, 61°08'W | 1890 m |
| NGRIP | 75.1°N, 42.3°W | 2920 m |
| GRIP | 72°35'N, 37°38'W | 3230 m |
| DYE-3 | 65°11'N, 43°49'W | 2490 m |

`time` is the centre of each 20-year interval in years before 1950 CE (age b2k - 10 -
50), from -20 (1970 CE) to 11640, with `time_bnds`.
