# Prepare the Hazzard & Richards (2024) Antarctic geothermal heat flow for remapping:
# the 0.5° lon-lat grids of HR24_grids.zip (OSF, datamanifest key hazzardrichards2024_ghf)
# as a prepared NetCDF file, $FESMDATA_WORK/prepared/HazzardRichards2024_ghf/HazzardRichards2024_GHF.nc,
# with the mean and standard deviation of the heat flow, the crustal thermal
# conductivity and the upper-crustal heat production.
#
# Usage:
#     julia --project=HazzardRichards2024_ghf HazzardRichards2024_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/HazzardRichards2024_ghf/HazzardRichards2024_GHF.nc Antarctica

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "hazzardrichards2024_ghf"

# Prepared field => (original grid, units, long_name)
const FIELDS = [
    "ghf" => ("HR24_GHF_mean", "mW m-2", "geothermal heat flow"),
    "ghf_sd" => ("HR24_GHF_std", "mW m-2", "standard deviation of geothermal heat flow"),
    "k_crust" => ("HR24_k_mean", "W m-1 K-1", "crustal thermal conductivity at 0 degC and 0 GPa (k0)"),
    "k_crust_sd" => ("HR24_k_std", "W m-1 K-1", "standard deviation of crustal thermal conductivity (k0)"),
    "h_upper_crust" => ("HR24_h_mean", "uW m-3", "upper-crustal radiogenic heat production"),
    "h_upper_crust_sd" => ("HR24_h_std", "uW m-3", "standard deviation of upper-crustal radiogenic heat production"),
]

db = manifest()
dir = get_dataset_path(db, KEY)
isdir(dir) || (dir = download_dataset(db, KEY))

# GMT grids (gridline registered) on lon 0:0.5:360 and lat -90:0.5:-60: lon = 360
# repeats lon = 0 and is dropped, and the longitudes are shifted to -180:180.
function read_grd(name)
    NCDataset(joinpath(dir, "model_output", "$name.grd")) do ds
        lon, lat = ds["x"][:], ds["y"][:]
        z = Float32.(coalesce.(ds["z"][:, :], NaN32))      # (x, y)
        (lon[1] == 0 && lon[end] == 360) || error("$name: longitudes $(lon[1]):$(lon[end]), expected 0:360")
        isequal(z[1, :], z[end, :]) || error("$name: columns at 0° and 360° differ")
        lon, z = lon[1:end-1], z[1:end-1, :]
        ix = sortperm(mod.(lon .+ 180, 360) .- 180)
        return mod.(lon[ix] .+ 180, 360) .- 180, lat, z[ix, :]
    end
end

lon, lat, _ = read_grd(FIELDS[1][2][1])

path = joinpath(prepared_dir("HazzardRichards2024_ghf"), "HazzardRichards2024_GHF.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, (grd, units, long_name)) in FIELDS
        l, b, z = read_grd(grd)
        (l == lon && b == lat) || error("$grd is not on the grid of $(FIELDS[1][2][1])")
        defVar(ds, name, z, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => units, "long_name" => long_name, "source_file" => "$grd.grd"])
    end
    ds.attrib["title"] = "Antarctic geothermal heat flow, crustal conductivity and heat production (Hazzard and Richards, 2024)"
    ds.attrib["references"] = "Hazzard, J. A. N. and Richards, F. D.: Antarctic geothermal heat flow, crustal " *
                              "conductivity and heat production inferred from seismological data, " *
                              "Geophys. Res. Lett., 51, e2023GL106274, 2024"
    ds.attrib["doi"] = "10.1029/2023GL106274"
    ds.attrib["license"] = "No licence stated (OSF project https://osf.io/54zam, HR24_grids.zip); " *
                           "redistribution of derived products assumed to be allowed"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
