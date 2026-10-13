# Prepare the hybrid ice masks of the last glacial cycle for remapping: the ice area
# fractions of Batchelor et al. (2019) in the Northern Hemisphere and of PaleoMIST 1.0
# (Gowan et al., 2021) in the Southern Hemisphere, for the Batchelor time slices from
# MIS 5a (80 ka) to the LGM, on a global 0.1° lon-lat grid, in one prepared NetCDF file,
# $FESMDATA_PREPARED/Batchelor2019_PaleoMIST_lgc/Batchelor2019_PaleoMIST_LGC.nc, with
# f_ice_best, f_ice_min and f_ice_max on (lon, lat, time). It replaces
# Batchelor2019_ice_masks_lgc.nc (v1, Batchelor2019_NHIceMasks/build_lgc_dataset.jl).
#
# Made from the prepared files of Batchelor2019_NHIceMasks and Gowan2021_PaleoMIST1.0,
# which are prepared first if they are missing.
#
# Usage:
#     julia -t 16 --project=Batchelor2019_PaleoMIST_lgc Batchelor2019_PaleoMIST_lgc/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_PREPARED/Batchelor2019_PaleoMIST_lgc/Batchelor2019_PaleoMIST_LGC.nc Global

using FesmUtils
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))

const NH = ("Batchelor2019_NHIceMasks", "Batchelor2019_NH_ICE.nc")
const SH = ("Gowan2021_PaleoMIST1.0", "Gowan2021_PaleoMIST.nc")

# Time slices (labels of the Batchelor file) and their time (years before 1950,
# time_slices.md); the LGM extent is held until 21 ka (the PMIP LGM), as in v1.
const SLICES = [("MIS 5a", 80_000), ("MIS 4", 65_000), ("45 ka", 45_000), ("40 ka", 40_000), ("35 ka", 35_000),
                ("30 ka", 30_000), ("LGM", 26_500), ("LGM", 21_000)]

const FIELDS = ["f_ice_best", "f_ice_min", "f_ice_max"]
const D = 0.1              # degrees
const NSUB = 5             # samples per cell side from the 2 km Batchelor grid

"Prepared file of a source, prepared first if it is missing."
function prepared(source, file)
    path = joinpath(prepared_dir(source), file)
    if !isfile(path)
        dir = joinpath(REPO_DIR, source)
        run(`$(Base.julia_cmd()) --project=$dir -e "import Pkg; Pkg.instantiate()"`)
        run(`$(Base.julia_cmd()) --project=$dir $(joinpath(dir, "prepare.jl"))`)
    end
    return path
end

"PaleoMIST time nearest to `t` (ties to the older)."
nearest(times, t) = times[argmin([(abs(s - t), -s) for s in times])]

g = LonLatGrid("GLOBAL-0.1DEG", D)
nx, ny = size(g)
nh = g.lat .> 0                      # the cell edges are at the equator
nt = length(SLICES)
out = Dict(f => zeros(Float32, nx, ny, nt) for f in FIELDS)

# Northern Hemisphere: Batchelor, remapped conservatively (sampled); 0 (no ice) outside
# its grid, which covers all its outlines
NCDataset(prepared(NH...)) do ds
    src = ProjGrid("Batchelor2019", ds["x"].var[:], ds["y"].var[:], ds["crs"].attrib["proj_params"])
    labels = ds["label"][:]
    m = SampledMap(g, src, NSUB)
    for (k, (label, _)) in enumerate(SLICES), f in FIELDS
        F, fv = remap(m, ds[f].var[:, :, findfirst(==(label), labels)])
        out[f][:, nh, k] = ifelse.(fv[:, nh] .> 0, F[:, nh], 0f0)
    end
end

# Southern Hemisphere: PaleoMIST f_ice at the nearest time, remapped conservatively (exact)
paleomist_time = Float64[]
NCDataset(prepared(SH...)) do ds
    lat = ds["lat"].var[:]
    src = LonLatGrid(ds["lon"].var[:], lat)
    times = ds["time"].var[:]
    m = AlignedMap(g, src)
    for (k, (_, t)) in enumerate(SLICES)
        ts = nearest(times, t)
        push!(paleomist_time, ts)
        F, _ = remap(m, ds["f_ice"].var[:, :, findfirst(==(ts), times)])
        for f in FIELDS
            out[f][:, .!nh, k] = F[:, .!nh]
        end
    end
end

path = joinpath(prepared_dir("Batchelor2019_PaleoMIST_lgc"), "Batchelor2019_PaleoMIST_LGC.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", g.lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", g.lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "time", Float64[t for (_, t) in SLICES], ("time",);
           attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)",
                   "comment" => "Batchelor et al. (2019) time slices at the ages of " *
                                "Batchelor2019_NHIceMasks/time_slices.md; the LGM is repeated at 21000"])
    defVar(ds, "label", String[l for (l, _) in SLICES], ("time",);
           attrib=["long_name" => "time slice of Batchelor et al. (2019) (Northern Hemisphere)"])
    defVar(ds, "time_paleomist", paleomist_time, ("time",);
           attrib=["units" => "years ago", "long_name" => "time of PaleoMIST used in the Southern Hemisphere",
                   "comment" => "the PaleoMIST time nearest to time (ties to the older)"])
    for (f, est) in zip(FIELDS, ("best-estimate", "minimum", "maximum"))
        defVar(ds, f, out[f], ("lon", "lat", "time"); deflatelevel=1, shuffle=true,
               attrib=["units" => "1", "long_name" => "ice area fraction, $est extent in the Northern Hemisphere",
                       "comment" => "Northern Hemisphere: Batchelor et al. (2019) ($est extent; the LGM has only a " *
                                    "best estimate); Southern Hemisphere: PaleoMIST 1.0 (the same for best, min and max)"])
    end
    ds.attrib["title"] = "Ice masks of the last glacial cycle, 80-21 ka: Batchelor et al. (2019) in the Northern " *
                         "Hemisphere and PaleoMIST 1.0 (Gowan et al., 2021) in the Southern Hemisphere"
    ds.attrib["references"] = "Batchelor, C. L. et al.: The configuration of Northern Hemisphere ice sheets through the " *
                              "Quaternary, Nat. Commun., 10, 3713, 2019, doi:10.1038/s41467-019-11601-2; Gowan, E. J. et " *
                              "al.: A new global ice sheet reconstruction for the past 80 000 years, Nat. Commun., 12, " *
                              "1199, 2021, doi:10.1038/s41467-021-21469-w (data: doi:10.1594/PANGAEA.905800)"
    ds.attrib["doi"] = "10.1038/s41467-019-11601-2"
    ds.attrib["license"] = "Batchelor et al. (2019): no licence stated for the shapefiles (OSF project 7jen3), article " *
                           "CC BY 4.0; PaleoMIST 1.0: CC BY 4.0 (PANGAEA)"
    ds.attrib["comment"] = "Split at the equator. Northern Hemisphere: $(NH[2]) remapped conservatively ($(NSUB)x$(NSUB) " *
                           "samples per cell), 0 outside its grid; Southern Hemisphere: f_ice of $(SH[2]) remapped " *
                           "conservatively"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
end
println("Wrote $path")
println("PaleoMIST times: ", Dict(t => s for ((_, t), s) in zip(SLICES, paleomist_time)))
