# Prepare the Antarctic ice-shelf data of Adusumilli et al. (2020) for remapping, as
# prepared NetCDF files in $FESMDATA_WORK/prepared/Adusumilli2020_bmelt/, on their
# original polar stereographic grids:
#
#     Adusumilli2020_BMELT_2010-2018.nc    basal melt rates, mean 2010-2018 (500 m), and
#                                          their uncertainty, m yr-1 ice equivalent,
#                                          positive for melting
#     Adusumilli2020_HEIGHTS_1992-2018.nc  quarterly height changes (10 km): surface
#                                          height and firn air content (m, relative to
#                                          1994), surface mass balance and discharge
#                                          changes (m yr-1 ice equivalent); not melt rates
#
# Usage:
#     julia --project=Adusumilli2020_bmelt Adusumilli2020_bmelt/prepare.jl

import HDF5: h5open   # not `using`: HDF5 also exports read_dataset (DataManifest)
using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))

const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

const REFERENCES = "Adusumilli, S., Fricker, H. A., Medley, B., Padman, L., and Siegfried, M. R.: " *
                   "Interannual variations in meltwater input to the Southern Ocean from Antarctic " *
                   "ice shelves, Nat. Geosci., 13, 616-620, 2020, doi:10.1038/s41561-020-0616-z; " *
                   "data: UC San Diego Library Digital Collections, doi:10.6075/J04Q7SHT"

const TIME_UNITS = "days since 1992-01-01 00:00:00"

"Define the grid (x, y in m, ascending) and the grid mapping."
function def_grid(ds, x, y)
    issorted(x) && issorted(y) || error("x or y not ascending")
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic",
                                             "proj_params" => PROJ, "epsg_code" => "EPSG:3031"])
end

"Write a field as Float32 (NaN for missing)."
function write_field(ds, name, A, dims, units, long_name; chunks=nothing)
    kw = isnothing(chunks) ? (;) : (; chunksizes=chunks)
    defVar(ds, name, Float32.(A), dims; fillvalue=NaN32, deflatelevel=1, kw...,
           attrib=["units" => units, "long_name" => long_name, "grid_mapping" => "crs"])
end

function global_attrib(ds, title, comment)
    ds.attrib["title"] = title
    ds.attrib["references"] = REFERENCES
    ds.attrib["doi"] = "10.6075/J04Q7SHT"
    ds.attrib["license"] = "CC BY 4.0"
    ds.attrib["comment"] = comment
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("basalmelt"))
end

"Days since 1992-01-01 of a decimal year (fraction of the actual length of the year)."
function days(t)
    y = floor(Int, t)
    t0 = DateTime(y)
    t1 = t0 + Millisecond(round(Int, (t - y) * Dates.value(DateTime(y + 1) - t0)))
    return Dates.value(t1 - DateTime(1992)) / 86_400_000
end

# --- Melt rates, mean 2010-2018 ---------------------------------------------------------

function prepare_mean()
    input = download_dataset(manifest(), "adusumilli2020_melt")
    path = joinpath(prepared_dir("Adusumilli2020_bmelt"), "Adusumilli2020_BMELT_2010-2018.nc")
    mkpath(dirname(path))
    h5open(input) do src
        # The file was written in C order as (y, x): read in Julia as (x, y)
        x = vec(read(src["x"]))
        y = vec(read(src["y"]))
        w_b = read(src["w_b"])                  # CryoSat-2, NaN where there are no data
        w_b_interp = read(src["w_b_interp"])    # only where w_b is missing
        size(w_b) == (length(x), length(y)) || error("unexpected size $(size(w_b)) of w_b")
        dims, chunks = ("x", "y"), [1024, 1024]
        NCDataset(path, "c") do ds
            def_grid(ds, x, y)
            write_field(ds, "bmelt", ifelse.(isfinite.(w_b), w_b, w_b_interp), dims, "m yr-1",
                        "basal melt rate of ice shelves, mean 2010-2018 (positive for melting), ice equivalent; " *
                        "CryoSat-2, gaps filled with the mean rate at the same ice draft on the same ice shelf";
                        chunks)
            write_field(ds, "bmelt_cs2", w_b, dims, "m yr-1",
                        "basal melt rate of ice shelves, mean 2010-2018 (positive for melting), ice equivalent; " *
                        "CryoSat-2 only"; chunks)
            w_b = w_b_interp = nothing
            write_field(ds, "bmelt_err", read(src["w_b_uncert"]), dims, "m yr-1",
                        "uncertainty of the basal melt rate, ice equivalent"; chunks)
            global_attrib(ds, "Basal melt rates of Antarctic ice shelves, 2010-2018 mean (Adusumilli et al., 2020)",
                          "From ANT_iceshelf_melt_rates_CS2_2010-2018_v0.h5 (version v0): bmelt is w_b, " *
                          "with w_b_interp where w_b is missing; bmelt_cs2 is w_b; bmelt_err is w_b_uncert")
        end
    end
    println("Wrote $path")
end

# --- Height changes, quarterly 1992-2018 ------------------------------------------------

function prepare_heights()
    input = download_dataset(manifest(), "adusumilli2020_height")
    path = joinpath(prepared_dir("Adusumilli2020_bmelt"), "Adusumilli2020_HEIGHTS_1992-2018.nc")
    mkpath(dirname(path))
    h5open(input) do src
        # x and y are 2D (meshgrid) in the file, (x, y) in Julia; fields (x, y, time)
        X, Y = read(src["x"]), read(src["y"])
        x, y = X[:, 1], Y[1, :]
        all(X .== x) && all(Y .== y') || error("x, y of $input not a regular grid")
        t = vec(read(src["time"]))                    # decimal years, every 0.25 yr
        h_alt = read(src["h_alt"])
        size(h_alt) == (length(x), length(y), length(t)) || error("unexpected size $(size(h_alt)) of h_alt")
        dims = ("x", "y", "time")
        NCDataset(path, "c") do ds
            def_grid(ds, x, y)
            defVar(ds, "time", days.(t), ("time",);
                   attrib=["units" => TIME_UNITS, "calendar" => "standard", "standard_name" => "time",
                           "long_name" => "time (middle of the quarter)", "bounds" => "time_bnds"])
            # bounds halfway between the times (the quarters are contiguous)
            edges = days.([t[1] - 0.125; (t[1:end-1] .+ t[2:end]) ./ 2; t[end] + 0.125])
            defVar(ds, "time_bnds", permutedims(hcat(edges[1:end-1], edges[2:end])), ("nv", "time");
                   attrib=["units" => TIME_UNITS, "calendar" => "standard"])
            write_field(ds, "dh_alt", h_alt, dims, "m",
                        "change of the ice-shelf surface height from radar altimetry, relative to 1994")
            write_field(ds, "dh_firn", read(src["h_firn"]), dims, "m",
                        "change of the firn air content (GSFC-FDMv0), relative to 1994")
            write_field(ds, "smb_discharge", read(src["smb_discharge"]), dims, "m yr-1",
                        "surface mass balance (precipitation minus evaporation, MERRA-2) plus the change " *
                        "of ice discharge (Amundsen Sea ice shelves only), ice equivalent")
            # uncert_alt and uncert_firn are left out: in the v0 file they are identical,
            # uncert_alt is the same in every quarter, and both have units of a rate
            global_attrib(ds, "Height changes of Antarctic ice shelves, quarterly 1992-2018 (Adusumilli et al., 2020)",
                          "From ANT_iceshelf_height_changes_RA_1994_2018_v0.h5 (version v0), as they are: " *
                          "height changes, not basal melt rates. dh_alt, dh_firn are h_alt, h_firn (0 in " *
                          "1994.16); smb_discharge. The uncertainties uncert_alt and uncert_firn are left " *
                          "out (identical, constant in time and in units of a rate in the file). Times are " *
                          "the decimal years of the file (every 0.25 yr), bounds halfway between them.")
        end
    end
    println("Wrote $path")
end

prepare_mean()
prepare_heights()
