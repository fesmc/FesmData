#!/usr/bin/env python3
"""Download monthly-averaged ERA5 data from the Copernicus CDS.

Two datasets, both monthly-averaged reanalysis on a regular 2.5x2.5 deg
lat-lon grid, NetCDF, over 1991-2020 (30 years x 12 months = 360 timesteps):

  - reanalysis-era5-pressure-levels-monthly-means  (all 37 pressure levels)
  - reanalysis-era5-single-levels-monthly-means

The CDS monthly-means products only serve per-year-month means; there is no
native 1991-2020 climatology. So we download all 30 years here and collapse to
the 12-month climatology on ingest (see README.md, `cdo ymonmean`).

Downloads one NetCDF file per variable. Existing files are skipped, so the
script is safely restartable (CDS requests queue and can take a while).

Requires cdsapi and a configured ~/.cdsapirc (see README.md).

Examples
--------
  # Everything (both datasets, tiers 1 and 2)
  python download_era5.py

  # Tier 1 only (radiation stack) -- minimal set to unblock building/validating
  python download_era5.py --tier 1

  # Just the pressure-level fields, tier 2
  python download_era5.py --dataset pressure --tier 2

  # Show the requests that would be sent, download nothing
  python download_era5.py --dry-run

  # Skip the optional wind components (u, v)
  python download_era5.py --no-optional
"""

import argparse
import os
import sys

# --- fixed request settings ---------------------------------------------------

OUTDIR = os.path.expanduser("~/data/era5")

YEARS = [str(y) for y in range(1991, 2021)]          # 1991-2020 inclusive
MONTHS = [f"{m:02d}" for m in range(1, 13)]          # 01-12
GRID = [2.5, 2.5]                                    # regular lat-lon, deg
PRODUCT_TYPE = "monthly_averaged_reanalysis"
TIME = "00:00"

# All 37 ERA5 pressure levels (hPa), 1000 -> 1.
PRESSURE_LEVELS = [
    "1000", "975", "950", "925", "900", "875", "850", "825", "800", "775",
    "750", "700", "650", "600", "550", "500", "450", "400", "350", "300",
    "250", "225", "200", "175", "150", "125", "100", "70", "50", "30",
    "20", "10", "7", "5", "3", "2", "1",
]

# --- variable manifest --------------------------------------------------------
# Each entry: (cds_variable_name, short_name, optional)

MANIFEST = {
    "pressure": {
        "dataset": "reanalysis-era5-pressure-levels-monthly-means",
        "subdir": "monthly-pressure-levels",
        "tiers": {
            # Tier 1: radiation
            1: [
                ("temperature", "t", False),
                ("specific_humidity", "q", False),
                ("ozone_mass_mixing_ratio", "o3", False),
                ("geopotential", "z", False),
            ],
            # Tier 2: clouds + moist stack
            2: [
                ("fraction_of_cloud_cover", "cc", False),
                ("specific_cloud_liquid_water_content", "clwc", False),
                ("specific_cloud_ice_water_content", "ciwc", False),
                ("relative_humidity", "r", False),
                ("u_component_of_wind", "u", True),
                ("v_component_of_wind", "v", True),
            ],
        },
    },
    "single": {
        "dataset": "reanalysis-era5-single-levels-monthly-means",
        "subdir": "monthly-single-levels",
        "tiers": {
            # Tier 1: surface state + flux validation targets
            1: [
                # surface state
                ("surface_pressure", "sp", False),
                ("skin_temperature", "skt", False),
                ("2m_temperature", "t2m", False),
                ("geopotential", "z", False),          # invariant -> orography
                ("land_sea_mask", "lsm", False),
                ("forecast_albedo", "fal", False),
                # TOA fluxes
                ("top_net_thermal_radiation", "ttr", False),          # -> OLR
                ("top_net_solar_radiation", "tsr", False),
                ("toa_incident_solar_radiation", "tisr", False),
                # surface fluxes
                ("surface_net_thermal_radiation", "str", False),
                ("surface_net_solar_radiation", "ssr", False),
                ("surface_thermal_radiation_downwards", "strd", False),
                ("surface_solar_radiation_downwards", "ssrd", False),
                # clear-sky fluxes (cloud radiative effect = all-sky - clear-sky)
                ("top_net_thermal_radiation_clear_sky", "ttrc", False),
                ("top_net_solar_radiation_clear_sky", "tsrc", False),
                ("surface_net_thermal_radiation_clear_sky", "strc", False),
                ("surface_net_solar_radiation_clear_sky", "ssrc", False),
                ("surface_thermal_radiation_downward_clear_sky", "strdc", False),
                ("surface_solar_radiation_downward_clear_sky", "ssrdc", False),
            ],
            # Tier 2: moist stack + surface
            2: [
                ("total_precipitation", "tp", False),
                ("evaporation", "e", False),
                ("total_column_water_vapour", "tcwv", False),
                ("total_cloud_cover", "tcc", False),
                ("surface_sensible_heat_flux", "sshf", False),
                ("surface_latent_heat_flux", "slhf", False),
                ("sea_ice_cover", "siconc", False),
                ("snow_depth", "sd", False),
            ],
        },
    },
}


def build_request(kind, variable):
    """Build the CDS retrieve() request dict for one variable."""
    req = {
        "product_type": [PRODUCT_TYPE],
        "variable": [variable],
        "year": YEARS,
        "month": MONTHS,
        "time": [TIME],
        "grid": GRID,
        "data_format": "netcdf",
        "download_format": "unarchived",
    }
    if kind == "pressure":
        req["pressure_level"] = PRESSURE_LEVELS
    return req


def target_path(kind, short_name):
    subdir = MANIFEST[kind]["subdir"]
    fname = f"era5_{subdir}_{short_name}_{YEARS[0]}-{YEARS[-1]}.nc"
    return os.path.join(OUTDIR, subdir, fname)


def selected_jobs(datasets, tiers, include_optional):
    """Yield (kind, dataset_id, variable, short_name, target) for each download."""
    for kind in datasets:
        dataset_id = MANIFEST[kind]["dataset"]
        for tier in tiers:
            for variable, short_name, optional in MANIFEST[kind]["tiers"][tier]:
                if optional and not include_optional:
                    continue
                yield kind, dataset_id, variable, short_name, target_path(kind, short_name)


def main():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument(
        "--dataset", choices=["pressure", "single", "both"], default="both",
        help="Which dataset(s) to download (default: both).",
    )
    p.add_argument(
        "--tier", choices=["1", "2", "all"], default="all",
        help="Variable tier: 1 (radiation), 2 (clouds/moist), or all (default).",
    )
    p.add_argument(
        "--no-optional", action="store_true",
        help="Skip variables flagged optional (u, v wind components).",
    )
    p.add_argument(
        "--dry-run", action="store_true",
        help="Print the requests that would be sent and exit; download nothing.",
    )
    p.add_argument(
        "--force", action="store_true",
        help="Re-download even if the target file already exists.",
    )
    args = p.parse_args()

    datasets = ["pressure", "single"] if args.dataset == "both" else [args.dataset]
    tiers = [1, 2] if args.tier == "all" else [int(args.tier)]
    include_optional = not args.no_optional

    jobs = list(selected_jobs(datasets, tiers, include_optional))
    print(f"Planned downloads: {len(jobs)} variable file(s)")
    print(f"Output root: {OUTDIR}\n")

    if not args.dry_run:
        try:
            import cdsapi
        except ImportError:
            sys.exit(
                "ERROR: cdsapi not installed. Run `pip install cdsapi` and "
                "configure ~/.cdsapirc (see README.md)."
            )
        client = cdsapi.Client()

    for kind, dataset_id, variable, short_name, target in jobs:
        req = build_request(kind, variable)
        if args.dry_run:
            print(f"[{kind}] {variable} -> {target}")
            print(f"    dataset: {dataset_id}")
            print(f"    request: {req}\n")
            continue

        if os.path.exists(target) and not args.force:
            print(f"SKIP (exists): {target}")
            continue

        os.makedirs(os.path.dirname(target), exist_ok=True)
        print(f"GET  {dataset_id} :: {variable}")
        print(f"  -> {target}")
        client.retrieve(dataset_id, req, target)

    print("\nDone.")


if __name__ == "__main__":
    main()
