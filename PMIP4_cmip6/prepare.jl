# Prepare the PMIP4 (CMIP6) lgm, midHolocene and piControl climatologies for remapping:
# monthly, annual, DJF and JJA means of tas and pr over the last 100 years of each run
# (Amon), with the orography and the land and ice fractions (fx) of the experiment, one file
# per model and experiment on the model's own lon-lat grid,
# $FESMDATA_PREPARED/PMIP4_cmip6/PMIP4_<model>_<experiment>.nc. A missing variable or fx field
# is left out of the file and named in its global attribute `missing`.
#
# The CMIP6 files are read from the pools in $CMIP6_POOL (':'-separated, searched in order:
# the DKRZ pool /pool/data/CMIP6/data on Levante by default; on Albedo the AWI pool and its
# esgf/ tree, shared/machines/albedo.env); of each variable the latest readable version.
#
# Usage:
#     julia --project=PMIP4_cmip6 PMIP4_cmip6/prepare.jl [model ...]
#     julia fesmdata.jl remap $FESMDATA_PREPARED/PMIP4_cmip6/PMIP4_INM-CM4-8_lgm.nc all --name=PMIP4-INM-CM4-8-lgm

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "cmip_climatology.jl"))

"CMIP6 data pools (<activity>/<institution>/<model>/<experiment>/<member>/<table>/<variable>/<grid>/<version>), ':'-separated."
const POOLS = pool_roots("CMIP6_POOL", "/pool/data/CMIP6/data")

# The models, their member per experiment (`member`: one for all, or per experiment) and the
# ESGF data DOIs of their experiments (10.22033/ESGF/CMIP6.<n>) with the first author of each
# data citation (none given: the file's further_info_url only). CESM2-FV2 and CESM2-WACCM-FV2:
# lgm only, with the matching physics (i2p2) of their piControl.
const MODELS = [
    (institution="AWI", model="AWI-ESM-1-1-LR", member="r1i1p1f1", year=2020,
     doi=Dict("lgm" => (9330, "Shi, X."), "midHolocene" => (9332, "Shi, X."), "piControl" => (9335, "Danek, C."))),
    (institution="INM", model="INM-CM4-8", member="r1i1p1f1", year=2019,
     doi=Dict("lgm" => (5075, "Volodin, E."), "midHolocene" => (5077, "Volodin, E."), "piControl" => (5080, "Volodin, E."))),
    (institution="MIROC", model="MIROC-ES2L", member="r1i1p1f2", year=2019,
     doi=Dict("lgm" => (5644, "Ohgaito, R."), "midHolocene" => (5646, "Ohgaito, R."), "piControl" => (5710, "Hajima, T."))),
    (institution="MPI-M", model="MPI-ESM1-2-LR", member="r1i1p1f1", year=2019,
     doi=Dict("lgm" => (6642, "Jungclaus, J."), "midHolocene" => (6644, "Jungclaus, J."), "piControl" => (6675, "Wieners, K.-H."))),
    (institution="NCAR", model="CESM2-FV2", member="r1i2p2f1", year=2022, doi=Dict{String,Tuple{Int,String}}(),
     experiments=["lgm", "piControl"]),
    (institution="NCAR", model="CESM2-WACCM-FV2", member="r1i2p2f1", year=2022, doi=Dict{String,Tuple{Int,String}}(),
     experiments=["lgm", "piControl"]),
]
const EXPERIMENTS = ["lgm" => "PMIP", "midHolocene" => "PMIP", "piControl" => "CMIP"]
const NYEARS = 100      # climatology over the last NYEARS years (all years if fewer)

const PROTOCOL =
    "Kageyama, M., Braconnot, P., Harrison, S. P., et al.: The PMIP4 contribution to CMIP6 - " *
    "Part 1: Overview and over-arching analysis plan, Geosci. Model Dev., 11, 1033-1057, 2018, " *
    "doi:10.5194/gmd-11-1033-2018"

"Files of a variable: the only grid and the latest version that is readable in one of the pools ([] if none)."
function cmip6_files(activity, m, experiment, table, var)
    cands = Tuple{String,Vector{String}}[]
    for pool in POOLS
        dir = joinpath(pool, activity, m.institution, m.model, experiment, m.member, table, var)
        isdir(dir) || continue
        grids = readdir(dir)
        length(grids) == 1 || error("$dir: more than one grid ($grids)")
        dir = joinpath(dir, only(grids))
        for v in filter(v -> isdir(joinpath(dir, v)), readdir(dir))
            push!(cands, (v, filter(endswith(".nc"), readdir(joinpath(dir, v); join=true))))
        end
    end
    return latest_version(cands)
end

function read_fx(activity, m, experiment, var)
    fs = cmip6_files(activity, m, experiment, "fx", var)
    isempty(fs) && return nothing
    NCDataset(ds -> (ds["lon"][:], ds["lat"][:], Float64.(coalesce.(ds[var][:, :], NaN))), only(fs))
end

function prepare(m, experiment, activity, outdir)
    tasfiles = cmip6_files(activity, m, experiment, "Amon", "tas")
    prfiles = cmip6_files(activity, m, experiment, "Amon", "pr")
    if isempty(tasfiles)
        println("$(m.model) $experiment: no tas ($(m.member)) in the pools, skipped")
        return
    end
    missing_ = String[]
    # tas and pr over the same years: the last NYEARS that both cover (pool versions may differ in length)
    y1 = isempty(prfiles) ? last_complete_year(tasfiles) : min(last_complete_year(tasfiles), last_complete_year(prfiles))
    tas, days, years = monthly_climatology(tasfiles, "tas", NYEARS; y1)
    pr = nothing
    if isempty(prfiles)
        push!(missing_, "pr")
    else
        pr, _, years_pr = monthly_climatology(prfiles, "pr", NYEARS; y1)
        years == years_pr || error("$(m.model) $experiment: tas and pr cover different years")
    end
    fields, monthly = tp_fields(tas, pr, days)

    lon, lat, license, furtherinfo = NCDataset(first(tasfiles)) do ds
        ds["lon"][:], ds["lat"][:], ds.attrib["license"], ds.attrib["further_info_url"]
    end
    fx = Dict(v => read_fx(activity, m, experiment, v) for v in ("orog", "sftlf", "sftgif"))
    for (v, x) in fx
        x === nothing && (push!(missing_, v); continue)
        same_grid(x[1], lon) && same_grid(x[2], lat) || error("$(m.model) $experiment: $v not on the grid of tas")
    end
    fx["orog"] === nothing || push!(fields, ("z_srf", fx["orog"][3], "m", "surface altitude (orography of the experiment)"))
    if fx["sftlf"] !== nothing
        sftlf = fx["sftlf"][3]
        push!(fields, ("f_land", sftlf ./ 100, "1", "land area fraction"))
        if fx["sftgif"] !== nothing
            # No land ice where there is no land (MIROC-ES2L leaves sftgif missing there)
            sftgif = fx["sftgif"][3]
            sftgif[isnan.(sftgif) .& (sftlf .== 0)] .= 0
            push!(fields, ("f_ice", sftgif ./ 100, "1", "land ice area fraction"))
        end
    elseif fx["sftgif"] !== nothing
        push!(fields, ("f_ice", fx["sftgif"][3] ./ 100, "1", "land ice area fraction"))
    end

    yrs = "$(years[1])-$(years[2])"
    path = joinpath(outdir, "PMIP4_$(m.model)_$(experiment).nc")
    cite = if haskey(m.doi, experiment)
        n, author = m.doi[experiment]
        doi = "10.22033/ESGF/CMIP6.$n"
        ["references" => "$PROTOCOL; $author et al.: $(m.institution) $(m.model) model output " *
                         "prepared for CMIP6 $activity $experiment, Earth System Grid Federation, " *
                         "$(m.year), doi:$doi", "doi" => doi]
    else
        ["references" => "$PROTOCOL; $(m.institution) $(m.model) model output prepared for CMIP6 " *
                         "$activity $experiment, Earth System Grid Federation, $(m.year), $furtherinfo"]
    end
    write_climatology(path, lon, lat, fields, monthly, [
        "title" => "PMIP4 $(m.model) $experiment climatology (years $yrs of the simulation)",
        "model" => m.model, "experiment" => experiment, "variant_label" => m.member, "years" => yrs,
        cite..., "license" => license, "further_info_url" => furtherinfo,
        "missing" => join(missing_, ","),
        "original_data" => join(unique(dirname.([tasfiles; prfiles])), " "),
        provenance_attrib("paleoclimate")...])
    println("Wrote $path ($yrs)", isempty(missing_) ? "" : ", missing: $(join(missing_, ", "))")
end

outdir = prepared_dir("PMIP4_cmip6")
mkpath(outdir)
for m in filter(m -> isempty(ARGS) || m.model in ARGS, MODELS), (experiment, activity) in EXPERIMENTS
    experiment in get(m, :experiments, first.(EXPERIMENTS)) || continue
    prepare(m, experiment, activity, outdir)
end
