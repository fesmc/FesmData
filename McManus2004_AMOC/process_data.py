import sys
import re
import numpy as np
import xarray as xr


def read_numeric_block(lines, start_idx, ncols):
    rows = []
    i = start_idx
    while i < len(lines):
        parts = lines[i].split()
        if len(parts) != ncols:
            if parts: 
                break
            i += 1
            continue
        try:
            rows.append([float(p) for p in parts])
        except ValueError:
            break
        i += 1
    return np.array(rows), i


def parse_mcmanus2004(path_txt):
    with open(path_txt, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    idx_pa_th = next(i for i, l in enumerate(lines) if re.match(r"\s*Age\s+Pa/Th238", l))
    pa_th_data, _ = read_numeric_block(lines, idx_pa_th + 1, ncols=5)

    idx_d18o = next(i for i, l in enumerate(lines) if re.match(r"\s*Age\s+G\. inflata", l))
    d18o_data, _ = read_numeric_block(lines, idx_d18o + 1, ncols=2)

    return pa_th_data, d18o_data


def build_dataset(pa_th_data, d18o_data):
    ds = xr.Dataset(
        data_vars=dict(
            pa_th238=("age_pa_th", pa_th_data[:, 1]),
            error238=("age_pa_th", pa_th_data[:, 2]),
            pa_th232=("age_pa_th", pa_th_data[:, 3]),
            error232=("age_pa_th", pa_th_data[:, 4]),
            d18O=("age_d18o", d18o_data[:, 1]),
        ),
        coords=dict(
            age_pa_th=("age_pa_th", pa_th_data[:, 0]),
            age_d18o=("age_d18o", d18o_data[:, 0]),
        ),
    )

    ds["age_pa_th"].attrs = dict(long_name="Age (Pa/Th record)", units="kyr BP")
    ds["age_d18o"].attrs = dict(long_name="Age (d18O record)", units="kyr BP")
    ds["pa_th238"].attrs = dict(long_name="231Pa/230Th (238-based age model)", units="")
    ds["error238"].attrs = dict(long_name="Error de pa_th238", units="")
    ds["pa_th232"].attrs = dict(long_name="231Pa/230Th (232-based age model)", units="")
    ds["error232"].attrs = dict(long_name="Error de pa_th232", units="")
    ds["d18O"].attrs = dict(long_name="G. inflata delta-18O", units="permil (VPDB)")

    ds.attrs = dict(
        title="North Atlantic Core GGC5 231Pa/230Th Meridional Circulation Data",
        source_core="OCE326-GGC5",
        location="33 42' N, 57 35' W, 4550 m water depth, Bermuda Rise",
        original_reference=(
            "McManus, J.F., R. Francois, J.-M. Gherardi, L.D. Keigwin, and S. Brown-Leger. 2004. "
            "Collapse and rapid resumption of Atlantic meridional circulation linked to deglacial "
            "climate changes. Nature, Vol. 428, pp. 834-837. doi:10.1038/nature02494"
        ),
        original_data_url="https://www.ncei.noaa.gov/pub/data/paleo/contributions_by_author/mcmanus2004/mcmanus2004.txt",
    )

    return ds


def main():
    path_in = sys.argv[1] if len(sys.argv) > 1 else "mcmanus2004.txt"
    path_out = sys.argv[2] if len(sys.argv) > 2 else "mcmanus2004.nc"

    pa_th_data, d18o_data = parse_mcmanus2004(path_in)
    ds = build_dataset(pa_th_data, d18o_data)
    ds.to_netcdf(path_out)


if __name__ == "__main__":
    main()