# CHELSA-TraCE21k v1.0 (Karger et al., 2023)

The transient TraCE-21ka simulation of the last deglaciation (CCSM3), downscaled to 30
arc seconds (about 1 km) with the CHELSA method and a paleo-orography that includes the
ice sheets and sea level of each time step: monthly climatologies of the near-surface air
temperature (daily maximum and minimum) and of the precipitation for 221 centennial time
steps from the Last Glacial Maximum to the present, with the orography and the glacier
layers of each step, here over the Pyrenees:

Karger, D. N., Nobis, M. P., Normand, S., Graham, C. H., and Zimmermann, N. E.:
CHELSA-TraCE21k - high-resolution (1 km) downscaled transient temperature and
precipitation data since the Last Glacial Maximum, Clim. Past, 19, 439-456, 2023,
[doi:10.5194/cp-19-439-2023](https://doi.org/10.5194/cp-19-439-2023).

Data: CHELSA-TraCE21k, EnviDat,
[doi:10.16904/envidat.211](https://doi.org/10.16904/envidat.211).

## Licence

The EnviDat record states CC BY-SA 4.0, the CHELSA website CC0 1.0; the stricter is
recorded (global attribute `license`): derived products must keep the ShareAlike terms,
as the PMIP4 products of Paleoclimate.

## Original data

Global Cloud-Optimized GeoTIFFs on `https://os.zhdk.cloud.switch.ch/chelsav1/chelsa_trace/`,
one per variable, month and time step, about 6-7 TB in all:

| Folder | Files | Variable, storage |
|---|---|---|
| `tasmax/`, `tasmin/` | `CHELSA_TraCE21k_<var>_<month>_<id>_V1.0.tif` (month 1-12, not zero-padded) | daily maximum and minimum temperature, monthly mean: K x 10 (uint16, no scale metadata) |
| `pr/` | `CHELSA_TraCE21k_pr_<month>_<id>_V1.0.tif` | precipitation, monthly sum: kg m-2 month-1 (uint16) |
| `orog/` | `CHELSA_TraCE21k_dem_<id>_V1.0.tif` | paleo-orography (m, int16, no data over the sea) |
| `orog/` | `CHELSA_TraCE21k_gle_<id>_V1.0.tif` | glacier extent (uint8: 1 ice, no data elsewhere) |
| `orog/` | `CHELSA_TraCE21k_glz_<id>_V1.0.tif` | glacier surface elevation (m, int16, only over glaciers) |

with the time IDs `<id>` = -200, ..., 20. The data set has also the lapse rate `tz` (on
the TraCE-21ka grid, about 3.75°), bioclimatic variables (`bio/`) and the forcing of the
downscaling (`input/`), not used here.

They are not downloaded: `prepare.jl` reads only the box 2.5°W-3.5°E, 41.3-44°N of each
file through GDAL `/vsicurl/` (`gdal_translate -projwin`), the PYR domain with a margin
of at least 0.4°, with parallel requests (threads), and keeps the clipped GeoTIFFs (721 x
325 cells; 8,619 files, about 1 GB) in the storage folder of the datamanifest entry
`chelsa_trace21k`. Files already clipped are kept, so an interrupted run can be resumed.

## Prepare and remap

On a node with internet access (the requests take about an hour with 16 threads):

```bash
julia -t 16 --project=Karger2023_chelsatrace21k Karger2023_chelsatrace21k/prepare.jl
julia -t 8 fesmdata.jl remap Paleoclimate CHELSA-TraCE21k
julia fesmdata.jl remap Paleoclimate CHELSA-TraCE21k-LGM-ice
```

`prepare.jl` writes to `$FESMDATA_PREPARED/Karger2023_chelsatrace21k/`:

- `Karger2023_CHELSA-TraCE21k_Pyrenees.nc`: `tas`, `tasmax`, `tasmin` (K) and `pr`
  (kg m-2 d-1, the monthly sum divided by the mean length of the month, February 28.25
  days) on (lon, lat, month, time); `dem`, `glz` (m) and `gle` (0/1) on (lon, lat, time);
  `time` in years before 1950 CE and `time_id`, the ID of the files;
- `Karger2023_CHELSA-TraCE21k-LGM-ice_Pyrenees.nc`: `mask_ice` (0/1), the glacier
  extent `gle` of the first step (ID -200, the Last Glacial Maximum), on (lon, lat).

## Notes

- **Time.** The IDs are taken as centuries of the calendar: -200 is 20,000 BCE (21,950
  years before 1950 CE, about the start of TraCE-21ka at 22 ka), 19 is 1900 CE and 20 is
  2000 CE; `time = 1950 - 100 id`, in years before 1950 CE. This follows the span of
  TraCE-21ka (22 ka to 1990 CE); the documentation of the data set does not state it.
- **Temperature.** `tas` is the mean of `tasmax` and `tasmin` (no mean temperature in
  the data set). The temperatures refer to the paleo-orography `dem` of each step
  (over the LGM ice of the Pyrenees, they correlate best with `dem`: r = -0.92, -3.7 K
  km-1 in July), which partly includes the ice: up to about 900 m higher than today at
  the LGM. Reduce them to a common surface with a lapse rate before taking differences
  between steps, and take the precipitation as a ratio.
- **Glacier layers.** `gle` is the glacier extent of the downscaling, 1 where the
  simulated ice surface is above the paleo-terrain (Karger et al., 2023), and `glz`
  the glacier surface elevation, smoother than `dem` (over the LGM ice of the Pyrenees,
  `glz - dem` is -34 m on average, from -1249 to +433 m). The present-day glaciers of
  the last steps are much larger than the real ones (a coarse inventory).
- **Missing files.** July of step -13 (`tasmax`, `tasmin`) is not on the server: it is
  interpolated linearly in time between steps -12 and -14 (listed in the global attribute
  `comment`).
- **Other domains.** The same script can clip any other box (`BOX`), e.g. for other
  mountain-glacier domains; the global files at 1 km (6-7 TB) are not prepared.
