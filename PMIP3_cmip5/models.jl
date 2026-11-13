# The PMIP3 (CMIP5) models, experiments and members of PMIP3_cmip5, the references and terms
# of use, and the CMIP5 files in the pools. Included by prepare.jl (atmosphere) and
# prepare_ocean.jl (ocean and sea ice), after shared/cmip_climatology.jl.

const POOLS = pool_roots("CMIP5_POOL", "/albedo/work/projects/p_pool_clim_data/cmip5/output1:" *
                                      "/albedo/work/projects/p_pool_clim_data/esgf/cmip5/output1")

# The models with a PMIP3 lgm or midHolocene run on ESGF (see README.md), their experiments
# (all three unless given), ensemble member per experiment (r1i1p1 unless given) and fx member
# (r0i0p0 unless given). GISS-E2-R lgm: physics version p150 (as PMIP3_cvdp).
const MODELS = [
    (institute="BCC", model="bcc-csm1-1", experiments=["midHolocene", "piControl"]),
    (institute="NCAR", model="CCSM4"),
    (institute="CNRM-CERFACS", model="CNRM-CM5"),
    (institute="CSIRO-QCCCE", model="CSIRO-Mk3-6-0", experiments=["midHolocene", "piControl"]),
    (institute="LASG-CESS", model="FGOALS-g2"),
    (institute="LASG-IAP", model="FGOALS-s2", experiments=["midHolocene", "piControl"]),
    (institute="NASA-GISS", model="GISS-E2-R", member=Dict("lgm" => "r1i1p150"), fxmember=Dict("lgm" => "r0i0p150")),
    (institute="MOHC", model="HadGEM2-CC", experiments=["midHolocene", "piControl"]),
    (institute="MOHC", model="HadGEM2-ES", experiments=["midHolocene", "piControl"]),
    (institute="IPSL", model="IPSL-CM5A-LR"),
    (institute="MIROC", model="MIROC-ESM"),
    (institute="MPI-M", model="MPI-ESM-P"),
    (institute="MRI", model="MRI-CGCM3"),
]
const EXPERIMENTS = ["lgm", "midHolocene", "piControl"]
const NYEARS = 100      # climatology over the last NYEARS years (all years if fewer)

experiments(m) = get(m, :experiments, EXPERIMENTS)
member(m, e) = get(get(m, :member, Dict{String,String}()), e, "r1i1p1")
fxmember(m, e) = get(get(m, :fxmember, Dict{String,String}()), e, "r0i0p0")

"The models and experiments to prepare: all, or those of the models named in `args`."
selection(args) = [(m, e) for m in MODELS if isempty(args) || m.model in args for e in experiments(m)]

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
