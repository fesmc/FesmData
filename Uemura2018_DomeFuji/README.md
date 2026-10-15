# Dome Fuji water isotopes and temperatures, 720 kyr (Uemura et al., 2012, 2018)

δ18O, δD and deuterium excess of the Dome Fuji ice cores (77.32°S, 39.70°E, 3810 m), and
the site and moisture-source temperatures derived from them, over the last 720 kyr on
AICC2012. From:

Uemura, R. et al.: Asynchrony between Antarctic temperature and CO2 associated with
obliquity over the past 720,000 years, Nat. Commun., 9, 961, 2018,
[doi:10.1038/s41467-018-03328-3](https://doi.org/10.1038/s41467-018-03328-3); and
Uemura, R. et al.: Ranges of moisture-source temperature estimated from Antarctic ice
cores stable isotope records over glacial-interglacial cycles, Clim. Past, 8, 1109-1125,
2012, [doi:10.5194/cp-8-1109-2012](https://doi.org/10.5194/cp-8-1109-2012).

Data: Dome Fuji 720,000 Year Stable Isotope Data and Temperature Reconstruction, NOAA
NCEI, [doi:10.25921/9886-bg13](https://doi.org/10.25921/9886-bg13).

## Licence

NOAA NCEI open data: no licence stated, no restrictions on use; cite the publications and
the dataset. We assume the data may be published.

## Original data

`domefuji2018iso-temp-noaa.txt` (NOAA template), downloaded by `prepare.jl` (datamanifest
key `uemura2018_domefuji`): top and bottom depth of the sample (m), AICC2012 age (years
before 1950), δ18O, δD (‰ VSMOW), deuterium excess (linear and logarithmic definitions,
‰), site and source temperatures (°C). The first core (DF1) gives the data to 2401.91 m
(0-296 ka, Uemura et al., 2012), the second (DF2) from 2399.5 m (296-716 ka, Uemura et
al., 2018). The NOAA header gives 38.7°E, a typo for 39.70°E.

The δ18O of Kawamura et al. (2017, doi:10.25921/zphz-qz79) and Kawamura et al. (2007, on
DFO-2006) have no δD and are not used.

## Prepare and record

```bash
julia --project=Uemura2018_DomeFuji Uemura2018_DomeFuji/prepare.jl
julia fesmdata.jl record IceCores Uemura2018
```

`prepare.jl` writes `$FESMDATA_PREPARED/Uemura2018_DomeFuji/Uemura2018_DomeFuji.nc` (see
`Records/README.md`), a time series at Dome Fuji (featureType timeSeries) along the
dimension `sample`: `d18O`, `dD`, `dxs`, `dln` (‰), `tas_anom`, `t_source_anom` (K,
relative to the present), `depth_top`, `depth_bottom` (m) and `time` (AICC2012).

Notes:

- The 66 samples at the bottom without an age are left out (7470 remain).
- The depths reverse where the two cores join (about 2400 m): the samples are sorted by
  age, along `sample`.
- Dome Fuji has no AICC2023 ages (not one of the cores of AICC2023).
