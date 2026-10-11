# Prepare the Antarctic ice-shelf basal melt rates of Adusumilli et al. (2020) for
# remapping: the 500 m grid of the 2010-2018 mean melt rates from CryoSat-2
# (ANT_iceshelf_melt_rates_CS2_2010-2018_v0.h5) as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/Adusumilli2020_bmelt/Adusumilli2020_BMELT_2010-2018.nc, with
# the melt rate and its uncertainty in m yr-1 ice equivalent (positive for melting).
#
# Usage:
#     julia --project=Adusumilli2020_bmelt Adusumilli2020_bmelt/prepare.jl

import HDF5: h5open   # not `using`: HDF5 also exports read_dataset (DataManifest)
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))

const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

const REFERENCES = "Adusumilli, S., Fricker, H. A., Medley, B., Padman, L., and Siegfried, M. R.: " *
                   "Interannual variations in meltwater input to the Southern Ocean from Antarctic " *
                   "ice shelves, Nat. Geosci., 13, 616-620, 2020, doi:10.1038/s41561-020-0616-z; " *
                   "data: UC San Diego Library Digital Collections, doi:10.6075/J04Q7SHT"

"Write a field (x, y) of melt rates as Float32, NaN for missing."
function write_field(ds, name, A, long_name)
    defVar(ds, name, Float32.(A), ("x", "y"); fillvalue=NaN32, deflatelevel=1, chunksizes=[1024, 1024],
           attrib=["units" => "m yr-1", "long_name" => long_name, "grid_mapping" => "crs"])
end

input = download_dataset(manifest(), "adusumilli2020_melt")

path = joinpath(prepared_dir("Adusumilli2020_bmelt"), "Adusumilli2020_BMELT_2010-2018.nc")
mkpath(dirname(path))
h5open(input) do src
    # The file was written in C order as (y, x): read in Julia as (x, y), x and y ascending
    x = vec(read(src["x"]))
    y = vec(read(src["y"]))
    issorted(x) && issorted(y) || error("x or y of $input not ascending")
    w_b = read(src["w_b"])                  # CryoSat-2, NaN where there are no data
    w_b_interp = read(src["w_b_interp"])    # only where w_b is missing
    size(w_b) == (length(x), length(y)) || error("unexpected size $(size(w_b)) of w_b")

    NCDataset(path, "c") do ds
        defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
        defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
        defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic",
                                                 "proj_params" => PROJ, "epsg_code" => "EPSG:3031"])
        write_field(ds, "bmelt", ifelse.(isfinite.(w_b), w_b, w_b_interp),
                    "basal melt rate of ice shelves, mean 2010-2018 (positive for melting), ice equivalent; " *
                    "CryoSat-2, gaps filled with the mean rate at the same ice draft on the same ice shelf")
        write_field(ds, "bmelt_cs2", w_b,
                    "basal melt rate of ice shelves, mean 2010-2018 (positive for melting), ice equivalent; " *
                    "CryoSat-2 only")
        w_b = w_b_interp = nothing
        write_field(ds, "bmelt_err", read(src["w_b_uncert"]),
                    "uncertainty of the basal melt rate, ice equivalent")
        ds.attrib["title"] = "Basal melt rates of Antarctic ice shelves, 2010-2018 mean (Adusumilli et al., 2020)"
        ds.attrib["references"] = REFERENCES
        ds.attrib["doi"] = "10.6075/J04Q7SHT"
        ds.attrib["license"] = "CC BY 4.0"
        ds.attrib["comment"] = "From ANT_iceshelf_melt_rates_CS2_2010-2018_v0.h5 (version v0): bmelt is w_b, " *
                               "with w_b_interp where w_b is missing; bmelt_cs2 is w_b; bmelt_err is w_b_uncert"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("basalmelt"))
    end
end
println("Wrote $path")
