# Prepare the PMIP3 (CMIP5) lgm, midHolocene and piControl ocean and sea-ice climatologies on
# a common regular 1° grid (shared/cmip_ocean.jl), one file per model and experiment,
# $FESMDATA_PREPARED/PMIP3_cmip5/PMIP3_<model>_<experiment>_ocean.nc: the monthly SST
# (Omon tos) and sea-ice concentration (OImon sic) climatologies of the last 100 years with
# the extent mask and the hemispheric sea-ice extent (with fx areacello), the annual mean
# potential temperature at standard depths of the last 30 years (Omon thetao), and the
# Atlantic overturning streamfunction of the last 100 years (Omon msftmyz). A field without
# data is left out and named in the global attribute `missing`. The models and pools: models.jl.
#
# Usage (on Albedo, with cdo):
#     source shared/machines/albedo.env; module load cdo
#     julia --project=PMIP3_cmip5 PMIP3_cmip5/prepare_ocean.jl [model ...]

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "cmip_climatology.jl"))
include(joinpath(@__DIR__, "..", "shared", "cmip_ocean.jl"))
include(joinpath(@__DIR__, "models.jl"))

const NYEARS_THETAO = 30

"The ocean and sea-ice files of a run (see ocean_fields)."
function ocean_sources(m, experiment)
    mem = member(m, experiment)
    # areacello of the run, else of the other experiments (the same grid, checked by latitude)
    area = reduce(vcat, [cmip5_files(m, e, "fx", "fx", "areacello", fxmember(m, e))
                         for e in [experiment; filter(!=(experiment), experiments(m))]])
    return Dict{String,Any}(
        "tos" => cmip5_files(m, experiment, "mon", "Omon", "tos", mem),
        "sic" => cmip5_files(m, experiment, "mon", "OImon", "sic", mem), "sic_name" => "sic",
        "thetao" => cmip5_files(m, experiment, "mon", "Omon", "thetao", mem),
        "msft" => cmip5_files(m, experiment, "mon", "Omon", "msftmyz", mem), "msft_name" => "msftmyz",
        "areacello" => area)
end

function prepare(m, experiment, outdir, workdir)
    src = ocean_sources(m, experiment)
    datafiles = [src["tos"]; src["sic"]; src["thetao"]; src["msft"]]
    if isempty(datafiles)
        println("$(m.model) $experiment: no ocean or sea-ice data ($(member(m, experiment))) in the pools, skipped")
        return
    end
    println("$(m.model) $experiment")
    fields, missing_ = ocean_fields(src, workdir; nyears=NYEARS, nyears_thetao=NYEARS_THETAO)
    refs = NCDataset(ds -> get(ds.attrib, "references", ""), first(datafiles))
    path = joinpath(outdir, "PMIP3_$(m.model)_$(experiment)_ocean.nc")
    rm(path; force=true)
    write_ocean(path, fields, [
        "title" => "PMIP3 $(m.model) $experiment ocean and sea-ice climatology on a regular 1° grid",
        "model" => m.model, "experiment" => experiment, "ensemble_member" => member(m, experiment),
        "references" => "$PROTOCOL; $(m.model): $refs",
        "license" => LICENSE,
        "missing" => join(missing_, ","),
        "original_data" => join(unique(dirname.(datafiles)), " "),
        provenance_attrib("paleoclimate")...])
    println("Wrote $path", isempty(missing_) ? "" : ", missing: $(join(missing_, ", "))")
end

if abspath(PROGRAM_FILE) == @__FILE__
    Sys.which("cdo") === nothing && error("cdo not found (on Albedo: module load cdo)")
    outdir = prepared_dir("PMIP3_cmip5")
    mkpath(outdir)
    mkpath(fesmdata_dir("work"))
    workdir = mktempdir(fesmdata_dir("work"))
    for (m, experiment) in selection(ARGS)
        prepare(m, experiment, outdir, workdir)
    end
end
