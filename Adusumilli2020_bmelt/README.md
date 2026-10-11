# Basal melt rates of Antarctic ice shelves (Adusumilli et al., 2020)

Basal melt rates of the Antarctic ice shelves averaged over 2010-2018, from CryoSat-2
radar altimetry, satellite-derived velocities and a firn model, on a 500 m polar
stereographic grid (EPSG:3031), with their uncertainty. From:

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
`$DATAMANIFEST_DATASETS_DIR/adusumilli2020/`:

- `ANT_iceshelf_melt_rates_CS2_2010-2018_v0.h5` (2.5 GB, datamanifest key
  `adusumilli2020_melt`): `w_b`, the 2010-2018 mean melt rate where there are
  CryoSat-2 data; `w_b_interp`, only where `w_b` is missing, the mean rate at the same
  ice draft elsewhere on the ice shelf; `w_b_uncert`, the uncertainty; m yr-1 ice
  equivalent, positive for melting;
- `ANT_iceshelf_height_changes_RA_1994_2018_v0.h5` (731 MB, key `adusumilli2020_height`):
  surface height change from radar altimetry (ERS-1, ERS-2, Envisat, CryoSat-2),
  firn air content change and surface mass balance, quarterly 1992-2018 on a 10 km
  grid, from which the article derives melt rates 1994-2018. Not used yet.

## Prepare and remap

```bash
julia --project=Adusumilli2020_bmelt Adusumilli2020_bmelt/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Adusumilli2020_bmelt/Adusumilli2020_BMELT_2010-2018.nc Antarctica --name=BasalMelt-Adusumilli2020
```

`prepare.jl` writes, on the original grid, to
`$FESMDATA_WORK/prepared/Adusumilli2020_bmelt/Adusumilli2020_BMELT_2010-2018.nc` (see
`Remap/README.md`), in m yr-1 ice equivalent, positive for melting:

- `bmelt`: `w_b`, with `w_b_interp` where `w_b` is missing (1.49 million km2 of ice
  shelves, 1211 Gt yr-1 in total);
- `bmelt_cs2`: `w_b` only (1.41 million km2, 874 Gt yr-1);
- `bmelt_err`: `w_b_uncert` (missing in most of the cells of `w_b_interp`).

The melt rates are already in ice equivalent (917 kg m-3) with the sign of the article,
so they are not converted.
