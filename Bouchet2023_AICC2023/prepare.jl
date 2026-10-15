# Prepare the AICC2023 ice core chronology of Bouchet et al. (2023) as records (see
# Records/README.md): the depth-age tables of EDC, EDML, NGRIP, TALDICE and Vostok
# (PANGAEA, version 2 of 2026, datamanifest keys aicc2023_<core>), each a profile at
# its site along depth (featureType profile),
# $FESMDATA_PREPARED/Bouchet2023_AICC2023/AICC2023_<core>.nc. They also give the AICC2023
# ages of the other ice core records (`aicc2023_age` of shared/records_prepare.jl).
#
# Usage:
#     julia --project=Bouchet2023_AICC2023 Bouchet2023_AICC2023/prepare.jl
#     julia fesmdata.jl record IceCores AICC2023

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

const RHO_ICE = 917.0           # kg m-3, accumulation in m ice yr-1 -> kg m-2 yr-1

# Core => PANGAEA dataset (datamanifest key aicc2023_<lowercase core>)
const DOIS = Dict("EDC" => "10.1594/PANGAEA.990377", "EDML" => "10.1594/PANGAEA.990380",
                  "NGRIP" => "10.1594/PANGAEA.990383", "TALDICE" => "10.1594/PANGAEA.990384",
                  "Vostok" => "10.1594/PANGAEA.990385")

# Columns of the tables: name => (column, scale to the units, units, long name). Ages in
# ka BP (before 1950 CE) become years ago, their uncertainties years.
const COLUMNS = [
    "age_ice_aicc2023" => ("Ice age [ka BP] (AICC2023)", 1000, "years ago", "ice age on AICC2023 (years before 1950 CE)"),
    "age_ice_aicc2023_sd" => ("Ice age unc [ka] (AICC2023)", 1000, "yr", "uncertainty (1 sigma) of the AICC2023 ice age"),
    "age_gas_aicc2023" => ("Gas age [ka BP] (AICC2023)", 1000, "years ago", "gas age on AICC2023 (years before 1950 CE)"),
    "age_gas_aicc2023_sd" => ("Gas age unc [ka] (AICC2023)", 1000, "yr", "uncertainty (1 sigma) of the AICC2023 gas age"),
    "delta_age_sd" => (r"^Age diff unc", 1000, "yr", "uncertainty (1 sigma) of the ice-gas age difference"),
    "age_ice_aicc2012" => ("Ice age [ka BP] (AICC2012)", 1000, "years ago", "ice age on AICC2012 (years before 1950 CE)"),
    "age_gas_aicc2012" => ("Gas age [ka BP] (AICC2012)", 1000, "years ago", "gas age on AICC2012 (years before 1950 CE)"),
    "acc" => ("Acc rate ice analyzed [m/a]", RHO_ICE, "kg m-2 yr-1",
              "accumulation rate of the analysis (from m ice yr-1 with an ice density of $(Int(RHO_ICE)) kg m-3)"),
    "acc_sd" => ("Acc rate ice analyzed unc [±]", RHO_ICE, "kg m-2 yr-1", "uncertainty (1 sigma) of the accumulation rate"),
    "thinning" => ("Thinning analyzed", 1, "1", "thinning function of the analysis"),
    "thinning_sd" => ("Thinning analyzed unc", 1, "1", "uncertainty (1 sigma) of the thinning function"),
    "lid" => ("LID analyzed [m]", 1, "m", "lock-in depth of the analysis"),
    "lid_sd" => ("LID analyzed unc [m]", 1, "m", "uncertainty (1 sigma) of the lock-in depth"),
    "delta_depth" => (r"^Depth diff \[m\]", 1, "m", "depth difference between ice and gas of the same age"),
    "delta_depth_sd" => (r"^Depth diff unc", 1, "m", "uncertainty (1 sigma) of the depth difference"),
]

const REFERENCES = "Bouchet, M., Landais, A., Grisart, A., Parrenin, F., Prié, F., Jacob, R., Fourré, E., " *
                   "Capron, E., Raynaud, D., Lipenkov, V. Y., Loutre, M.-F., Extier, T., Svensson, A., " *
                   "Legrain, E., Martinerie, P., Leuenberger, M., Jiang, W., Ritterbusch, F., Lu, Z.-T., and " *
                   "Yang, G.-M.: The Antarctic Ice Core Chronology 2023 (AICC2023) chronological framework and " *
                   "associated timescale for the European Project for Ice Coring in Antarctica (EPICA) Dome C " *
                   "ice core, Clim. Past, 19, 2257-2286, 2023, doi:10.5194/cp-19-2257-2023. Data: Bouchet, M. " *
                   "et al.: The Antarctic ice core chronology (AICC2023), PANGAEA, doi:10.1594/PANGAEA.961017 " *
                   "(version 2 of the tables, 2026)"

for core in AICC2023_CORES
    tab = download_dataset(manifest(), "aicc2023_$(lowercase(core))")
    t = read_pangaea(tab)
    ev = pangaea_event(tab)
    depth = nan64(column(t, "Depth ice/snow [m]"))
    issorted(depth; lt=<=) || error("$tab: depths not increasing")
    n = length(depth)
    path = aicc2023_file(core)
    mkpath(dirname(path))
    rm(path; force=true)
    NCDataset(path, "c") do ds
        defDim(ds, "station", 1)
        defDim(ds, "depth", n)
        defVar(ds, "site_name", [core], ("station",); attrib=["long_name" => "ice core site", "cf_role" => "profile_id"])
        defVar(ds, "lat", [ev.lat], ("station",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
        defVar(ds, "lon", [ev.lon], ("station",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
        defVar(ds, "z_srf", [ev.z_srf], ("station",); attrib=["units" => "m", "long_name" => "present surface elevation of the site"])
        defVar(ds, "depth", depth, ("depth",); attrib=["units" => "m", "positive" => "down", "long_name" => "depth in the core"])
        for (name, (col, scale, units, long_name)) in COLUMNS
            v = Float32.(nan64(column(t, col)) .* scale)
            defVar(ds, name, reshape(v, n, 1), ("depth", "station"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => units, "long_name" => long_name, "coordinates" => "depth lat lon"])
        end
        ds.attrib["title"] = "AICC2023 chronology of the $core ice core (Bouchet et al., 2023)"
        ds.attrib["references"] = REFERENCES
        ds.attrib["doi"] = DOIS[core]
        ds.attrib["license"] = "CC BY 4.0 (PANGAEA)"
        ds.attrib["featureType"] = "profile"
        ds.attrib["Conventions"] = "CF-1.11"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icecores"))
    end
    println("Wrote $path ($n depths, $(round(maximum(filter(isfinite, nan64(column(t, "Ice age [ka BP] (AICC2023)")))); digits=1)) ka)")
end
