# Prepare the PMIP4 (CMIP6) lgm, midHolocene and piControl ocean and sea-ice climatologies on
# a common regular 1° grid (shared/cmip_ocean.jl), one file per model and experiment,
# $FESMDATA_PREPARED/PMIP4_cmip6/PMIP4_<model>_<experiment>_ocean.nc: the monthly SST
# (Omon tos) and sea-ice concentration (SImon siconc, else siconca) climatologies of the last
# 100 years with the extent mask and the hemispheric sea-ice extent (with Ofx areacello), the
# annual mean potential temperature at standard depths of the last 30 years (Omon thetao), and
# the Atlantic overturning streamfunction of the last 100 years (Omon msftmz, else msftyz). A
# field without data is left out and named in the global attribute `missing`. The models and
# pools: models.jl.
#
# Usage (on Albedo, with cdo):
#     source shared/machines/albedo.env; module load cdo
#     julia --project=PMIP4_cmip6 PMIP4_cmip6/prepare_ocean.jl [model ...]

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "cmip_climatology.jl"))
include(joinpath(@__DIR__, "..", "shared", "cmip_ocean.jl"))
include(joinpath(@__DIR__, "models.jl"))

const NYEARS_THETAO = 30
"Grid labels in order of preference: the native grid first."
const GRIDS = ["gn", "gr", "gr1", "gr2", "grz", "gr1z", "gr2z"]

"The ocean and sea-ice files of a run (see ocean_fields)."
function ocean_sources(m, experiment, activity)
    files(table, var; grids=GRIDS) = cmip6_files(activity, m, experiment, table, var; grids)
    src = Dict{String,Any}("tos" => files("Omon", "tos"))
    src["sic_name"] = isempty(files("SImon", "siconc")) ? "siconca" : "siconc"
    src["sic"] = files("SImon", src["sic_name"])
    # thetao on depth levels (NorESM2-LM: gr, its gn is on density levels)
    src["thetao"] = String[]
    for g in GRIDS
        fs = files("Omon", "thetao"; grids=[g])
        if !isempty(fs) && is_depth_axis(first(fs), "thetao")
            src["thetao"] = fs
            break
        end
    end
    src["msft_name"] = isempty(files("Omon", "msftmz")) ? "msftyz" : "msftmz"
    src["msft"] = files("Omon", src["msft_name"])
    # areacello on the grid of the sea ice (CESM2 midHolocene: a gr file in the gn dataset)
    grid = isempty(src["sic"]) ? "gn" : basename(dirname(dirname(first(src["sic"]))))
    area = filter(f -> endswith(f, "_$grid.nc"), files("Ofx", "areacello"; grids=[grid]))
    src["areacello"] = isempty(area) ? nothing : only(area)
    return src
end

function prepare(m, experiment, activity, outdir, workdir)
    src = ocean_sources(m, experiment, activity)
    datafiles = [src["tos"]; src["sic"]; src["thetao"]; src["msft"]]
    if isempty(datafiles)
        println("$(m.model) $experiment: no ocean or sea-ice data ($(member(m, experiment))) in the pools, skipped")
        return
    end
    println("$(m.model) $experiment")
    fields, missing_ = ocean_fields(src, workdir; nyears=NYEARS, nyears_thetao=NYEARS_THETAO)
    license, furtherinfo = NCDataset(first(datafiles)) do ds
        ds.attrib["license"], ds.attrib["further_info_url"]
    end
    path = joinpath(outdir, "PMIP4_$(m.model)_$(experiment)_ocean.nc")
    rm(path; force=true)
    write_ocean(path, fields, [
        "title" => "PMIP4 $(m.model) $experiment ocean and sea-ice climatology on a regular 1° grid",
        "model" => m.model, "experiment" => experiment, "variant_label" => member(m, experiment),
        citation(m, experiment, activity, furtherinfo)..., "license" => license, "further_info_url" => furtherinfo,
        "missing" => join(missing_, ","),
        "original_data" => join(unique(dirname.(datafiles)), " "),
        provenance_attrib("paleoclimate")...])
    println("Wrote $path", isempty(missing_) ? "" : ", missing: $(join(missing_, ", "))")
end

if abspath(PROGRAM_FILE) == @__FILE__
    Sys.which("cdo") === nothing && error("cdo not found (on Albedo: module load cdo)")
    outdir = prepared_dir("PMIP4_cmip6")
    mkpath(outdir)
    mkpath(fesmdata_dir("work"))
    workdir = mktempdir(fesmdata_dir("work"))
    for (m, experiment, activity) in selection(ARGS)
        prepare(m, experiment, activity, outdir, workdir)
    end
end
