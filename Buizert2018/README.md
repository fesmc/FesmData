# Temperature reconstruction from 10 to 120 kyr b2k from the NGRIP ice core

Source: [https://agupubs.onlinelibrary.wiley.com/doi/full/10.1002/2017GL075601](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1002/2017GL075601)

Citation: Buizert, C., Keisling, B. A., Box, J. E., He, F., Carlson, A. E., Sinclair, G., & DeConto, R. M. (2018). Greenland‐wide seasonal temperatures during the last deglaciation. Geophysical Research Letters, 45(4), 1905-1914.


## Download the supplementary data

Download the supplementary data [here](https://agupubs.onlinelibrary.wiley.com/action/downloadSupplement?doi=10.1002%2F2017GL075601&file=grl56971-sup-0002-supinfo.xlsx).

## Download the reconstruction data

Source: [https://www.ncei.noaa.gov/pub/data/paleo/reconstructions/buizert2018/](https://www.ncei.noaa.gov/pub/data/paleo/reconstructions/buizert2018/)

1. Get the data here:

```bash
wget https://www.ncei.noaa.gov/pub/data/paleo/reconstructions/buizert2018/GLand_1981-2010_baseline_12282016.nc
wget https://www.ncei.noaa.gov/pub/data/paleo/reconstructions/buizert2018/GLand_22ka_recon_Buizert_20161228.nc # 4 Gb!
```

2. Since the reconstruction file is so big (4 Gb), I like to make a smaller file for prototyping things locally. In that case, use `ncks`:

```bash
# Get ~200 years of transient data until present day
ncks -d time,2000,2206 GLand_22ka_recon_Buizert_20161228.nc GLand_22ka_recon_Buizert_only200yrs.nc
```

These data files are on a lat-lon grid, but only contain regional points around Greenland to reduce their overall size. They can be mapped online to the grid of interest.

