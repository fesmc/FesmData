# Prepare the PMIP4 (CMIP6) lgm, midHolocene and piControl atmosphere climatologies for remapping:
# monthly, annual, DJF and JJA means of tas and pr over the last 100 years of each run
# (Amon), with the orography and the land and ice fractions (fx) of the experiment, one file
# per model and experiment on the model's own lon-lat grid,
# $FESMDATA_PREPARED/PMIP4_cmip6/PMIP4_<model>_<experiment>.nc. A missing variable or fx field
# is left out of the file and named in its global attribute `missing`.
#
# The CMIP6 files are read from the pools in $CMIP6_POOL (':'-separated, searched in order:
# the DKRZ pool /pool/data/CMIP6/data on Levante by default; on Albedo the AWI pool,
# shared/machines/albedo.env); of each variable the latest readable version. The
# models: models.jl. Ocean and sea ice: prepare_ocean.jl.
#
# Usage:
#     julia --project=PMIP4_cmip6 PMIP4_cmip6/prepare.jl [model ...]
#     julia fesmdata.jl remap $FESMDATA_PREPARED/PMIP4_cmip6/PMIP4_INM-CM4-8_lgm.nc all --name=PMIP4-INM-CM4-8-lgm

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "cmip_climatology.jl"))

include(joinpath(@__DIR__, "models.jl"))

"An fx field on the grid `grid` (label) of tas: (lon, lat, field), or nothing."
function read_fx(activity, m, experiment, var, grid)
    fs = cmip6_files(activity, m, experiment, "fx", var; grids=[grid])
    isempty(fs) && return nothing
    NCDataset(ds -> (ds["lon"][:], ds["lat"][:], Float64.(coalesce.(ds[var][:, :], NaN))), only(fs))
end

function prepare(m, experiment, activity, outdir)
    tasfiles = cmip6_files(activity, m, experiment, "Amon", "tas")
    prfiles = cmip6_files(activity, m, experiment, "Amon", "pr")
    if isempty(tasfiles)
        println("$(m.model) $experiment: no tas ($(member(m, experiment))) in the pools, skipped")
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
    grid = basename(dirname(dirname(first(tasfiles))))            # .../<grid>/<version>/<file>
    fx = Dict(v => read_fx(activity, m, experiment, v, grid) for v in ("orog", "sftlf", "sftgif"))
    for v in collect(keys(fx))
        x = fx[v]
        x === nothing && (push!(missing_, v); continue)
        if same_grid(x[1], lon) && same_grid(reverse(x[2]), lat)       # north to south (EC-Earth3-LR sftlf)
            fx[v] = x = (x[1], reverse(x[2]), reverse(x[3]; dims=2))
        end
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
    write_climatology(path, lon, lat, fields, monthly, [
        "title" => "PMIP4 $(m.model) $experiment climatology (years $yrs of the simulation)",
        "model" => m.model, "experiment" => experiment, "variant_label" => member(m, experiment), "years" => yrs,
        citation(m, experiment, activity, furtherinfo)..., "license" => license, "further_info_url" => furtherinfo,
        "missing" => join(missing_, ","),
        "original_data" => join(unique(dirname.([tasfiles; prfiles])), " "),
        provenance_attrib("paleoclimate")...])
    println("Wrote $path ($yrs)", isempty(missing_) ? "" : ", missing: $(join(missing_, ", "))")
end

outdir = prepared_dir("PMIP4_cmip6")
mkpath(outdir)
for (m, experiment, activity) in selection(ARGS)
    prepare(m, experiment, activity, outdir)
end
