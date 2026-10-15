# EPICA Dome C dust flux, 800 kyr (Lambert et al., 2012)

Dust flux of the EPICA Dome C ice core (75.10°S, 123.35°E, 3233 m) in 25-year means over
the last 800 kyr on EDC3. From:

Lambert, F., Bigler, M., Steffensen, J. P., Hutterli, M., and Fischer, H.: Centennial
mineral dust variability in high-resolution ice core data from Dome C, Antarctica, Clim.
Past, 8, 609-623, 2012, [doi:10.5194/cp-8-609-2012](https://doi.org/10.5194/cp-8-609-2012).

Data: Lambert, F. et al.: EDC dust flux 800 kyr (25 yr mean), PANGAEA,
[doi:10.1594/PANGAEA.778213](https://doi.org/10.1594/PANGAEA.778213).

## Licence

CC BY 3.0 (PANGAEA).

## Original data

The tab-delimited text of the PANGAEA dataset (no login), downloaded by `prepare.jl`
(datamanifest key `lambert2012_edcdust`): depth (m), EDC3 age (ka BP), dust flux (mg m-2
yr-1). The 25-year means are of the 1 cm data: many data points near the top, one or two
at the bottom of the core (see the methods of the article before any analysis of
variability). The dust concentrations of Lambert et al. (2008, doi:10.1038/nature06763)
are not used.

## Prepare and record

```bash
julia --project=Lambert2012_EDCdust Lambert2012_EDCdust/prepare.jl
julia fesmdata.jl record IceCores Lambert2012
```

`prepare.jl` writes `$FESMDATA_PREPARED/Lambert2012_EDCdust/Lambert2012_EDCdust.nc` (see
`Records/README.md`), a time series at EDC (featureType timeSeries) of 31838 values:
`dust_flux` (mg m-2 yr-1), `depth` (m), `time` (EDC3) and `time_aicc2023` (AICC2023 age
at the same depth, from `Bouchet2023_AICC2023`).
