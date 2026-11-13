# Prepare the LGM (21ka) and preindustrial (PI) climatologies of the Paleoclimate-Calibrated
# CESM2 (CESM2.1.1 PaleoCalibr, Zhu et al., 2022) in the form of PMIP4_cmip6: monthly, annual,
# DJF and JJA means of TREFHT and PRECC + PRECL over the last 100 years of each run (years
# 401-500), with the surface altitude PHIS/g and the land fraction LANDFRAC, on the CAM grid
# (f19, 1.9° x 2.5°), $FESMDATA_PREPARED/Zhu2022_PaleoCalibr/PMIP4_CESM2-PaleoCalibr_{lgm,piControl}.nc.
#
# The CAM history time series (cam.h0.<var>.<yyyymm>-<yyyymm>.nc) are read from $PALEOCALIBR_DIR
# (default /albedo/work/projects/p_pool_clim_data/gdex/d583116, fetched from NCAR GDEX d583116,
# see README.md). CAM stamps a monthly mean at the end of its month, so the month is taken from
# the middle of time_bnds.
#
# Usage: julia --project=Zhu2022_PaleoCalibr Zhu2022_PaleoCalibr/prepare.jl

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "cmip_climatology.jl"))

const DIR = get(ENV, "PALEOCALIBR_DIR", "/albedo/work/projects/p_pool_clim_data/gdex/d583116")
const CASES = ["lgm" => "b.e21.B1850.f19_g17.PaleoCalibr.21ka.02", "piControl" => "b.e21.B1850.f19_g17.PaleoCalibr.PI.02"]
const YEARS = (401, 500)
const G = 9.80616      # CAM's gravity [m s-2] (PHIS = g z)
const REFERENCES =
    "Zhu, J., Otto-Bliesner, B. L., Brady, E. C., et al.: LGM paleoclimate constraints inform cloud " *
    "parameterizations and equilibrium climate sensitivity in CESM2, J. Adv. Model. Earth Syst., 14, " *
    "e2021MS002776, 2022, doi:10.1029/2021MS002776; Zhu, J.: Simulation data of the DECK, CMIP6 historical, " *
    "and PMIP4 LGM simulations using the Paleoclimate-Calibrated CESM2, NSF NCAR Geoscience Data Exchange, " *
    "2021, doi:10.5065/bdr7-wt42; Kageyama, M., Braconnot, P., Harrison, S. P., et al.: The PMIP4 " *
    "contribution to CMIP6 - Part 1, Geosci. Model Dev., 11, 1033-1057, 2018, doi:10.5194/gmd-11-1033-2018"

files(case, var) = sort(filter(f -> occursin(".cam.h0.$var.", f) && startswith(f, case) && endswith(f, ".nc"), readdir(DIR)))

"Monthly climatology of `var` over YEARS (month from the middle of time_bnds), and the mean month lengths."
function climatology(case, var)
    S, n, days = nothing, zeros(Int, 12), zeros(12)
    for f in files(case, var)
        NCDataset(joinpath(DIR, f)) do ds
            b = ds[ds["time"].attrib["bounds"]][:, :]
            mid = [b[1, i] + Dates.Millisecond(div(Dates.value(b[2, i] - b[1, i]), 2)) for i in axes(b, 2)]
            for i in eachindex(mid)
                YEARS[1] <= Dates.year(mid[i]) <= YEARS[2] || continue
                A = Float64.(coalesce.(ds[var][:, :, i], NaN))
                S === nothing && (S = zeros(size(A)..., 12))
                m = Dates.month(mid[i])
                S[:, :, m] .+= A
                n[m] += 1
                days[m] += Dates.value(b[2, i] - b[1, i]) / 86_400_000
            end
        end
    end
    all(==(YEARS[2] - YEARS[1] + 1), n) || error("$case $var: months missing in $(YEARS[1])-$(YEARS[2]) ($n)")
    return S ./ reshape(n, 1, 1, 12), days ./ n
end

annual(case, var) = dropdims(sum(climatology(case, var)[1]; dims=3); dims=3) ./ 12

function prepare(experiment, case, outdir)
    tas, days = climatology(case, "TREFHT")
    pr = climatology(case, "PRECC")[1] .+ climatology(case, "PRECL")[1]      # m s-1
    fields, monthly = tp_fields(tas, pr .* 1000, days)                       # kg m-2 s-1 as in CMIP
    push!(fields, ("z_srf", annual(case, "PHIS") ./ G, "m", "surface altitude (PHIS / g, orography of the experiment)"),
          ("f_land", annual(case, "LANDFRAC"), "1", "land area fraction"))
    lon, lat = NCDataset(ds -> (ds["lon"][:], ds["lat"][:]), joinpath(DIR, first(files(case, "TREFHT"))))
    path = joinpath(outdir, "PMIP4_CESM2-PaleoCalibr_$(experiment).nc")
    yrs = "$(YEARS[1])-$(YEARS[2])"
    write_climatology(path, lon, lat, fields, monthly, [
        "title" => "PMIP4 CESM2-PaleoCalibr $experiment climatology (years $yrs of the simulation)",
        "model" => "CESM2-PaleoCalibr", "experiment" => experiment, "case" => case, "years" => yrs,
        "references" => REFERENCES, "doi" => "10.5065/bdr7-wt42",
        "license" => "Creative Commons Attribution 4.0 International (CC BY 4.0)",
        "missing" => "sftgif",
        "original_data" => "$DIR/$case.cam.h0.{TREFHT,PRECC,PRECL,PHIS,LANDFRAC}.*.nc",
        provenance_attrib("paleoclimate")...])
    println("Wrote $path ($yrs)")
end

outdir = prepared_dir("Zhu2022_PaleoCalibr")
mkpath(outdir)
for (experiment, case) in CASES
    prepare(experiment, case, outdir)
end
