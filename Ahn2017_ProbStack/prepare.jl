# Prepare the probabilistic benthic d18O stack of Ahn et al. (2017) as a record (see
# Records/README.md): Prob_stack.txt of the repository of the authors (datamanifest key
# ahn2017_probstack), the stack of 180 benthic d18O records over 5 Myr, as a global series
# (featureType timeSeries), $FESMDATA_PREPARED/Ahn2017_ProbStack/Ahn2017_ProbStack.nc.
#
# Usage:
#     julia --project=Ahn2017_ProbStack Ahn2017_ProbStack/prepare.jl
#     julia fesmdata.jl record Stacks ProbStack

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "ahn2017_probstack")
# No header: age (ka), d18O, standard deviation, upper and lower bound of the 95% interval
t = read_columns(txt, ["age", "d18O", "sd", "upper", "lower"]; skipto=1)

write_series(joinpath(prepared_dir("Ahn2017_ProbStack"), "Ahn2017_ProbStack.nc"); tag="stacks",
    sites=[Region("global")], instance="region", time=1000 .* nan64(column(t, "age")),
    time_comment="age model of the stack (aligned to LR04), every 1 kyr to 600 ka, 2 kyr to 1500 ka, 2.5 kyr to " *
                 "3000 ka and 5 kyr beyond; years before 1950 CE",
    vars=[Var("d18O_benthic", column(t, "d18O"), "1e-3", "benthic d18O, probabilistic stack of 180 records, per mil"),
          Var("d18O_benthic_sd", column(t, "sd"), "1e-3", "standard deviation of d18O_benthic, per mil"),
          Var("d18O_benthic_min", column(t, "lower"), "1e-3", "lower bound of the 95% interval of d18O_benthic"),
          Var("d18O_benthic_max", column(t, "upper"), "1e-3", "upper bound of the 95% interval of d18O_benthic")],
    title="Probabilistic benthic d18O stack, 5 Myr (Ahn et al., 2017)",
    references="Ahn, S., Khider, D., Lisiecki, L. E., and Lawrence, C. E.: A probabilistic Pliocene-Pleistocene " *
               "stack of benthic d18O using a profile hidden Markov model, Dyn. Stat. Clim. Syst., 2, dzx002, 2017, " *
               "doi:10.1093/climsys/dzx002. Data: Prob_stack.txt of https://github.com/seonminahn/HMM-Stack " *
               "(commit c8125f8)",
    doi="10.1093/climsys/dzx002",
    license="GPL-3.0 (repository of the authors)")
