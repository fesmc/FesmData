# Prepare the LR04 benthic d18O stack of Lisiecki and Raymo (2005) as a record (see
# Records/README.md): the NOAA NCEI file (datamanifest key lisiecki2005_lr04), the
# average of 57 benthic d18O records over 5.3 Myr, as a global series (featureType
# timeSeries), $FESMDATA_PREPARED/Lisiecki2005_LR04/Lisiecki2005_LR04.nc.
#
# Usage:
#     julia --project=Lisiecki2005_LR04 Lisiecki2005_LR04/prepare.jl
#     julia fesmdata.jl record Stacks LR04

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "lisiecki2005_lr04")
t = read_noaa(txt)

write_series(joinpath(prepared_dir("Lisiecki2005_LR04"), "Lisiecki2005_LR04.nc"); tag="stacks",
    sites=[Region("global")], instance="region", time=1000 .* nan64(column(t, "age_calkaBP")),
    time_comment="LR04 age model (tuned to a model of ice volume forced by 21 June insolation at 65N), every 1 kyr " *
                 "to 600 ka, 2 kyr to 1500 ka, 2.5 kyr to 3000 ka and 5 kyr beyond; years before 1950 CE",
    vars=[Var("d18O_benthic", column(t, "d18O_benthic"), "1e-3", "benthic d18O, average of 57 globally distributed records, per mil"),
          Var("d18O_benthic_sd", column(t, "d18O_error"), "1e-3", "standard error of d18O_benthic, per mil")],
    title="LR04 benthic d18O stack, 5.3 Myr (Lisiecki and Raymo, 2005)",
    references="Lisiecki, L. E. and Raymo, M. E.: A Pliocene-Pleistocene stack of 57 globally distributed benthic " *
               "d18O records, Paleoceanography, 20, PA1003, 2005, doi:10.1029/2004PA001071. Data: LR04 Global " *
               "Pliocene-Pleistocene Benthic d18O Stack, NOAA NCEI, doi:10.25921/k88j-0106",
    doi="10.25921/k88j-0106",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication; also on PANGAEA, CC BY 3.0)")
