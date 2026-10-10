# Prepare the PMIP4 (CMIP6) lgm, midHolocene and piControl climatologies for remapping:
# monthly, annual, DJF and JJA means of tas and pr over the last 100 years of each run
# (Amon, DKRZ CMIP6 pool), with the orography and the land and ice fractions (fx) of the
# experiment, one file per model and experiment on the model's own lon-lat grid,
# $FESMDATA_WORK/prepared/PMIP4_cmip6/PMIP4_<model>_<experiment>.nc.
#
# Usage (on Levante, where the CMIP6 data are in /pool/data/CMIP6/data):
#     julia --project=PMIP4_cmip6 PMIP4_cmip6/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/PMIP4_cmip6/PMIP4_INM-CM4-8_lgm.nc all --name=PMIP4-INM-CM4-8-lgm

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))

"CMIP6 data tree (<activity>/<institution>/<model>/<experiment>/<member>/<table>/<variable>/<grid>/<version>)."
const POOL = get(ENV, "CMIP6_POOL", "/pool/data/CMIP6/data")

# The models with lgm, midHolocene and piControl (r1 member), and the ESGF data DOIs of
# their experiments (10.22033/ESGF/CMIP6.<n>) with the first author of each data citation
const MODELS = [
    (institution="AWI", model="AWI-ESM-1-1-LR", member="r1i1p1f1", year=2020,
     doi=Dict("lgm" => (9330, "Shi, X."), "midHolocene" => (9332, "Shi, X."), "piControl" => (9335, "Danek, C."))),
    (institution="INM", model="INM-CM4-8", member="r1i1p1f1", year=2019,
     doi=Dict("lgm" => (5075, "Volodin, E."), "midHolocene" => (5077, "Volodin, E."), "piControl" => (5080, "Volodin, E."))),
    (institution="MIROC", model="MIROC-ES2L", member="r1i1p1f2", year=2019,
     doi=Dict("lgm" => (5644, "Ohgaito, R."), "midHolocene" => (5646, "Ohgaito, R."), "piControl" => (5710, "Hajima, T."))),
    (institution="MPI-M", model="MPI-ESM1-2-LR", member="r1i1p1f1", year=2019,
     doi=Dict("lgm" => (6642, "Jungclaus, J."), "midHolocene" => (6644, "Jungclaus, J."), "piControl" => (6675, "Wieners, K.-H."))),
]
const EXPERIMENTS = ["lgm" => "PMIP", "midHolocene" => "PMIP", "piControl" => "CMIP"]
const NYEARS = 100      # climatology over the last NYEARS years (all years if fewer)

const PROTOCOL =
    "Kageyama, M., Braconnot, P., Harrison, S. P., et al.: The PMIP4 contribution to CMIP6 - " *
    "Part 1: Overview and over-arching analysis plan, Geosci. Model Dev., 11, 1033-1057, 2018, " *
    "doi:10.5194/gmd-11-1033-2018"

"Files of a variable: the only grid and the latest version of its folder."
function cmip6_files(activity, m, experiment, table, var)
    dir = joinpath(POOL, activity, m.institution, m.model, experiment, m.member, table, var)
    grids = readdir(dir)
    length(grids) == 1 || error("$dir: more than one grid ($grids)")
    dir = joinpath(dir, only(grids))
    dir = joinpath(dir, last(sort(readdir(dir))))
    return filter(endswith(".nc"), readdir(dir; join=true))
end

"""
    monthly_climatology(files, name, nyears) -> (M, weights, years)

Mean of each calendar month of `name` over the last `nyears` complete years in `files`
(lon × lat × 12), the mean length of each month in days, and the years used.
"""
function monthly_climatology(files, name, nyears)
    recs = NamedTuple[]
    for f in files
        NCDataset(f) do ds
            t = ds["time"][:]
            b = ds[ds["time"].attrib["bounds"]][:, :]
            for i in eachindex(t)
                push!(recs, (file=f, i=i, year=Dates.year(t[i]), month=Dates.month(t[i]),
                             days=Dates.value(b[2, i] - b[1, i]) / 86_400_000))
            end
        end
    end
    complete = [y for y in unique(r.year for r in recs) if count(r -> r.year == y, recs) == 12]
    y1 = maximum(complete)
    y0 = max(minimum(complete), y1 - nyears + 1)
    all(y -> y in complete, y0:y1) || error("$name: incomplete years in $y0-$y1")
    sel = filter(r -> y0 <= r.year <= y1, recs)

    S = nothing
    n = zeros(Int, 12)
    days = zeros(12)
    for f in unique(r.file for r in sel)
        rs = filter(r -> r.file == f, sel)
        i = [r.i for r in rs]
        i == first(i):last(i) || error("$f: time steps not contiguous")
        NCDataset(f) do ds
            A = Float64.(coalesce.(ds[name][:, :, first(i):last(i)], NaN))
            S === nothing && (S = zeros(size(A, 1), size(A, 2), 12))
            for (k, r) in enumerate(rs)
                S[:, :, r.month] .+= A[:, :, k]
                n[r.month] += 1
                days[r.month] += r.days
            end
        end
    end
    all(==(y1 - y0 + 1), n) || error("$name: months missing in $y0-$y1")
    return S ./ reshape(n, 1, 1, 12), days ./ n, (y0, y1)
end

"Mean over the months `months` of a monthly climatology, weighted by month length."
season(M, days, months) = sum(M[:, :, m] .* days[m] for m in months) ./ sum(days[months])

function read_fx(activity, m, experiment, var)
    f = only(cmip6_files(activity, m, experiment, "fx", var))
    NCDataset(ds -> (ds["lon"][:], ds["lat"][:], Float64.(coalesce.(ds[var][:, :], NaN))), f)
end

function prepare(m, experiment, activity, outdir)
    tasfiles = cmip6_files(activity, m, experiment, "Amon", "tas")
    prfiles = cmip6_files(activity, m, experiment, "Amon", "pr")
    tas, days, years = monthly_climatology(tasfiles, "tas", NYEARS)
    pr, days_pr, years_pr = monthly_climatology(prfiles, "pr", NYEARS)
    years == years_pr || error("$(m.model) $experiment: tas and pr cover different years")
    tas .-= 273.15                  # K -> degC
    pr .*= 86400                    # kg m-2 s-1 -> mm d-1

    lon, lat, license, furtherinfo = NCDataset(first(tasfiles)) do ds
        ds["lon"][:], ds["lat"][:], ds.attrib["license"], ds.attrib["further_info_url"]
    end
    fx = Dict(v => read_fx(activity, m, experiment, v) for v in ("orog", "sftlf", "sftgif"))
    for (v, (lo, la, _)) in fx
        lo ≈ lon && la ≈ lat || error("$(m.model) $experiment: $v not on the grid of tas")
    end
    # No land ice where there is no land (MIROC-ES2L leaves sftgif missing there)
    sftlf, sftgif = fx["sftlf"][3], fx["sftgif"][3]
    sftgif[isnan.(sftgif) .& (sftlf .== 0)] .= 0

    fields = [
        ("t2m_ann", season(tas, days, 1:12), "degC", "near-surface (2 m) air temperature, annual mean"),
        ("t2m_djf", season(tas, days, [12, 1, 2]), "degC", "near-surface (2 m) air temperature, DJF mean"),
        ("t2m_jja", season(tas, days, 6:8), "degC", "near-surface (2 m) air temperature, JJA mean"),
        ("pr_ann", season(pr, days, 1:12), "mm d-1", "precipitation (water equivalent), annual mean"),
        ("pr_djf", season(pr, days, [12, 1, 2]), "mm d-1", "precipitation (water equivalent), DJF mean"),
        ("pr_jja", season(pr, days, 6:8), "mm d-1", "precipitation (water equivalent), JJA mean"),
        ("z_srf", fx["orog"][3], "m", "surface altitude (orography of the experiment)"),
        ("f_land", sftlf ./ 100, "1", "land area fraction"),
        ("f_ice", sftgif ./ 100, "1", "land ice area fraction"),
    ]
    monthly = [
        ("t2m_mon", tas, "degC", "near-surface (2 m) air temperature, monthly mean"),
        ("pr_mon", pr, "mm d-1", "precipitation (water equivalent), monthly mean"),
    ]

    n, author = m.doi[experiment]
    doi = "10.22033/ESGF/CMIP6.$n"
    yrs = "$(years[1])-$(years[2])"
    path = joinpath(outdir, "PMIP4_$(m.model)_$(experiment).nc")
    NCDataset(path, "c") do ds
        defVar(ds, "lon", Float64.(lon), ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
        defVar(ds, "lat", Float64.(lat), ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
        defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
        for (name, F, units, long_name) in fields
            defVar(ds, name, Float32.(F), ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => units, "long_name" => long_name])
        end
        for (name, F, units, long_name) in monthly
            defVar(ds, name, Float32.(F), ("lon", "lat", "month"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => units, "long_name" => long_name])
        end
        ds.attrib["title"] = "PMIP4 $(m.model) $experiment climatology (years $yrs of the simulation)"
        ds.attrib["model"] = m.model
        ds.attrib["experiment"] = experiment
        ds.attrib["variant_label"] = m.member
        ds.attrib["years"] = yrs
        ds.attrib["references"] = "$PROTOCOL; $author et al.: $(m.institution) $(m.model) model output " *
                                  "prepared for CMIP6 $activity $experiment, Earth System Grid Federation, " *
                                  "$(m.year), doi:$doi"
        ds.attrib["doi"] = doi
        ds.attrib["license"] = license
        ds.attrib["further_info_url"] = furtherinfo
        ds.attrib["original_data"] = join(unique(dirname.([tasfiles; prfiles])), " ")
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("paleoclimate"))
    end
    println("Wrote $path ($yrs)")
end

outdir = prepared_dir("PMIP4_cmip6")
mkpath(outdir)
for m in MODELS, (experiment, activity) in EXPERIMENTS
    prepare(m, experiment, activity, outdir)
end
