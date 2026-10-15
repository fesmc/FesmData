# Sea level and CO2 of a coupled ice-sheet-climate model, 3.6 Myr (Berends et al., 2021)

Global mean sea level and atmospheric CO2 every 100 years over the last 3.6 Myr, from a
hybrid ice-sheet-climate model forced by the LR04 benthic δ18O stack, with the range of
three simulations. From:

Berends, C. J., de Boer, B., and van de Wal, R. S. W.: Reconstructing the evolution of ice
sheets, sea level, and atmospheric CO2 during the past 3.6 million years, Clim. Past,
17, 361-377, 2021, [doi:10.5194/cp-17-361-2021](https://doi.org/10.5194/cp-17-361-2021).

Data: Zenodo, [doi:10.5281/zenodo.3793592](https://doi.org/10.5281/zenodo.3793592).

## Licence

CC BY 4.0 (Zenodo).

## Original data

`Berends_etal_2020_CP_supplement.dat`, downloaded by `prepare.jl` (datamanifest key
`berends2021_sealevel`): time (kyr ago, negative), sea level (m relative to the present
day) and CO2 (ppmv), each with a lower and upper value (three simulations). The file has
no contributions of the ice sheets.

## Prepare and record

```bash
julia --project=Berends2021_sealevel Berends2021_sealevel/prepare.jl
julia fesmdata.jl record SeaLevel Berends2021
```

`prepare.jl` writes `$FESMDATA_PREPARED/Berends2021_sealevel/Berends2021_sealevel.nc` (see
`Records/README.md`), a global series (dimension `region`, no location) of 36000 values,
sorted forward in age: `sl`, `sl_min`, `sl_max` (m), `co2`, `co2_min`, `co2_max`
(ppm). The model sea level at the present is -3.32 m: kept as given.
