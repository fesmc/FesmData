# NEEM ice core high-resolution water isotopes (Gkinis et al., 2020)

δ18O and δD of the NEEM ice core (77.45°N, 51.06°W, 2545 m), Greenland, in 0.05 m
samples from 1210.5 to 2536.5 m depth (about 8 to 129 ka b2k). From:

Gkinis, V. et al.: NEEM ice core High Resolution (0.05m) Water Isotope Ratios (18O/16O,
2H/1H) covering 8-129 ky b2k, PANGAEA, 2020,
[doi:10.1594/PANGAEA.925552](https://doi.org/10.1594/PANGAEA.925552), supplement to
Gkinis, V. et al.: A 120,000-year long climate record from a NW-Greenland deep ice core
at ultra-high resolution, Sci. Data, 8, 141, 2021,
[doi:10.1038/s41597-021-00916-9](https://doi.org/10.1038/s41597-021-00916-9).

## Licence

CC BY 4.0 (PANGAEA).

## Original data

The tab-delimited text of the PANGAEA dataset,
https://doi.pangaea.de/10.1594/PANGAEA.925552?format=textfile (no login), downloaded by
`prepare.jl` (datamanifest key `gkinis2020_neem`): depth (bottom of each sample), the
ages (ka b2k) on GICC05 (counted), GICC05_modelext and AICC2012, the maximum counting
error of GICC05, δ18O, δD (‰ VSMOW), their precision (1σ) and the offsets of the
accuracy checks.

## Prepare and record

```bash
julia --project=Gkinis2020_NEEMwateriso Gkinis2020_NEEMwateriso/prepare.jl
julia fesmdata.jl record IceCores Gkinis2020
```

`prepare.jl` writes `$FESMDATA_PREPARED/Gkinis2020_NEEMwateriso/Gkinis2020_NEEM.nc`
(see `Records/README.md`), a time series at one station (featureType timeSeries) along
the dimension `sample`: `d18O`, `dD`, their precision `d18O_sd`, `dD_sd`, the offsets
`d18O_offset`, `dD_offset` (units 1e-3, i.e. per mil), `depth` (m) and `mce` (yr).

Notes:

- The three age columns each cover only part of the core: GICC05 (counted) from 1210.50
  to 1955.90 m (8-60 ka), GICC05_modelext and AICC2012 below. `time` is GICC05 above
  1955.90 m and GICC05_modelext below; `time_aicc2012` is GICC05 above and AICC2012
  below. Both are in years before 1950 CE (age b2k - 50).
- The 2834 samples below 2394.8 m have no GICC05_modelext age (the folded ice at the
  bottom) and are left out (23687 samples remain).
- In the disturbed ice between 2206 and 2365 m the ages are not monotonic in depth: the
  samples are sorted by `time` (as in the v1 file), and `depth` is kept as a variable. A
  few samples have the same age, so `time` is not a dimension.
- The v1 script `build_neem_dataset.jl` (with a depth-indexed file and a figure) is
  replaced by `prepare.jl`.
