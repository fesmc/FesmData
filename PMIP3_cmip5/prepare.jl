# Prepare the PMIP3 (CMIP5) lgm, midHolocene and piControl climatologies for remapping:
# monthly, annual, DJF and JJA means of tas and pr over the last 100 years of each run
# (Amon), with the orography and the land and ice fractions (fx) of the experiment, one
# file per model and experiment on the model's own lon-lat grid,
# $FESMDATA_PREPARED/PMIP3_cmip5/PMIP3_<model>_<experiment>.nc (the same form as PMIP4_cmip6).
#
# The CMIP5 files are read from pools laid out as the ESGF dataset ids,
# <pool>/<institute>/<model>/<experiment>/<frequency>/<realm>/<table>/<member>/<version>/,
# $CMIP5_POOL a ':'-separated list of pools (shared/machines/albedo.env: the AWI pool
# p_pool_clim_data and its esgf/ tree, where CMIP/esgf_fetch.py adds missing files, see
# README.md). Of each variable the latest version whose files are all readable is taken. A
# missing variable or fx field is left out of the file and named in its global attribute `missing`.
#
# Usage (on Albedo):
#     source shared/machines/albedo.env
#     julia --project=PMIP3_cmip5 PMIP3_cmip5/prepare.jl [model ...]

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "cmip_climatology.jl"))

const POOLS = pool_roots("CMIP5_POOL", "/albedo/work/projects/p_pool_clim_data/cmip5/output1:" *
                                      "/albedo/work/projects/p_pool_clim_data/esgf/cmip5/output1")

# The PMIP3 models, their ensemble member per experiment (r1i1p1 unless given) and fx member
# (r0i0p0 unless given). GISS-E2-R lgm: physics version p150 (as PMIP3_cvdp).
const MODELS = [
    (institute="NCAR", model="CCSM4"),
    (institute="CNRM-CERFACS", model="CNRM-CM5"),
    (institute="LASG-CESS", model="FGOALS-g2"),
    (institute="NASA-GISS", model="GISS-E2-R", member=Dict("lgm" => "r1i1p150"), fxmember=Dict("lgm" => "r0i0p150")),
    (institute="IPSL", model="IPSL-CM5A-LR"),
    (institute="MIROC", model="MIROC-ESM"),
    (institute="MPI-M", model="MPI-ESM-P"),
    (institute="MRI", model="MRI-CGCM3"),
]
const EXPERIMENTS = ["lgm", "midHolocene", "piControl"]
const NYEARS = 100      # climatology over the last NYEARS years (all years if fewer)

member(m, e) = get(get(m, :member, Dict{String,String}()), e, "r1i1p1")
fxmember(m, e) = get(get(m, :fxmember, Dict{String,String}()), e, "r0i0p0")

const PROTOCOL =
    "Braconnot, P., Harrison, S. P., Kageyama, M., et al.: Evaluation of climate models using " *
    "palaeoclimatic data, Nat. Clim. Change, 2, 417-424, 2012, doi:10.1038/nclimate1456; Taylor, K. E., " *
    "Stouffer, R. J., and Meehl, G. A.: An overview of CMIP5 and the experiment design, Bull. Amer. " *
    "Meteor. Soc., 93, 485-498, 2012, doi:10.1175/BAMS-D-11-00094.1"
const LICENSE = "CMIP5 model output, terms of use https://pcmdi.llnl.gov/mips/cmip5/terms-of-use.html " *
                "(for some models non-commercial research and education only)"

"""
    cmip5_files(m, experiment, frequency, table, var, member) -> Vector{String}

The files of `var` (any realm) in the latest version that is readable in one of the pools,
[] if none.
"""
function cmip5_files(m, experiment, frequency, table, var, member)
    cands = Tuple{String,Vector{String}}[]
    for pool in POOLS
        base = joinpath(pool, m.institute, m.model, experiment, frequency)
        isdir(base) || continue
        for realm in readdir(base)
            dir = joinpath(base, realm, table, member)
            isdir(dir) || continue
            for v in readdir(dir)
                isdir(joinpath(dir, v)) || continue
                fs = filter(f -> startswith(f, "$(var)_") && endswith(f, ".nc"), readdir(joinpath(dir, v)))
                push!(cands, (v, joinpath.(dir, v, fs)))
            end
        end
    end
    return latest_version(cands)
end

function read_fx(m, experiment, var)
    fs = cmip5_files(m, experiment, "fx", "fx", var, fxmember(m, experiment))
    isempty(fs) && return nothing
    NCDataset(ds -> (ds["lon"][:], ds["lat"][:], Float64.(coalesce.(ds[var][:, :], NaN))), only(fs))
end

function prepare(m, experiment, outdir)
    mem = member(m, experiment)
    tasfiles = cmip5_files(m, experiment, "mon", "Amon", "tas", mem)
    prfiles = cmip5_files(m, experiment, "mon", "Amon", "pr", mem)
    if isempty(tasfiles)
        println("$(m.model) $experiment: no tas ($mem) in the pool, skipped")
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
        years == years_pr || error("$(m.model) $experiment: tas and pr cover different years ($years, $years_pr)")
    end
    fields, monthly = tp_fields(tas, pr, days)

    lon, lat, refs = NCDataset(first(tasfiles)) do ds
        ds["lon"][:], ds["lat"][:], get(ds.attrib, "references", "")
    end
    fx = Dict(v => read_fx(m, experiment, v) for v in ("orog", "sftlf", "sftgif"))
    for (v, x) in fx
        x === nothing && (push!(missing_, v); continue)
        same_grid(x[1], lon) && same_grid(x[2], lat) || error("$(m.model) $experiment: $v not on the grid of tas")
    end
    # Fractions in % (some files give fractions in 0-1: GISS-E2-R lgm)
    pct(F) = maximum(filter(isfinite, F)) <= 1.0 + 1e-6 ? F : F ./ 100
    fx["orog"] === nothing || push!(fields, ("z_srf", fx["orog"][3], "m", "surface altitude (orography of the experiment)"))
    if fx["sftlf"] !== nothing
        f_land = pct(fx["sftlf"][3])
        push!(fields, ("f_land", f_land, "1", "land area fraction"))
        if fx["sftgif"] !== nothing
            f_ice = pct(fx["sftgif"][3])
            f_ice[isnan.(f_ice) .& (f_land .== 0)] .= 0      # no land ice where there is no land
            push!(fields, ("f_ice", f_ice, "1", "land ice area fraction"))
        end
    elseif fx["sftgif"] !== nothing
        push!(fields, ("f_ice", pct(fx["sftgif"][3]), "1", "land ice area fraction"))
    end

    yrs = "$(years[1])-$(years[2])"
    path = joinpath(outdir, "PMIP3_$(m.model)_$(experiment).nc")
    write_climatology(path, lon, lat, fields, monthly, [
        "title" => "PMIP3 $(m.model) $experiment climatology (years $yrs of the simulation)",
        "model" => m.model, "experiment" => experiment, "ensemble_member" => mem, "years" => yrs,
        "references" => "$PROTOCOL; $(m.model): $refs",
        "license" => LICENSE,
        "missing" => join(missing_, ","),
        "original_data" => join(unique(dirname.(filter(!isempty, [tasfiles; prfiles]))), " "),
        provenance_attrib("paleoclimate")...])
    println("Wrote $path ($yrs)", isempty(missing_) ? "" : ", missing: $(join(missing_, ", "))")
end

outdir = prepared_dir("PMIP3_cmip5")
mkpath(outdir)
for m in filter(m -> isempty(ARGS) || m.model in ARGS, MODELS), experiment in EXPERIMENTS
    prepare(m, experiment, outdir)
end
