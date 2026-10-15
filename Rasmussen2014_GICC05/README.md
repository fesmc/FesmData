# NGRIP, GRIP and GISP2 d18O and calcium on GICC05modelext (Rasmussen et al., 2014)

δ18O and calcium concentration of the NGRIP (NGRIP1 and NGRIP2 cores), GRIP and GISP2 ice
cores in 20-year means, synchronized on the GICC05modelext time scale, from the present
to 122 ka b2k (GRIP and GISP2 to about 104 ka). From:

Rasmussen, S. O. et al.: A stratigraphic framework for abrupt climatic changes during the
Last Glacial period based on three synchronized Greenland ice-core records: refining and
extending the INTIMATE event stratigraphy, Quat. Sci. Rev., 106, 14-28, 2014,
[doi:10.1016/j.quascirev.2014.09.007](https://doi.org/10.1016/j.quascirev.2014.09.007);
and Seierstad, I. K. et al.: Consistently dated records from the Greenland GRIP, GISP2
and NGRIP ice cores for the past 104 ka reveal regional millennial-scale δ18O gradients
with possible Heinrich event imprint, Quat. Sci. Rev., 106, 29-46, 2014,
[doi:10.1016/j.quascirev.2014.10.032](https://doi.org/10.1016/j.quascirev.2014.10.032).

The δ18O and calcium data are from the works listed in the workbook (NGRIP members,
2004; Johnsen et al., 1997; Grootes and Stuiver, 1997; Stuiver and Grootes, 2000;
Bigler, 2004; Fuhrer et al., 1993; Mayewski et al., 1997).

## Licence

No licence stated: the Centre for Ice and Climate asks to cite the publications. We
assume the data may be published.

## Original data

The workbook `GICC05modelext_GRIP_and_GISP2_and_resampled_data_series_Seierstad_et_al._2014_version_10Dec2014-2.xlsx`
of https://www.iceandclimate.nbi.ku.dk/data/ (no login), downloaded by `prepare.jl`
(datamanifest key `rasmussen2014_gicc05`). Sheet 3 has, every 20 years, the age (years
b2k), the depth and δ18O (‰) of NGRIP1 and NGRIP2, the depth, δ18O and [Ca2+] (ppb) of
NGRIP2, GRIP and GISP2, and the maximum counting error (MCE, years). The sheet is in step
form: two rows per interval, at its top and bottom.

## Prepare and record

```bash
julia --project=Rasmussen2014_GICC05 Rasmussen2014_GICC05/prepare.jl
julia fesmdata.jl record IceCores Rasmussen2014
```

`prepare.jl` writes `$FESMDATA_PREPARED/Rasmussen2014_GICC05/Rasmussen2014_GICC05.nc` (see
`Records/README.md`), time series at four stations, NGRIP1, NGRIP2, GRIP and GISP2
(featureType timeSeries), on the 20-year intervals: `d18O` (‰), `ca` (ng g-1, = ppb; not
NGRIP1), `depth` (m, bottom of the interval), `time` (middle of the interval, with
`time_bnds`), `mce` (yr, at the bottom of the interval, to 60 ka b2k) and
`time_aicc2023` (AICC2023 age at the bottom of the interval, for NGRIP1 and NGRIP2 from
`Bouchet2023_AICC2023`; missing for GRIP and GISP2).

Notes:

- The ages are converted from b2k to years before 1950 CE (minus 50).
- NGRIP1 reaches 1372 m; the NGRIP2 data start at 1346 m. The two cores are 20 m apart
  and their depths are offset by 0.43 m on average in the overlap; both are kept as
  stations at the location of NGRIP.
- GISP2 on its own (Meese/Sowers) time scale (Grootes and Stuiver, 1997) is not used:
  this file has it on GICC05modelext.
