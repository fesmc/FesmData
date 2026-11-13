# Prepare the ocean and sea-ice climatologies of the LGM (21ka) and preindustrial (PI) runs of
# the Paleoclimate-Calibrated CESM2 (Zhu et al., 2022) on the common regular 1° grid of
# PMIP4_cmip6 (shared/cmip_ocean.jl), $FESMDATA_PREPARED/Zhu2022_PaleoCalibr/
# PMIP4_CESM2-PaleoCalibr_{lgm,piControl}_ocean.nc, from the POP history time series: the
# monthly SST (top level of TEMP) and ice fraction (IFRAC, with the extent from the POP cell
# areas TAREA) climatologies of years 401-500, the annual mean potential temperature at
# standard depths of years 471-500 (TEMP), and the Atlantic overturning streamfunction of
# years 401-500 (MOC: region Atlantic Ocean + Mediterranean Sea + Labrador Sea + GIN Sea +
# Arctic Ocean, the sum of the Eulerian mean, eddy-induced and submesoscale components).
#
# The POP files are read from $PALEOCALIBR_DIR (default /albedo/work/projects/p_pool_clim_data/
# gdex/d583116), fetched from NCAR GDEX d583116: IFRAC and MOC whole, TEMP subset (the top
# level of years 401-500 without the level dimension, TEMP_top; the levels down to 2200 m of
# years 471-500, TEMP_0-2200m; see README.md).
#
# Usage (on Albedo, with cdo):
#     source shared/machines/albedo.env; module load cdo
#     julia --project=Zhu2022_PaleoCalibr Zhu2022_PaleoCalibr/prepare_ocean.jl

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "cmip_climatology.jl"))
include(joinpath(@__DIR__, "..", "shared", "cmip_ocean.jl"))

const DIR = get(ENV, "PALEOCALIBR_DIR", "/albedo/work/projects/p_pool_clim_data/gdex/d583116")
const CASES = ["lgm" => "b.e21.B1850.f19_g17.PaleoCalibr.21ka.02", "piControl" => "b.e21.B1850.f19_g17.PaleoCalibr.PI.02"]
const NYEARS = 100
const NYEARS_THETAO = 30
const REFERENCES =
    "Zhu, J., Otto-Bliesner, B. L., Brady, E. C., et al.: LGM paleoclimate constraints inform cloud " *
    "parameterizations and equilibrium climate sensitivity in CESM2, J. Adv. Model. Earth Syst., 14, " *
    "e2021MS002776, 2022, doi:10.1029/2021MS002776; Zhu, J.: Simulation data of the DECK, CMIP6 historical, " *
    "and PMIP4 LGM simulations using the Paleoclimate-Calibrated CESM2, NSF NCAR Geoscience Data Exchange, " *
    "2021, doi:10.5065/bdr7-wt42; Kageyama, M., Braconnot, P., Harrison, S. P., et al.: The PMIP4 " *
    "contribution to CMIP6 - Part 1, Geosci. Model Dev., 11, 1033-1057, 2018, doi:10.5194/gmd-11-1033-2018"

files(case, var) = joinpath.(DIR, sort(filter(f -> startswith(f, "$case.pop.h.$var.") && endswith(f, ".nc"), readdir(DIR))))

"The Atlantic overturning streamfunction [Sv] of the POP MOC files: all components, the Atlantic region."
function pop_amoc(fs; nyears)
    M, days, years = monthly_climatology(fs, "MOC", nyears)         # lat_aux_grid × moc_z × moc_comp × transport_reg × 12
    A = sum(selectdim(M, 5, m) .* days[m] for m in 1:12) ./ sum(days)
    lat, z, ia = NCDataset(first(fs)) do ds
        Float64.(ds["lat_aux_grid"][:]), level_depths(ds, "moc_z"), atlantic_index(ds, "transport_reg")
    end
    P = dropdims(sum(A[:, :, :, ia]; dims=3); dims=3)
    return amoc_fields(lat, z, P, years, "MOC", fs)
end

function prepare(experiment, case, outdir, workdir)
    println("CESM2-PaleoCalibr $experiment ($case)")
    ifrac = files(case, "IFRAC")
    area = NCDataset(ds -> Float64.(coalesce.(Array(ds["TAREA"]), NaN)) ./ 1e4, first(ifrac))   # cm2 to m2
    fields, missing_ = [], String[]
    for (key, make) in (("tos", () -> sst_mon(files(case, "TEMP_top"), workdir; nyears=NYEARS, name="TEMP")),
                        ("sic", () -> sea_ice(ifrac, "IFRAC", (area, "TAREA (POP cell areas)"), workdir; nyears=NYEARS)),
                        ("thetao", () -> to_ann(files(case, "TEMP_0-2200m"), workdir; nyears=NYEARS_THETAO, name="TEMP")),
                        ("msft", () -> pop_amoc(files(case, "MOC"); nyears=NYEARS)))
        try
            append!(fields, make())
        catch e
            println("  $key: ", sprint(showerror, e)[1:min(end, 400)])
            append!(missing_, OCEAN_FIELDS[key])
        end
    end
    path = joinpath(outdir, "PMIP4_CESM2-PaleoCalibr_$(experiment)_ocean.nc")
    rm(path; force=true)
    write_ocean(path, fields, [
        "title" => "PMIP4 CESM2-PaleoCalibr $experiment ocean and sea-ice climatology on a regular 1° grid",
        "model" => "CESM2-PaleoCalibr", "experiment" => experiment, "case" => case,
        "references" => REFERENCES, "doi" => "10.5065/bdr7-wt42",
        "license" => "Creative Commons Attribution 4.0 International (CC BY 4.0)",
        "missing" => join(missing_, ","),
        "original_data" => "$DIR/$case.pop.h.{TEMP_top,TEMP_0-2200m,IFRAC,MOC}.*.nc",
        provenance_attrib("paleoclimate")...])
    println("Wrote $path", isempty(missing_) ? "" : ", missing: $(join(missing_, ", "))")
end

Sys.which("cdo") === nothing && error("cdo not found (on Albedo: module load cdo)")
outdir = prepared_dir("Zhu2022_PaleoCalibr")
mkpath(outdir)
mkpath(fesmdata_dir("work"))
workdir = mktempdir(fesmdata_dir("work"))
for (experiment, case) in CASES
    prepare(experiment, case, outdir, workdir)
end
