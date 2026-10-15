# Prepare the EPICA Dome C nitrous oxide record of Schilt et al. (2010) as a record (see
# Records/README.md): the NOAA NCEI file (datamanifest key schilt2010_n2o), N2O over 800
# kyr on the EDC3 gas age, as a time series at EDC (featureType timeSeries),
# $FESMDATA_PREPARED/Schilt2010_N2O/Schilt2010_N2O.nc.
#
# Usage:
#     julia --project=Schilt2010_N2O Schilt2010_N2O/prepare.jl
#     julia fesmdata.jl record GHG Schilt2010

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

# EPICA Dome C, as in the other EDC files of NOAA NCEI
const SITE = Site("EDC", -75.1, 123.4; z_srf=3240.0)

txt = download_dataset(manifest(), "schilt2010_n2o")
# A free-text header, then two lines of column headers ending with "[m] [m] [yr BP]
# [ppbv] ...", the data (NaN for missing) up to the end
lines = read_lines(txt)
h = findfirst(l -> split(l) == ["[m]", "[m]", "[yr", "BP]", "[ppbv]", "[ppbv]", "[ppbv]"], lines)
h === nothing && error("$txt: no line of units [m] [m] [yr BP] [ppbv] [ppbv] [ppbv]")
t = read_columns(txt, ["depth_edc96", "depth_edc99", "age", "n2o", "n2o_artifact", "n2o_sd"]; skipto=h + 1)
depth = column(t, "depth_edc99")
age = nan64(column(t, "age"))
sorted = all(>(0), diff(age))

write_series(joinpath(prepared_dir("Schilt2010_N2O"), "Schilt2010_N2O.nc"); tag="ghg",
    sites=[SITE], axis=sorted ? "time" : "sample", time=age,
    time_comment="EDC3 gas age (Loulergue et al., 2007), years before 1950 CE",
    axis_vars=[Var("time_aicc2023", aicc2023_age("EDC", depth; kind="gas"), "years ago",
                   "AICC2023 gas age (Bouchet et al., 2023), years before 1950 CE"; T=Float64)],
    vars=[Var("depth", depth, "m", "depth in the core (EDC99; from EDC96 depths where measured on EDC96)"; T=Float64,
              attrib=["positive" => "down"]),
          Var("n2o", column(t, "n2o"), "ppb", "atmospheric N2O mole fraction (missing where the value is an artifact)"),
          Var("n2o_artifact", column(t, "n2o_artifact"), "ppb", "N2O values identified as artifacts (in situ production)"),
          Var("n2o_sd", column(t, "n2o_sd"), "ppb", "uncertainty (1 sigma) of n2o")],
    title="EPICA Dome C nitrous oxide, 800 kyr (Schilt et al., 2010)",
    references="Schilt, A., Baumgartner, M., Blunier, T., Schwander, J., Spahni, R., Fischer, H., and Stocker, " *
               "T. F.: Glacial-interglacial and millennial-scale variations in the atmospheric nitrous oxide " *
               "concentration during the last 800,000 years, Quat. Sci. Rev., 29, 182-192, 2010, " *
               "doi:10.1016/j.quascirev.2009.03.011; with data of Spahni et al. (2005), Flückiger et al. (2002) and " *
               "Stauffer et al. (2002). Data: EPICA Dome C Ice Core 800KYr N2O Data, IGBP PAGES/World Data Center " *
               "for Paleoclimatology Data Contribution Series # 2010-005, NOAA NCEI",
    doi="10.1016/j.quascirev.2009.03.011",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
