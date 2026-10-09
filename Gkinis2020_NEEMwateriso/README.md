# NEEM ice core high-resolution water isotopes (Gkinis et al., 2020)

High-resolution (0.05 m) δ¹⁸O and δD from the NEEM ice core, Greenland,
covering ~8–129 ka b2k.

Source: [PANGAEA https://doi.org/10.1594/PANGAEA.925552](https://doi.org/10.1594/PANGAEA.925552) (CC-BY-4.0)

Citation: Gkinis, V. et al. (2020): *NEEM ice core High Resolution (0.05m) Water
Isotope Ratios (18O/16O, 2H/1H) covering 8-129 ky b2k*. PANGAEA.
Supplement to Gkinis et al. (2021), *Sci. Data* 8, 141,
https://doi.org/10.1038/s41597-021-00916-9.

## Build

```bash
julia --project=. build_neem_dataset.jl              # default: GICC05 timescale
julia --project=. build_neem_dataset.jl AICC2012     # alternative deep timescale
```

The script downloads the tab-delimited source (cached as `NEEM_Gkinis2020.tab`)
and produces:

| File | Dimension | Contents |
|---|---|---|
| `NEEM_water_isotopes_depth.nc` | `depth` (m) | every source column as a series along depth, incl. all three raw age scales |
| `NEEM_water_isotopes_time.nc`  | `time` (a)  | rows resorted to be monotonic in the chosen timescale |
| `NEEM_d18O.png` | — | δ¹⁸O vs depth (top) and vs time (bottom) |

## Timescale

The source provides three age columns that each cover only part of the core:

| Column | Depth coverage | Age range |
|---|---|---|
| GICC05 (counted) | 1210.50–1955.90 m | ~8–60 ka b2k |
| GICC05_modelext | 1955.95 m → deep | ~60 ka b2k → |
| AICC2012 | 1955.95 m → deep | ~60 ka b2k → |

No single column spans the whole core, so a continuous age is built from the
counted **GICC05** for the shared upper part plus a user-chosen deep scale below:

- `GICC05` **(default)** → GICC05 (shallow) + GICC05_modelext (deep)
- `AICC2012` → GICC05 (shallow) + AICC2012 (deep)

Pass the choice as the first argument (see Build above). The deepest folded ice
has no age on any scale; those rows are **dropped from the time file** (count
reported at run time) but retained in the depth file.

## Time convention

`time` is in years relative to `reference_year = 2000` CE (the b2k datum),
negative before present: `time = -(age in years)`. Data in the time file are
sorted so `time` increases (oldest first).
