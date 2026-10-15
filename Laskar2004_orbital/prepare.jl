# Prepare the orbital elements of Laskar et al. (2004) and insolation series computed from
# them as a record (see Records/README.md): the La2004 tables of IMCCE (datamanifest keys
# laskar2004_past, laskar2004_future), every 1 kyr from 5 Ma ago to 1 Ma in the future, as
# a global series (featureType timeSeries),
# $FESMDATA_PREPARED/Laskar2004_orbital/Laskar2004_orbital.nc.
#
# Usage:
#     julia --project=Laskar2004_orbital Laskar2004_orbital/prepare.jl
#     julia fesmdata.jl record Orbital La2004
#
# Insolation: daily means at the top of the atmosphere (insolation.jl, as the insol
# library), S0 = 1365 W m-2, a year of 365 days with the vernal equinox on 21 March. The
# tables are in kyr from J2000: the elements are interpolated at the times of the record
# (years before 1950 CE, i.e. -(t + 50) years from J2000).

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))
include(joinpath(@__DIR__, "insolation.jl"))

const S0 = 1365.0               # W m-2
const DAY_YEAR = 365
const TIME = -1_000_000:1000:5_000_000      # years before 1950 CE (negative: future)
# Days of the year: 21 June, 21 December, June-August, December-February
const JUN21, DEC21 = 172, 355
const JJA, DJF = 152:243, [335:365; 1:59]
# Insolation series: name => (latitude, days, long name)
const SERIES = [
    "insol_65n_jun21" => (65.0, [JUN21], "daily-mean insolation at 65N on 21 June"),
    "insol_65n_jja" => (65.0, JJA, "mean insolation at 65N in June-August"),
    "insol_65s_dec21" => (-65.0, [DEC21], "daily-mean insolation at 65S on 21 December"),
    "insol_65s_djf" => (-65.0, DJF, "mean insolation at 65S in December-February"),
]

tmax = maximum(abs, TIME) / 1000 + 1
tab = OrbitTable(read_la2004(download_dataset(manifest(), "laskar2004_past"), tmax),
                 read_la2004(download_dataset(manifest(), "laskar2004_future"), tmax))
t_ka = [-(t + B2K_TO_BP) / 1000 for t in TIME]     # kyr from J2000
elements = [orbital_par(tab, t; day_year=DAY_YEAR) for t in t_ka]
ecc, obl, per = [e[1] for e in elements], [e[2] for e in elements], [e[3] for e in elements]

vars = [Var("ecc", ecc, "1", "eccentricity of the orbit of the Earth"; T=Float64),
        Var("obl", obl, "degree", "obliquity"; T=Float64),
        Var("per", per, "degree", "longitude of the perihelion relative to the moving vernal equinox (pibar of La2004, " *
                                  "102.9 degrees at J2000, as omega of Berger, 1978)"; T=Float64),
        Var("prec", ecc .* sind.(per), "1", "climatic precession index e sin(per)"; T=Float64)]
for (name, (lat, days, long_name)) in SERIES
    push!(vars, Var(name, [insolation(tab, t, lat, days; S0, day_year=DAY_YEAR) for t in t_ka], "W m-2",
                    "$long_name (S0 = $(Int(S0)) W m-2, year of $DAY_YEAR days, vernal equinox on 21 March)"))
end

write_series(joinpath(prepared_dir("Laskar2004_orbital"), "Laskar2004_orbital.nc"); tag="orbital",
    sites=[Region("global")], instance="region", time=collect(Float64, TIME),
    time_comment="every 1 kyr from 1 Ma in the future (negative) to 5 Ma ago, years before 1950 CE",
    vars, title="Orbital elements and insolation, 5 Ma to 1 Ma in the future (Laskar et al., 2004)",
    references="Laskar, J., Robutel, P., Joutel, F., Gastineau, M., Correia, A. C. M., and Levrard, B.: A " *
               "long-term numerical solution for the insolation quantities of the Earth, Astron. Astrophys., 428, " *
               "261-285, 2004, doi:10.1051/0004-6361:20041335. Data: La2004 tables of IMCCE " *
               "(INSOLN.LA2004.BTL.ASC, INSOLP.LA2004.BTL.ASC). Insolation: Berger, A.: Long-term variations of " *
               "daily insolation and Quaternary climatic changes, J. Atmos. Sci., 35, 2362-2367, 1978, computed " *
               "as in the insol library (https://github.com/fesmc/insol)",
    doi="10.1051/0004-6361:20041335", license="No licence stated (ASD/IMCCE); publishing assumed to be allowed")
