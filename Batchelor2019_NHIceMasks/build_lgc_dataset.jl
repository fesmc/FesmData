#
# Build the last-glacial-cycle subset of the Batchelor et al. (2019) ice masks
# with a real time axis, for use as transient forcing.
#
# Reads `Batchelor2019_ice_masks.nc` (index time axis, 18 slices, see
# `build_lonlat_dataset.jl`) and writes `Batchelor2019_ice_masks_lgc.nc` with
# the slices from MIS 6 to the LGM on a time axis in years relative to present
# (negative = before present). The ages per slice are documented in
# `time_slices.md`. The LGM slice is repeated at -21000 yr so that the LGM
# extent is held from 26.5 ka (the paper's LGM age) to 21 ka (PMIP LGM).
#
# Run:
#
#     julia --project=. build_lgc_dataset.jl
#
cd(@__DIR__)
import Pkg; Pkg.activate(".")

using NCDatasets

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

const PATH_IN  = "Batchelor2019_ice_masks.nc"
const PATH_OUT = "Batchelor2019_ice_masks_lgc.nc"

# (label in PATH_IN, assigned age in years relative to present), oldest first.
# See time_slices.md for the rationale.
const SLICES = [
    ("MIS 6",  -140000.0),
    ("MIS 5d", -112000.0),
    ("MIS 5c", -100000.0),
    ("MIS 5b",  -88000.0),
    ("MIS 5a",  -80000.0),
    ("MIS 4",   -65000.0),
    ("45 ka",   -45000.0),
    ("40 ka",   -40000.0),
    ("35 ka",   -35000.0),
    ("30 ka",   -30000.0),
    ("LGM",     -26500.0),
    ("LGM",     -21000.0),   # LGM extent held until the PMIP LGM date
]

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

function build_lgc_dataset(; path_in=PATH_IN, path_out=PATH_OUT, slices=SLICES)

    ds_in  = NCDataset(path_in, "r")
    labels = ds_in["label"][:]
    lon    = ds_in["lon"][:]
    lat    = ds_in["lat"][:]
    nt     = length(slices)

    times = [t for (_, t) in slices]
    issorted(times) || error("assigned ages must be increasing")

    isfile(path_out) && rm(path_out)
    ds = NCDataset(path_out, "c")
    try
        ds.attrib["source"]  = ds_in.attrib["source"]
        ds.attrib["title"]   = "Batchelor et al. (2019) NH ice masks, last glacial cycle (MIS 6 to LGM)"
        ds.attrib["history"] = "build_lgc_dataset.jl: subset of $(path_in) with assigned ages (see time_slices.md)"

        defDim(ds, "lon",  length(lon))
        defDim(ds, "lat",  length(lat))
        defDim(ds, "time", nt)

        v = defVar(ds, "lon", Float32, ("lon",), attrib = Dict(
            "standard_name" => "longitude", "long_name" => "longitude",
            "units" => "degrees_east", "axis" => "X"))
        v[:] = lon
        v = defVar(ds, "lat", Float32, ("lat",), attrib = Dict(
            "standard_name" => "latitude", "long_name" => "latitude",
            "units" => "degrees_north", "axis" => "Y"))
        v[:] = lat
        v = defVar(ds, "time", Float64, ("time",), attrib = Dict(
            "standard_name" => "time",
            "long_name" => "time relative to present (negative = before present)",
            "units" => "years", "axis" => "T"))
        v[:] = times

        labelvar = defVar(ds, "label", String, ("time",))
        maskvar  = defVar(ds, "mask", Int8, ("lon","lat","time"), attrib = Dict(
            "long_name" => "Ice mask (1=ice,0=no ice)"))

        for (k, (label, t)) in enumerate(slices)
            idx = findfirst(==(label), labels)
            idx === nothing && error("label not found in $(path_in): $(label)")
            maskvar[:, :, k]  = ds_in["mask"][:, :, idx]
            labelvar[k]       = label
            println("  slice $(k)/$(nt): $(label) -> $(t) yr (from index $(idx))")
        end
    finally
        close(ds)
        close(ds_in)
    end

    println("Wrote ", path_out)
    return path_out
end

build_lgc_dataset()
