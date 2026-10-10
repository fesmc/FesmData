# Prepare CERES EBAF Ed4.2.1 (Loeb et al., 2018) for remapping: the monthly climatology
# 2001-2020 of the TOA and surface radiative fluxes on the 1° grid, from the monthly means
# in the ICDC data pool on Levante, as
#     $FESMDATA_WORK/prepared/Loeb2018_ceres/Loeb2018_CERES-EBAF_2001-2020.nc
#
# Usage:
#     julia --project=Loeb2018_ceres Loeb2018_ceres/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Loeb2018_ceres/Loeb2018_CERES-EBAF_2001-2020.nc all

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "ceres_ebaf_ed4_2_1"
const Y0, Y1 = 2001, 2020        # full years (CERES starts in 2000-03)
const EBAF = "CERES_EBAF_Ed4.2.1_Subset_200003-202512.nc"
const EBAF_TOA = "CERES_EBAF-TOA_Ed4.2.1_Subset_200003-202601.nc"

# name => (file, long_name), from the field <name>_mon. Fluxes in W m-2: at the TOA,
# shortwave (sw) and longwave (lw) outgoing (upward), net downward (solar - sw - lw); at
# the surface, down and up as named, net downward. Clear sky: clr_c for the cloud-free
# areas of a cell (observed), clr_t for the whole cell (clouds removed in the radiative
# transfer, as in climate models). Cloud radiative effect (cre): all-sky - clr_t.
const FIELDS = [
    "solar" => (EBAF_TOA, "TOA incoming solar flux"),
    "toa_sw_all" => (EBAF, "TOA outgoing shortwave flux, all-sky"),
    "toa_sw_clr_c" => (EBAF, "TOA outgoing shortwave flux, clear-sky (cloud-free areas)"),
    "toa_sw_clr_t" => (EBAF, "TOA outgoing shortwave flux, clear-sky (total region)"),
    "toa_lw_all" => (EBAF, "TOA outgoing longwave flux, all-sky"),
    "toa_lw_clr_c" => (EBAF, "TOA outgoing longwave flux, clear-sky (cloud-free areas)"),
    "toa_lw_clr_t" => (EBAF, "TOA outgoing longwave flux, clear-sky (total region)"),
    "toa_net_all" => (EBAF, "TOA net downward flux, all-sky"),
    "toa_net_clr_c" => (EBAF, "TOA net downward flux, clear-sky (cloud-free areas)"),
    "toa_net_clr_t" => (EBAF, "TOA net downward flux, clear-sky (total region)"),
    "toa_cre_sw" => (EBAF, "TOA shortwave cloud radiative effect (all-sky - clr_t)"),
    "toa_cre_lw" => (EBAF, "TOA longwave cloud radiative effect (all-sky - clr_t)"),
    "toa_cre_net" => (EBAF, "TOA net cloud radiative effect (all-sky - clr_t)"),
    "sfc_sw_down_all" => (EBAF, "surface downward shortwave flux, all-sky"),
    "sfc_sw_down_clr_t" => (EBAF, "surface downward shortwave flux, clear-sky (total region)"),
    "sfc_sw_up_all" => (EBAF, "surface upward shortwave flux, all-sky"),
    "sfc_sw_up_clr_t" => (EBAF, "surface upward shortwave flux, clear-sky (total region)"),
    "sfc_lw_down_all" => (EBAF, "surface downward longwave flux, all-sky"),
    "sfc_lw_down_clr_t" => (EBAF, "surface downward longwave flux, clear-sky (total region)"),
    "sfc_lw_up_all" => (EBAF, "surface upward longwave flux, all-sky"),
    "sfc_lw_up_clr_t" => (EBAF, "surface upward longwave flux, clear-sky (total region)"),
    "sfc_net_sw_all" => (EBAF, "surface net downward shortwave flux, all-sky"),
    "sfc_net_sw_clr_t" => (EBAF, "surface net downward shortwave flux, clear-sky (total region)"),
    "sfc_net_lw_all" => (EBAF, "surface net downward longwave flux, all-sky"),
    "sfc_net_lw_clr_t" => (EBAF, "surface net downward longwave flux, clear-sky (total region)"),
    "sfc_net_tot_all" => (EBAF, "surface net downward radiative flux, all-sky"),
    "sfc_net_tot_clr_t" => (EBAF, "surface net downward radiative flux, clear-sky (total region)"),
    "sfc_cre_net_sw" => (EBAF, "surface net shortwave cloud radiative effect (all-sky - clr_t)"),
    "sfc_cre_net_lw" => (EBAF, "surface net longwave cloud radiative effect (all-sky - clr_t)"),
    "sfc_cre_net_tot" => (EBAF, "surface net cloud radiative effect (all-sky - clr_t)"),
]

# Monthly climatology Y0-Y1 of the field `name`_mon of the file `path`, (lon, lat, month)
function climatology(path, name)
    NCDataset(path) do ds
        t = ds["time"][:]
        it = findall(d -> Y0 <= Dates.year(d) <= Y1, t)
        length(it) == 12 * (Y1 - Y0 + 1) && it == it[1]:it[end] ||
            error("$path: expected all months of $Y0-$Y1")
        A = Float64.(coalesce.(ds[name*"_mon"][:, :, it[1]:it[end]], NaN))
        months = Dates.month.(t[it])
        C = Array{Float32}(undef, size(A, 1), size(A, 2), 12)
        for m in 1:12
            C[:, :, m] = sum(A[:, :, months.==m]; dims=3) ./ count(==(m), months)
        end
        return C
    end
end

dir = download_dataset(manifest(), KEY)
lon, lat = NCDataset(joinpath(dir, EBAF)) do ds
    Float64.(ds["lon"][:]), Float64.(ds["lat"][:])
end
NCDataset(joinpath(dir, EBAF_TOA)) do ds
    (Float64.(ds["lon"][:]) == lon && Float64.(ds["lat"][:]) == lat) || error("EBAF and EBAF-TOA grids differ")
end
# Longitudes 0.5:359.5 to -179.5:179.5
lon = ifelse.(lon .>= 180, lon .- 360, lon)
perm = sortperm(lon)

path = joinpath(prepared_dir("Loeb2018_ceres"), "Loeb2018_CERES-EBAF_$Y0-$Y1.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon[perm], ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
    for (name, (file, long_name)) in FIELDS
        C = climatology(joinpath(dir, file), name)[perm, :, :]
        any(isnan, C) && error("$name has missing values")
        defVar(ds, name, C, ("lon", "lat", "month"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "W m-2", "long_name" => long_name])
    end
    ds.attrib["title"] = "CERES EBAF Ed4.2.1 TOA and surface radiative fluxes, monthly climatology $Y0-$Y1"
    ds.attrib["references"] = "Loeb, N. G., Doelling, D. R., Wang, H., et al.: Clouds and the Earth's Radiant " *
                              "Energy System (CERES) Energy Balanced and Filled (EBAF) Top-of-Atmosphere (TOA) " *
                              "Edition-4.0 Data Product, J. Climate, 31, 895-918, 2018; Kato, S., Rose, F. G., " *
                              "Rutan, D. A., et al.: Surface Irradiances of Edition 4.0 CERES EBAF Data Product, " *
                              "J. Climate, 31, 4501-4527, 2018 (doi:10.1175/JCLI-D-17-0523.1)"
    ds.attrib["doi"] = "10.1175/JCLI-D-17-0208.1"
    ds.attrib["license"] = "NASA Earth science data, open without restriction on use or redistribution " *
                           "(NASA Earth Science Data and Information Policy); cite the data products"
    ds.attrib["period"] = "$Y0-$Y1"
    ds.attrib["comment"] = "Monthly climatology ($Y0-$Y1) of the CERES EBAF Ed4.2.1 monthly means " *
                           "(data DOIs 10.5067/TERRA-AQUA-NOAA20/CERES/EBAF_L3B004.2.1 and " *
                           "10.5067/TERRA-AQUA-NOAA20/CERES/EBAF-TOA_L3B004.2.1), from the ICDC data pool " *
                           "at DKRZ (/pool/data/ICDC/atmosphere/ceres_ebaf/DATA)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("atmosphere"))
end
println("Wrote $path")
