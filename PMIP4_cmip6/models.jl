# The PMIP4 (CMIP6) models, experiments and members of PMIP4_cmip6, their data citations,
# and the CMIP6 files in the pools. Included by prepare.jl (atmosphere) and prepare_ocean.jl
# (ocean and sea ice), after shared/cmip_climatology.jl.

"CMIP6 data pools (<activity>/<institution>/<model>/<experiment>/<member>/<table>/<variable>/<grid>/<version>), ':'-separated."
const POOLS = pool_roots("CMIP6_POOL", "/pool/data/CMIP6/data")

# The models with a PMIP4 lgm or midHolocene run on ESGF (see README.md): their institution
# and member (one for all experiments, or a Dict per experiment), experiments (all three
# unless given) and the ESGF data citations of their experiments (DOI 10.22033/ESGF/CMIP6.<n>,
# authors and year, from the WDCC citation service). CESM2-FV2 and CESM2-WACCM-FV2: lgm only,
# with the matching physics (i2p2) of their piControl.
const MODELS = [
    (institution="CSIRO", model="ACCESS-ESM1-5", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (13704, "Brown, J. et al.", 2021), "piControl" => (4312, "Ziehn, T. et al.", 2019))),
    (institution="AWI", model="AWI-ESM-1-1-LR", member="r1i1p1f1",
     doi=Dict("lgm" => (9330, "Shi, X. et al.", 2020), "midHolocene" => (9332, "Shi, X. et al.", 2020),
              "piControl" => (9335, "Danek, C. et al.", 2020))),
    (institution="NCAR", model="CESM2", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (7674, "Danabasoglu, G.", 2019), "piControl" => (7733, "Danabasoglu, G. et al.", 2019))),
    (institution="NCAR", model="CESM2-FV2", member="r1i2p2f1", experiments=["lgm", "piControl"],
     doi=Dict("lgm" => (17642, "National Center for Atmospheric Research (NCAR)", 2022),
              "piControl" => (11301, "Danabasoglu, G.", 2019))),
    (institution="NCAR", model="CESM2-WACCM-FV2", member="r1i2p2f1", experiments=["lgm", "piControl"],
     doi=Dict("lgm" => (17643, "National Center for Atmospheric Research (NCAR)", 2022),
              "piControl" => (11302, "Danabasoglu, G.", 2019))),
    (institution="EC-Earth-Consortium", model="EC-Earth3", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (11224, "EC-Earth Stockholm group (EC-Earth-S)", 2023),
              "piControl" => (4842, "EC-Earth Consortium (EC-Earth)", 2019))),
    (institution="EC-Earth-Consortium", model="EC-Earth3-LR", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (4801, "EC-Earth Consortium (EC-Earth)", 2020),
              "piControl" => (4847, "EC-Earth Consortium (EC-Earth)", 2019))),
    (institution="EC-Earth-Consortium", model="EC-Earth3-Veg", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (18105, "EC-Earth Stockholm group (EC-Earth-S)", 2023),
              "piControl" => (4848, "EC-Earth Consortium (EC-Earth)", 2019))),
    (institution="CAS", model="FGOALS-f3-L", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (12014, "Zheng, W. et al.", 2019), "piControl" => (3447, "Yu, Y.", 2019))),
    (institution="CAS", model="FGOALS-g3", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (3409, "Zheng, W. et al.", 2019), "piControl" => (3448, "Li, L.", 2019))),
    (institution="NASA-GISS", model="GISS-E2-1-G", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (7225, "NASA Goddard Institute for Space Studies (NASA/GISS)", 2019),
              "piControl" => (7380, "NASA Goddard Institute for Space Studies (NASA/GISS)", 2018))),
    (institution=Dict("midHolocene" => "NERC", "piControl" => "MOHC"), model="HadGEM3-GC31-LL", member="r1i1p1f1",
     experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (12129, "Williams, C. et al.", 2021), "piControl" => (6294, "Ridley, J. et al.", 2018))),
    (institution="INM", model="INM-CM4-8", member="r1i1p1f1",
     doi=Dict("lgm" => (5075, "Volodin, E. et al.", 2019), "midHolocene" => (5077, "Volodin, E. et al.", 2019),
              "piControl" => (5080, "Volodin, E. et al.", 2019))),
    (institution="IPSL", model="IPSL-CM6A-LR", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (5229, "Boucher, O. et al.", 2018), "piControl" => (5251, "Boucher, O. et al.", 2018))),
    (institution="MIROC", model="MIROC-ES2L", member="r1i1p1f2",
     doi=Dict("lgm" => (5644, "Ohgaito, R. et al.", 2019), "midHolocene" => (5646, "Ohgaito, R. et al.", 2019),
              "piControl" => (5710, "Hajima, T. et al.", 2019))),
    (institution="MPI-M", model="MPI-ESM1-2-LR", member="r1i1p1f1",
     doi=Dict("lgm" => (6642, "Jungclaus, J. et al.", 2019), "midHolocene" => (6644, "Jungclaus, J. et al.", 2019),
              "piControl" => (6675, "Wieners, K.-H. et al.", 2019))),
    (institution="MRI", model="MRI-ESM2-0", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (6860, "Yukimoto, S. et al.", 2019), "piControl" => (6900, "Yukimoto, S. et al.", 2019))),
    (institution="NUIST", model="NESM3", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (8773, "Cao, J.", 2019), "piControl" => (8776, "Cao, J. et al.", 2019))),
    (institution="NCC", model="NorESM1-F", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (11591, "Guo, C. et al.", 2019), "piControl" => (11595, "Guo, C. et al.", 2019))),
    (institution="NCC", model="NorESM2-LM", member="r1i1p1f1", experiments=["midHolocene", "piControl"],
     doi=Dict("midHolocene" => (8079, "Zhang, Z. et al.", 2019), "piControl" => (8217, "Seland, Ø. et al.", 2019))),
]
const EXPERIMENTS = ["lgm" => "PMIP", "midHolocene" => "PMIP", "piControl" => "CMIP"]
const NYEARS = 100      # climatology over the last NYEARS years (all years if fewer)

"A model attribute that is either one value for all experiments or a Dict per experiment."
per_experiment(x, experiment) = x isa AbstractDict ? x[experiment] : x
institution(m, experiment) = per_experiment(m.institution, experiment)
member(m, experiment) = per_experiment(m.member, experiment)

"The models, experiments and activities to prepare: all, or those of the models named in `args`."
selection(args) = [(m, e, a) for m in MODELS if isempty(args) || m.model in args
                   for (e, a) in EXPERIMENTS if e in get(m, :experiments, first.(EXPERIMENTS))]

const PROTOCOL =
    "Kageyama, M., Braconnot, P., Harrison, S. P., et al.: The PMIP4 contribution to CMIP6 - " *
    "Part 1: Overview and over-arching analysis plan, Geosci. Model Dev., 11, 1033-1057, 2018, " *
    "doi:10.5194/gmd-11-1033-2018"

"""
    cmip6_files(activity, m, experiment, table, var; grids=nothing) -> Vector{String}

The files of a variable in the latest version that is readable in one of the pools ([] if
none): of its only grid (`grids` nothing), or of the first of the grid labels `grids` that
is present.
"""
function cmip6_files(activity, m, experiment, table, var; grids=nothing)
    dirs = [joinpath(pool, activity, institution(m, experiment), m.model, experiment, member(m, experiment), table, var)
            for pool in POOLS]
    present = unique(g for d in dirs if isdir(d) for g in readdir(d))
    isempty(present) && return String[]
    if grids === nothing
        length(present) == 1 || error("$(m.model) $experiment $var: more than one grid ($present)")
        grid = only(present)
    else
        i = findfirst(in(present), grids)
        i === nothing && return String[]
        grid = grids[i]
    end
    cands = Tuple{String,Vector{String}}[]
    for dir in joinpath.(dirs, grid)
        isdir(dir) || continue
        for v in filter(v -> isdir(joinpath(dir, v)), readdir(dir))
            push!(cands, (v, filter(endswith(".nc"), readdir(joinpath(dir, v); join=true))))
        end
    end
    return latest_version(cands)
end

"""
    citation(m, experiment, activity, furtherinfo) -> attributes

The global attributes `references` (the PMIP4 protocol and the data citation) and `doi` of
the prepared files (the file's further_info_url if there is no DOI).
"""
function citation(m, experiment, activity, furtherinfo)
    data = "$(institution(m, experiment)) $(m.model) model output prepared for CMIP6 $activity $experiment, " *
           "Earth System Grid Federation"
    haskey(m.doi, experiment) || return ["references" => "$PROTOCOL; $data, $furtherinfo"]
    n, author, year = m.doi[experiment]
    doi = "10.22033/ESGF/CMIP6.$n"
    return ["references" => "$PROTOCOL; $author: $data, $year, doi:$doi", "doi" => doi]
end
