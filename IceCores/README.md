# IceCores: ice core records

Time series at Antarctic and Greenland ice core sites over glacial cycles: water
isotopes, temperature, accumulation, dust and surface elevation, and the AICC2023 ice core
chronology. IceCores is a records dataset (non-gridded data, see
[Records](https://fesmc.github.io/FesmData/records_overview.html)): its products,
defined in `IceCores/records.toml`, are prepared files in the form of the CF discrete
sampling geometries, written to
`$FESMDATA_PRODUCTS/Records/IceCores/IceCores-<product>[-<part>].nc`, each with its text
form (`.txt`).

## Products

| Product | Source | Sites | Variables | Time |
|---|---|---|---|---|
| `IceCores-Jouzel2007` | Jouzel et al. (2007): EPICA Dome C deuterium, [doi:10.25921/8t7e-z147](https://doi.org/10.25921/8t7e-z147) | EDC | `dD` (‰), `tas_anom` (K), `depth` | 0-802 ka, 0.55 m bags (EDC3; also AICC2023) |
| `IceCores-Petit1999` | Petit et al. (1999): Vostok deuterium, [doi:10.25921/kcry-ae86](https://doi.org/10.25921/kcry-ae86) | Vostok | `dD` (‰), `tas_anom` (K), `depth` | 0-423 ka, every 1 m (GT4; also AICC2023) |
| `IceCores-Uemura2018` | Uemura et al. (2012, 2018): Dome Fuji water isotopes, [doi:10.25921/9886-bg13](https://doi.org/10.25921/9886-bg13) | Dome Fuji | `d18O`, `dD`, `dxs`, `dln` (‰), `tas_anom`, `t_source_anom` (K), `depth_top`, `depth_bottom` | 0-716 ka (AICC2012) |
| `IceCores-EPICA2006` | EPICA Community Members (2006): EDML δ18O, [doi:10.1594/PANGAEA.754444](https://doi.org/10.1594/PANGAEA.754444) | EDML | `d18O`, `d18O_swcor`, `d18O_swaltcor`, `d18O_sw` (‰), `dz_srf`, `depth` | 0-150 ka, 0.5 m (EDML1; also AICC2023) |
| `IceCores-WAIS2015` | WAIS Divide Project Members (2015): WAIS Divide δ18O, [doi:10.7265/N5GT5K41](https://doi.org/10.7265/N5GT5K41) | WAIS Divide | `d18O` (‰), `depth`, `depth_top`, `depth_bottom`, `tube` | 0-68 ka, about 1 m tubes (WD2014; AICC2023 for 10-57 ka) |
| `IceCores-Stenni2011` | Stenni et al. (2011): TALDICE δ18O on AICC2012, [doi:10.1594/PANGAEA.824890](https://doi.org/10.1594/PANGAEA.824890) | TALDICE | `d18O` (‰), `depth` | 0-153 ka, every 1 m (AICC2012; also AICC2023) |
| `IceCores-Lambert2012` | Lambert et al. (2012): EPICA Dome C dust flux, [doi:10.1594/PANGAEA.778213](https://doi.org/10.1594/PANGAEA.778213) | EDC | `dust_flux` (mg m-2 yr-1), `depth` | 0.4-801 ka, 25 years (EDC3; also AICC2023) |
| `IceCores-Rasmussen2014` | Rasmussen et al. (2014), Seierstad et al. (2014): synchronized Greenland records, [doi:10.1016/j.quascirev.2014.09.007](https://doi.org/10.1016/j.quascirev.2014.09.007) | NGRIP1, NGRIP2, GRIP, GISP2 | `d18O` (‰), `ca` (ng g-1), `depth`, `mce` | 0-122 ka, 20 years (GICC05modelext; NGRIP also AICC2023) |
| `IceCores-Buizert2018` | Buizert et al. (2018): seasonal temperatures at ice core sites, [doi:10.25921/psvs-yg80](https://doi.org/10.25921/psvs-yg80) | NEEM, NGRIP, GISP2, Dye-3, ReCAP, Agassiz, Hans Tausen, Camp Century, EGRIP | `tas_ann`, `tas_djf`, `tas_mam`, `tas_jja`, `tas_son` (K) | 22 ka to present, 20 years |
| `IceCores-Kindler2014` | Kindler et al. (2014): reconstruction from δ15N and a firn model, [doi:10.5194/cp-10-887-2014](https://doi.org/10.5194/cp-10-887-2014) | NGRIP | `tas` (K), `acc` (kg m-2 yr-1), `depth` | 10-122 ka, 20 years (GICC05modelext) |
| `IceCores-Gkinis2020` | Gkinis et al. (2020): 0.05 m samples, [doi:10.1594/PANGAEA.925552](https://doi.org/10.1594/PANGAEA.925552) | NEEM | `d18O`, `dD` (‰) with precision and accuracy offsets, `depth` | 8-121 ka (GICC05, GICC05_modelext; also AICC2012) |
| `IceCores-Vinther2009` | Vinther et al. (2009): Holocene thinning, [doi:10.1038/nature08355](https://doi.org/10.1038/nature08355) | Camp Century, NGRIP, GRIP, DYE-3 | `dz_srf`, `dz_srf_sd` (m), `z_srf` (present) | 11.7 ka to present, 20 years (GICC05) |
| `IceCores-AICC2023-<core>` | Bouchet et al. (2023): AICC2023 chronology, [doi:10.1594/PANGAEA.961017](https://doi.org/10.1594/PANGAEA.961017); one file per core | EDC, EDML, NGRIP, TALDICE, Vostok | `age_ice_aicc2023`, `age_gas_aicc2023` and their `_sd`, `age_ice_aicc2012`, `age_gas_aicc2012`, `acc`, `thinning`, `lid`, `delta_depth` (profiles along `depth`) | to 813 ka (EDC) |

The records are time series at fixed sites (featureType timeSeries, dimension `station`,
with `lat`, `lon`, `site_name`, and `z_srf` where the source gives it); the AICC2023
files are profiles along depth (featureType profile). `time` is in years before 1950 CE
(units "years ago"), on the time scale of the source (in the comment of `time`); ages b2k
(before 2000 CE) are converted by subtracting 50. Water isotopes are in ‰ (units
`1e-3`); temperature anomalies `tas_anom` are relative to the present (see each source).

`time_aicc2023`: the records of EDC, EDML, TALDICE, Vostok and NGRIP with depths also
have the ages on AICC2023 (Bouchet et al., 2023), interpolated linearly in depth in the
AICC2023 table of the core (`IceCores-AICC2023-<core>`); missing outside the table. WAIS
Divide has AICC2023 ages from the WAIS Divide-EDC tie points of AICC2023 (10-57 ka).

## Licences

| Source | Licence |
|---|---|
| Jouzel et al. (2007), Petit et al. (1999), Uemura et al. (2018), Buizert et al. (2018) | NOAA NCEI open data, no licence stated; publishing assumed to be allowed |
| EPICA Community Members (2006), Stenni et al. (2011) on AICC2012, Lambert et al. (2012) | CC BY 3.0 (PANGAEA) |
| Rasmussen et al. (2014), Seierstad et al. (2014) | No licence stated (Centre for Ice and Climate); publishing assumed to be allowed |
| Bouchet et al. (2023), AICC2023 | CC BY 4.0 (PANGAEA) |
| WAIS Divide Project Members (2015), data of E. Steig | CC BY-NC 4.0 (USAP-DC) |
| Kindler et al. (2014) | CC BY 3.0 (Clim. Past supplement) |
| Gkinis et al. (2020) | CC BY 4.0 (PANGAEA) |
| Vinther et al. (2009) | NOAA NCEI open data, no licence stated; publishing assumed to be allowed |

## Making the dataset

```bash
julia fesmdata.jl record IceCores
```

prepares the missing sources (`<Source>/prepare.jl`), checks the prepared files and
copies them to `$FESMDATA_PRODUCTS/Records/IceCores/` with their text forms
(`--overwrite` to replace them). The sources with AICC2023 ages prepare
`Bouchet2023_AICC2023` first if needed.
