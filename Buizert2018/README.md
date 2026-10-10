# Greenland seasonal temperatures, 22 ka to present (Buizert et al., 2018)

Monthly surface air temperature and precipitation over Greenland from 22 ka to present,
in decadal steps, on a 0.5° x 0.25° lon-lat grid (96°W-0°, 58-85°N). Ice-core
temperature reconstructions are merged with the transient TraCE-21ka simulation and
added to a 1981-2010 baseline climatology. From:

Buizert, C., Keisling, B. A., Box, J. E., He, F., Carlson, A. E., Sinclair, G., and
DeConto, R. M.: Greenland-wide seasonal temperatures during the last deglaciation,
Geophys. Res. Lett., 45, 1905-1914, 2018,
[doi:10.1002/2017GL075601](https://doi.org/10.1002/2017GL075601).

Data: NOAA/WDS Paleoclimatology, Greenland 22,000 Year Seasonal Temperature
Reconstructions, NOAA NCEI, [doi:10.25921/psvs-yg80](https://doi.org/10.25921/psvs-yg80).

## Licence

NOAA NCEI open data: no licence is stated and there are no restrictions on use; NCEI
asks to cite the publication and the dataset (with the date accessed). We assume the
data and derived products may be published.

The supplementary file of the article (below) is published by AGU under the Wiley
standard terms, not under an open licence.

## Original data

From the NCEI archive, https://www.ncei.noaa.gov/pub/data/paleo/reconstructions/buizert2018/
(no login), downloaded by `prepare.jl` (datamanifest keys `buizert2018_recon`,
`buizert2018_baseline`):

- `GLand_22ka_recon_Buizert_20161228.nc` (4.6 GB): the reconstruction, `TS2` (K) and
  `PRECIP` (m s-1 water equivalent) on (time, month, c, r), and `DEM` (m), 2207 time
  steps;
- `GLand_1981-2010_baseline_12282016.nc`: the 1981-2010 baseline climatology (`TS2`,
  `PRECIP`, `DEM`), on the same grid.

The archive also has RCP2.6, 4.5 and 8.5 projections (`GLand_RCP*_12282016.nc`), not
used here.

For prototyping, a short subset of the reconstruction can be made with `ncks`, e.g. the
last ~200 years:

```bash
ncks -d time,2000,2206 GLand_22ka_recon_Buizert_20161228.nc GLand_22ka_recon_Buizert_only200yrs.nc
```

### Site time series (supplement)

`grl56971-sup-0002-supinfo.xlsx` (in this folder) is the supplementary data of the
article: annual and seasonal (DJF, MAM, JJA, SON) temperatures (°C), -50 to 21,990 yr BP
every 20 years, at ice-core sites (NEEM, NGRIP, GISP2, Dye-3, ReCAP/Renland, Agassiz,
Hans Tausen, Camp Century, EGRIP) and ice-margin sites, without corrections for ice
flow or elevation change. It is a time series at points, not a gridded product, and is
not prepared. To get it again:

```bash
wget "https://agupubs.onlinelibrary.wiley.com/action/downloadSupplement?doi=10.1002%2F2017GL075601&file=grl56971-sup-0002-supinfo.xlsx"
```

The same series are in `buizert2018.xlsx`, `buizert2018cores.txt` and
`buizert2018margin.txt` in the NCEI archive.

## Prepare and remap

```bash
julia --project=Buizert2018 Buizert2018/prepare.jl
julia -t 16 fesmdata.jl remap $FESMDATA_WORK/prepared/Buizert2018/Buizert2018.nc GRL-16KM GRL-32KM --name=Paleoclimate-Buizert2018
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Buizert2018/Buizert2018_1981-2010.nc Greenland --name=Paleoclimate-Buizert2018_1981-2010
```

`prepare.jl` writes to `$FESMDATA_WORK/prepared/Buizert2018/` (see `Remap/README.md`):

- `Buizert2018.nc`: `tas` (K) and `pr` (kg m-2 s-1) on (lon, lat, month, time), and
  `z_srf` (m), 3.7 GB;
- `Buizert2018_1981-2010.nc`: the baseline climatology, `tas` and `pr` on (lon, lat,
  month), and `z_srf`.

Notes:

- `time` is the age in years BP (before 1950 CE), 22005 to -55 (2005 CE), oldest first,
  at the centres of decades. In the original file, `TIME` is in years relative to 1950,
  negative in the past (`YEAR_CE` = `TIME` + 1950), although the NCEI readme calls it
  years before present.
- `pr` is `PRECIP` converted from m s-1 water equivalent to kg m-2 s-1 (x 1000). It
  has small negative values in places (down to about -2e-6 kg m-2 s-1), kept as they are.
- `z_srf` is the present-day DEM of the reconstruction (`DEM`, the same in both files),
  with values down to -30 m over the ocean.
- Anomalies relative to 1981-2010 are the difference to `Buizert2018_1981-2010.nc`
  (for `pr`, the ratio), remapped on the same grid. (The v1 files `CLIM-RECON-B18` had
  temperature anomalies relative to the last time step, 2005 CE, about 1 K warmer than
  1981-2010 on average.)
- The grid covers 96°W to 0° and 58-85°N: the corners of the Greenland domain (east of
  0° towards Svalbard, west of 96°W) are left missing (`f_valid` < 1).
- The remapped time series are large (12 months x 2207 time steps): about 0.4 GB per
  file on GRL-32KM, 1.5 GB on GRL-16KM, 6 GB on GRL-8KM and 24 GB on GRL-4KM
  (compressed), so only the coarse grids are made.
