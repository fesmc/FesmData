# SeaLevel: global sea level over glacial cycles

Reconstructions of global (mean or eustatic) sea level over glacial cycles, some with
the contributions of the ice sheets: stacks and regressions of benthic δ18O, inverse
modelling of ice sheets, the Red Sea record, and the ice sheets of PaleoMIST 1.0.
SeaLevel is a records dataset (non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)): its products,
defined in `SeaLevel/records.toml`, are prepared files in the form of the CF discrete
sampling geometries, written to
`$FESMDATA/Records/SeaLevel/SeaLevel-<product>[-<part>].nc`, each with its text
form (`.txt`). Relative sea level indicators at sites are in RSL.

## Products

| Product | Source | Variables | Time |
|---|---|---|---|
| `SeaLevel-Spratt2016` | Spratt and Lisiecki (2016): sea-level stacks, [doi:10.25921/rd66-5820](https://doi.org/10.25921/rd66-5820) | `sl_short` (7 records, 0-430 ka), `sl_long` (5 records, 0-798 ka), each with `_sd`, `_min`, `_max` (95%) | 0-798 ka, 1 kyr (LR04) |
| `SeaLevel-Waelbroeck2002` | Waelbroeck et al. (2002): from benthic δ18O, [doi:10.25921/08dt-1228](https://doi.org/10.25921/08dt-1228) | `sl`, `sl_min`, `sl_max`, `d18O_sw` with its range; alternate age models | 0.5-430 ka, 1.5 kyr |
| `SeaLevel-Bintanja2008` | Bintanja and van de Wal (2008): inverse modelling, [doi:10.25921/revb-da37](https://doi.org/10.25921/revb-da37) | `sl`, `sl_nam`, `sl_eas`, `tas_anom_nh`, `t_deep_anom`, `d18O_benthic`, `d18O_ice`, `d18O_temp` | 0-3 Ma, 100 years |
| `SeaLevel-deBoer2014` | de Boer et al. (2014): inverse modelling with four ice sheets, [doi:10.25921/xs31-nt56](https://doi.org/10.25921/xs31-nt56) | `sl`, `sl_eis`, `sl_nais`, `sl_ais`, `sl_gris`, `tas_anom_nh`, `d18O_benthic`, `d18O_sw`, `d18O_temp`, `V_ais`, `D_ais` | 0-5.3 Ma, 100 years |
| `SeaLevel-Berends2021` | Berends et al. (2021): coupled ice-sheet-climate model, [doi:10.5281/zenodo.3793592](https://doi.org/10.5281/zenodo.3793592) | `sl`, `sl_min`, `sl_max`, `co2`, `co2_min`, `co2_max` (three simulations) | 0-3.6 Ma, 100 years |
| `SeaLevel-Rohling2021` | Rohling et al. (2021): regression on the LR04 stack, [doi:10.25921/rq2y-4k67](https://doi.org/10.25921/rq2y-4k67) | `sl`, `sl_lis`, `sl_eis`, `sl_ais`, `sl_gris`, `d18O_benthic`, `d18O_sw`, `d18O_temp`, `t_deep_anom` | 0-5.3 Ma, 1 kyr (LR04) |
| `SeaLevel-Lambeck2014` | Lambeck et al. (2014): ice-volume equivalent sea level from sea-level indicators and glacial isostatic adjustment, [doi:10.1073/pnas.1411762111](https://doi.org/10.1073/pnas.1411762111) | `sl`, `sl_sd`, `sl_nominal` | 0-35 ka, 326 values |
| `SeaLevel-Grant2014-<part>` | Grant et al. (2014): Red Sea relative sea level, [doi:10.1038/ncomms6076](https://doi.org/10.1038/ncomms6076); parts `probabilistic` and `data` | `rsl`, `rsl_min`, `rsl_max` (95%), `rsl_data_min`, `rsl_data_max`, `drsl` with its range; `data`: `rsl` of the data points | 0-492 ka, 125 years; data points |
| `SeaLevel-PaleoMIST`, `SeaLevel-PaleoMIST_max` | Gowan et al. (2021): ice sheets of PaleoMIST 1.0, minimal and maximal MIS 3 scenarios, [doi:10.1594/PANGAEA.905800](https://doi.org/10.1594/PANGAEA.905800) | `sl`, `sl_nam` (with Greenland), `sl_eis`, `sl_ais`, `sl_pat` | 0-80 ka, 2.5 kyr |

All are series of the region "global" without a location (featureType timeSeries,
dimension `region`, `lat` and `lon` missing), except Grant et al. (2014), a time series
at the Hanish Sill of the Red Sea (dimension `station`). `time` is in years before 1950
CE (units "years ago"), on the age model of the source (in the comment of `time`).

Conventions: `sl` is sea level relative to the present in m, negative when lower (e.g.
about -120 m at the Last Glacial Maximum); `sl_<ice sheet>` is the contribution of an ice
sheet to it, with the same sign (minus the change of its volume from the present, in m
sea level equivalent). Sources with the opposite sign (Bintanja and van de Wal, 2008)
or with total ice volumes (de Boer et al., 2014; Rohling et al., 2021) are converted;
values at the present are kept as given, not set to zero (e.g. Spratt and Lisiecki,
2016: +8.5 m; Berends et al., 2021: -3.3 m). `_sd` is 1 sigma, `_min` and `_max` the
bounds given by the source (see the long names).

## Licences

| Source | Licence |
|---|---|
| Spratt and Lisiecki (2016), Waelbroeck et al. (2002), Bintanja and van de Wal (2008), de Boer et al. (2014), Rohling et al. (2021) | NOAA NCEI open data, no licence stated; publishing assumed to be allowed |
| Berends et al. (2021) | CC BY 4.0 (Zenodo) |
| Grant et al. (2014) | Supplement of a Nature Communications article, no open licence stated; publishing assumed to be allowed |
| Lambeck et al. (2014) | Supporting information of a PNAS article, no open licence stated; publishing assumed to be allowed |
| Gowan et al. (2021), PaleoMIST 1.0 | CC BY 4.0 (PANGAEA) |

## Making the dataset

```bash
julia fesmdata.jl record SeaLevel
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA/Records/SeaLevel/` with their text forms
(`--overwrite` to replace them). PaleoMIST needs the archive of PaleoMIST 1.0 (3.5 GB,
also used by IceHistory); Lambeck2014 a manual download (see its README) and `pdftotext`.
