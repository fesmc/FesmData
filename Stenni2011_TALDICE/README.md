# TALDICE d18O on AICC2012, 153 kyr (Stenni et al., 2011)

δ18O of the Talos Dome ice core (72.78°S, 159.07°E, 2315 m) every 1 m to 1437 m (153
ka), on the AICC2012 chronology. From:

Stenni, B. et al.: Expression of the bipolar see-saw in Antarctic climate records during
the last deglaciation, Nat. Geosci., 4, 46-49, 2011,
[doi:10.1038/ngeo1026](https://doi.org/10.1038/ngeo1026); on AICC2012: Bazin, L. et al.:
An optimized multi-proxy, multi-site Antarctic ice and gas orbital chronology
(AICC2012): 120-800 ka, Clim. Past, 9, 1715-1731, 2013,
[doi:10.5194/cp-9-1715-2013](https://doi.org/10.5194/cp-9-1715-2013).

Data: PANGAEA, [doi:10.1594/PANGAEA.824890](https://doi.org/10.1594/PANGAEA.824890)
(part of the AICC2012 collection, doi:10.1594/PANGAEA.824894).

## Licence

CC BY 3.0 (PANGAEA).

## Original data

The tab-delimited text of the PANGAEA dataset (no login), downloaded by `prepare.jl`
(datamanifest key `stenni2011_taldice`): depth (m), AICC2012 age (ka BP), δ18O (‰ SMOW).
No public file has the whole record of about 250 kyr; the AICC2012 file of NOAA notes
that TALDICE should not be used on AICC2012 beyond 150 ka.

## Prepare and record

```bash
julia --project=Stenni2011_TALDICE Stenni2011_TALDICE/prepare.jl
julia fesmdata.jl record IceCores Stenni2011
```

`prepare.jl` writes `$FESMDATA_PREPARED/Stenni2011_TALDICE/Stenni2011_TALDICE.nc` (see
`Records/README.md`), a time series at Talos Dome (featureType timeSeries) of 1427
depths: `d18O` (‰), `depth` (m), `time` (AICC2012) and `time_aicc2023` (AICC2023 age at
the same depth, from `Bouchet2023_AICC2023`).
