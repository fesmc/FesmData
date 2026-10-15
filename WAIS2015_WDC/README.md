# WAIS Divide d18O, 68 kyr (WAIS Divide Project Members, 2015)

δ18O of the WAIS Divide ice core WDC06A (79.47°S, 112.09°W, 1766 m) in tubes of about
1 m, from 2005 CE to 68 ka, on the WD2014 time scale. From:

WAIS Divide Project Members: Precise interpolar phasing of abrupt climate change during
the last ice age, Nature, 520, 661-665, 2015,
[doi:10.1038/nature14401](https://doi.org/10.1038/nature14401); the last 30 kyr: WAIS
Divide Project Members, Nature, 500, 440-444, 2013,
[doi:10.1038/nature12376](https://doi.org/10.1038/nature12376); the last 2000 years:
Steig, E. J. et al., Nat. Geosci., 6, 372-375, 2013,
[doi:10.1038/ngeo1778](https://doi.org/10.1038/ngeo1778). WD2014: Buizert, C. et al.,
Clim. Past, 11, 153-173, 2015; Sigl, M. et al., Clim. Past, 12, 769-786, 2016.

Data: Steig, E. J. et al.: WAIS Divide Ice Core Oxygen Isotopes, USAP-DC,
[doi:10.7265/N5GT5K41](https://doi.org/10.7265/N5GT5K41) (final data set of 3 September
2014).

## Licence

CC BY-NC 4.0 (USAP-DC): non-commercial use, with attribution.

## Original data

`Steig_WAIS_Divide_Ice_Core_WDC06A_Oxygen_Isotopes.txt` (datamanifest key
`wais2015_wdc`): a `%` header, then tab-separated tube number, top and bottom depth (m),
δ18O (‰ VSMOW/SLAP) and the WD2014 ages of the top and bottom (ka before 1950); 999999
for missing values (tubes 1096 and 1326 not sampled). The download of USAP-DC is behind
a captcha: download the zip by hand from https://www.usap-dc.org/view/dataset/609629 and
put this file (the zip also has 100-year means, not used) in
`$FESMDATA_SOURCES/wais2015_wdc/`. The δD of the core (NSIDC-0662) is not used.

The AICC2023 ages come from the WAIS Divide-EDC tie points of AICC2023 (Bouchet et al.,
2023, PANGAEA, [doi:10.1594/PANGAEA.990386](https://doi.org/10.1594/PANGAEA.990386),
datamanifest key `aicc2023_wdc_ties`): WDC and EDC depths with the ages on WD2014, AICC2012
and AICC2023 (ka b2k), 10-57 ka.

## Prepare and record

```bash
julia --project=WAIS2015_WDC WAIS2015_WDC/prepare.jl
julia fesmdata.jl record IceCores WAIS2015
```

`prepare.jl` writes `$FESMDATA_PREPARED/WAIS2015_WDC/WAIS2015_WDC.nc` (see
`Records/README.md`), a time series at WAIS Divide (featureType timeSeries) of 6375
tubes: `d18O` (‰), `depth` (m, middle of the tube), `depth_top`, `depth_bottom`, `tube`,
`time` (WD2014 age of the middle of the tube, with `time_bnds` from the ages of the top
and bottom) and `time_aicc2023` (interpolated linearly in WDC depth between the tie
points; missing outside 10-57 ka).
