# Prepare the spline-smoothed greenhouse gas records of Köhler et al. (2017) as a record
# (see Records/README.md): the version 2 splines of CO2, CH4 and N2O and their radiative
# forcing, every year from 2016 CE back to 156 ka (N2O to 134 ka), from PANGAEA
# (datamanifest keys koehler2017_co2, koehler2017_ch4, koehler2017_n2o), as a global
# series (featureType timeSeries), $FESMDATA_PREPARED/Koehler2017_GHG/Koehler2017_GHG.nc.
#
# Usage:
#     julia --project=Koehler2017_GHG Koehler2017_GHG/prepare.jl
#     julia fesmdata.jl record GHG Koehler2017

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

# Gas => (PANGAEA column of the value, units, long name of the value)
const GASES = [
    "co2" => ("CO2 [µmol/mol]", "ppm", "atmospheric CO2 mole fraction, spline"),
    "ch4" => ("CH4 [nmol/mol]", "ppb", "atmospheric CH4 mole fraction, spline (Southern Hemisphere: Antarctic ice cores and stations)"),
    "n2o" => ("N2O [nmol/mol]", "ppb", "atmospheric N2O mole fraction, spline"),
]
const FORCING = Dict("co2" => "5.35 ln(CO2/278)", "ch4" => "1.4 x 0.036 (sqrt(CH4) - sqrt(742))",
                     "n2o" => "0.12 (sqrt(N2O) - sqrt(272))")

tables = Dict(gas => read_pangaea(download_dataset(manifest(), "koehler2017_$gas")) for (gas, _) in GASES)
# Ages in ka BP, every 0.001 ka: whole years
years(t) = round.(Int, 1000 .* nan64(column(t, "Age [ka BP]")))
for (gas, t) in tables
    y = years(t)
    all(diff(y) .== 1) || error("$(t.path): the ages are not every year")
end
y0, y1 = minimum(first(years(t)) for t in values(tables)), maximum(last(years(t)) for t in values(tables))
time = collect(y0:y1)
# The values of a column of a gas on the common axis (missing beyond its record)
function on_axis(gas, col)
    t = tables[gas]
    v = Vector{Union{Missing,Float64}}(missing, length(time))
    v[years(t) .- y0 .+ 1] .= column(t, col)
    return v
end

vars = Var[]
for (gas, (col, units, long_name)) in GASES
    G = uppercase(gas)
    push!(vars, Var(gas, on_axis(gas, col), units, long_name),
                Var("$(gas)_sd", on_axis(gas, "$G std dev [±]"), units, "uncertainty (1 sigma) of $gas"),
                Var("rf_$gas", on_axis(gas, "dR_[$G] [W/m**2]"), "W m-2",
                    "radiative forcing of $G relative to the preindustrial value, $(FORCING[gas])"),
                Var("rf_$(gas)_sd", on_axis(gas, "dR_[$G] std dev [±]"), "W m-2", "uncertainty (1 sigma) of rf_$gas"))
end

write_series(joinpath(prepared_dir("Koehler2017_GHG"), "Koehler2017_GHG.nc"); tag="ghg",
    sites=[Region("global")], instance="region", time,
    time_comment="every year, years before 1950 CE (from ka BP); ice core gas ages on AICC2012 (EDC, EDML, " *
                 "TALDICE), WD2014 (WAIS Divide) and GICC05 (NGRIP)",
    vars, title="Spline-smoothed CO2, CH4 and N2O and their radiative forcing, 156 kyr (Köhler et al., 2017)",
    references="Köhler, P., Nehrbass-Ahles, C., Schmitt, J., Stocker, T. F., and Fischer, H.: A 156 kyr smoothed " *
               "history of the atmospheric greenhouse gases CO2, CH4, and N2O and their radiative forcing, Earth " *
               "Syst. Sci. Data, 9, 363-387, 2017, doi:10.5194/essd-9-363-2017. Data: PANGAEA, " *
               "doi:10.1594/PANGAEA.871273 (version 2 splines, 2017-06-08: doi:10.1594/PANGAEA.876013, " *
               "doi:10.1594/PANGAEA.876009, doi:10.1594/PANGAEA.876014)",
    doi="10.1594/PANGAEA.871273", license="CC BY 3.0 (PANGAEA)")
