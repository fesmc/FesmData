# Basal melt rates and height changes of Antarctic ice shelves (Adusumilli et al., 2020)

Two data sets of the Antarctic ice shelves, on polar stereographic grids (EPSG:3031):

- basal melt rates averaged over 2010-2018, from CryoSat-2 radar altimetry,
  satellite-derived velocities and a firn model, on a 500 m grid, with their
  uncertainty;
- quarterly height changes 1992-2018 from four radar altimeters (ERS-1, ERS-2, Envisat,
  CryoSat-2), with the firn air content and surface mass balance needed to derive
  melt rates from them, on a 10 km grid. These are **height changes, not melt
  rates** (see below).

From:

Adusumilli, S., Fricker, H. A., Medley, B., Padman, L., and Siegfried, M. R.:
Interannual variations in meltwater input to the Southern Ocean from Antarctic ice
shelves, Nat. Geosci., 13, 616-620, 2020,
[doi:10.1038/s41561-020-0616-z](https://doi.org/10.1038/s41561-020-0616-z).

Data: Adusumilli, S., Fricker, H. A., Medley, B. C., Padman, L., and Siegfried, M. R.:
Data from: Interannual variations in meltwater input to the Southern Ocean from
Antarctic ice shelves, UC San Diego Library Digital Collections, 2020,
[doi:10.6075/J04Q7SHT](https://doi.org/10.6075/J04Q7SHT). Code to read them:
<https://github.com/sioglaciology/ice_shelf_change>.

## Licence

CC BY 4.0 (UC San Diego Library).

## Original data

From the UC San Diego Library (no login), downloaded by `prepare.jl` into
`$FESMDATA_SOURCES/adusumilli2020/`:

- `ANT_iceshelf_melt_rates_CS2_2010-2018_v0.h5` (2.5 GB, datamanifest key
  `adusumilli2020_melt`): `w_b`, the 2010-2018 mean melt rate where there are
  CryoSat-2 data; `w_b_interp`, only where `w_b` is missing, the mean rate at the same
  ice draft elsewhere on the ice shelf; `w_b_uncert`, the uncertainty; m yr-1 ice
  equivalent, positive for melting;
- `ANT_iceshelf_height_changes_RA_1994_2018_v0.h5` (731 MB, key `adusumilli2020_height`):
  `h_alt`, `h_firn`, `smb_discharge`, `uncert_alt`, `uncert_firn` every 0.25 yr from
  1992.41 to 2018.91 (decimal years), on 12001 cells of 10 km.

## Prepare and remap

```bash
julia --project=Adusumilli2020_bmelt Adusumilli2020_bmelt/prepare.jl
julia fesmdata.jl remap $FESMDATA_PREPARED/Adusumilli2020_bmelt/Adusumilli2020_BMELT_2010-2018.nc Antarctica --name=BasalMelt-Adusumilli2020
julia fesmdata.jl remap $FESMDATA_PREPARED/Adusumilli2020_bmelt/Adusumilli2020_HEIGHTS_1992-2018.nc Antarctica --name=BasalMelt-Adusumilli2020-heights
```

`prepare.jl` writes two files to `$FESMDATA_PREPARED/Adusumilli2020_bmelt/` (see
`Remap/README.md`), on the original grids.

`Adusumilli2020_BMELT_2010-2018.nc`, in m yr-1 ice equivalent, positive for melting:

- `bmelt`: `w_b`, with `w_b_interp` where `w_b` is missing (1.49 million km2 of ice
  shelves, 1211 Gt yr-1 in total);
- `bmelt_cs2`: `w_b` only (1.41 million km2, 874 Gt yr-1);
- `bmelt_err`: `w_b_uncert` (missing in most of the cells of `w_b_interp`).

The melt rates are already in ice equivalent (917 kg m-3) with the sign of the article,
so they are not converted.

`Adusumilli2020_HEIGHTS_1992-2018.nc`, the fields of the file as they are, on
`(x, y, time)`:

- `dh_alt` (m): `h_alt`, the change of the ice-shelf surface height from altimetry,
  relative to 1994 (0 at 1994.16);
- `dh_firn` (m): `h_firn`, the change of the firn air content (GSFC-FDMv0), relative
  to 1994;
- `smb_discharge` (m yr-1 ice equivalent): precipitation minus evaporation (MERRA-2),
  plus the change of ice discharge for the Amundsen Sea ice shelves only.

The uncertainties of the file, `uncert_alt` (height change from altimetry) and
`uncert_firn` (from firn modelling), are left out: in the file (version v0) they are
identical to each other, `uncert_alt` is the same in every quarter, and both have the
units of a rate ("m of ice equivalent per year") rather than of a height change.

`time` is in days since 1992-01-01, from the decimal years of the file (the middle of
each quarter), with bounds (`time_bnds`) halfway between them.

**Melt rates from the height changes.** The article derives time series of melt rates
(its Eq. S7) as anomalies relative to the 2010-2018 mean:
w_b,anom(t) = M_anom − ρw / (ρw − ρi) (dh_anom/dt − dh_air,anom/dt) − ∇·(H v)_anom,
with ρw = 1028 and ρi = 917 kg m-3, the rates of change of `dh_alt` and `dh_firn`,
M the surface mass balance (here `smb_discharge`, which includes the discharge term
∇·(H v)_anom of the Amundsen Sea), and adds them to the 2010-2018 mean `bmelt`. The
ice-equivalent thickness change is (`dh_alt` − `dh_firn`) ρw / (ρw − ρi). The rates
need a time derivative and smoothing: the article filters the shelf-averaged series
(a gradient and smoothing operator), and differences of single quarters or years of
the gridded fields are noisy. FesmData does not derive them.
