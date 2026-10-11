# NGRIP temperature, 10-120 kyr b2k (Kindler et al., 2014)

Surface temperature and accumulation rate at NGRIP (75.10°N, 42.32°W) every 20 years
from 10 to 122 kyr b2k, reconstructed from δ15N measurements with a firn densification
and heat diffusion model, from the supplement of:

Kindler, P., Guillevic, M., Baumgartner, M., Schwander, J., Landais, A., and
Leuenberger, M.: Temperature reconstruction from 10 to 120 kyr b2k from the NGRIP ice
core, Clim. Past, 10, 887-902, 2014,
[doi:10.5194/cp-10-887-2014](https://doi.org/10.5194/cp-10-887-2014).

## Licence

The article and its supplement are published by Copernicus under CC BY 3.0.

## Original data

`supplement.xlsx` of the article supplement,
https://cp.copernicus.org/articles/10/887/2014/cp-10-887-2014-supplement.zip (no login),
downloaded by `prepare.jl` (datamanifest key `kindler2014_ngrip`). Its sheet
`modelled data` has depth, the ages on the ss09sea06bm and GICC05modelext time scales,
the tuned accumulation rate (m ice/yr) and the temperature (°C), and the ice and gas
ages; the sheet `d15N data` has the δ15N measurements (not used).

## Prepare and record

```bash
julia --project=Kindler2014 Kindler2014/prepare.jl
julia fesmdata.jl record IceCores Kindler2014
```

`prepare.jl` writes `$FESMDATA_WORK/prepared/Kindler2014/Kindler2014_NGRIP.nc` (see
`Records/README.md`), a time series at one station (featureType timeSeries):

- `tas` (K): surface temperature, from °C (+ 273.15); the article gives an
  uncertainty of about 3 K;
- `acc` (kg m-2 yr-1): accumulation rate, from m ice yr-1 with an ice density of
  917 kg m-3;
- `depth` (m): depth of the ice of each age.

`time` is the GICC05modelext age in years before 1950 CE (`time` = age b2k - 50), from
9915 to 122245; `time_ss09sea06bm` is the age on the time scale of the model run.
