# Prepare ICE-5G v1.2 (Peltier, 2004) for remapping: the 39 time slices 21-0 ka on the
# 1° grid as one prepared NetCDF file with a time dimension,
# $FESMDATA_WORK/prepared/Peltier2004_ice5g/Peltier2004_ICE5G.nc, with z_topo, H_ice and f_ice.
#
# Usage:
#     julia --project=Peltier2004_ice5g Peltier2004_ice5g/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Peltier2004_ice5g/Peltier2004_ICE5G.nc all

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "ice5g_v1_2_1deg"
# The data server does not send its intermediate TLS certificate
const HOST = "www.atmosp.physics.utoronto.ca"

function original_dir()
    db = manifest()
    path = get_dataset_path(db, KEY)
    ispath(path) && return path
    return withenv(() -> download_dataset(db, KEY), "JULIA_SSL_NO_VERIFY_HOSTS" => HOST)
end

# One file per time slice, ice5g_v1.2_<age>k_1deg.nc, oldest first
dir = original_dir()
files = Dict(parse(Float64, m[1]) => joinpath(dir, f)
             for f in readdir(dir) for m in (match(r"^ice5g_v1\.2_(\d+\.\d)k_1deg\.nc$", f),)
             if m !== nothing)
ages = sort(collect(keys(files)); rev=true)
length(ages) == 39 || error("expected 39 time slices in $dir, found $(length(ages))")

# Longitudes 0:359 (cell centres) to -180:179
lon0, lat = NCDataset(files[0.0]) do ds
    Float64.(ds["long"].var[:]), Float64.(ds["lat"].var[:])
end
lon = ifelse.(lon0 .>= 180, lon0 .- 360, lon0)
perm = sortperm(lon)
lon = lon[perm]
nx, ny, nt = length(lon), length(lat), length(ages)

# Source fields (lat, long in the file): orog, sftgit, sftgif; missing_value 1e20
function read_field(ds, name)
    A = Float32.(ds[name].var[:, :])[perm, :]
    A[abs.(A) .>= 1f19] .= NaN32
    return A
end

z_topo = Array{Float32}(undef, nx, ny, nt)
H_ice = similar(z_topo)
f_ice = similar(z_topo)
for (k, age) in enumerate(ages)
    NCDataset(files[age]) do ds
        z_topo[:, :, k] = read_field(ds, "orog")
        H_ice[:, :, k] = read_field(ds, "sftgit")
        f_ice[:, :, k] = read_field(ds, "sftgif") ./ 100   # ice mask 0 or 100 %
    end
end

path = joinpath(prepared_dir("Peltier2004_ice5g"), "Peltier2004_ICE5G.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "time", ages, ("time",);
           attrib=["units" => "ka BP", "long_name" => "age (thousands of years before present)"])
    for (name, F, units, long_name) in
        (("z_topo", z_topo, "m", "topography (surface elevation, sea floor in the ocean)"),
         ("H_ice", H_ice, "m", "ice thickness"),
         ("f_ice", f_ice, "1", "ice area fraction (ice mask: 0 or 1)"))
        defVar(ds, name, F, ("lon", "lat", "time"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => units, "long_name" => long_name])
    end
    ds.attrib["title"] = "ICE-5G (VM2) v1.2 ice-sheet reconstruction, 21-0 ka (Peltier, 2004)"
    ds.attrib["references"] = "Peltier, W. R.: Global glacial isostasy and the surface of the ice-age " *
                              "Earth: the ICE-5G (VM2) model and GRACE, Annu. Rev. Earth Planet. Sci., " *
                              "32, 111-149, 2004"
    ds.attrib["doi"] = "10.1146/annurev.earth.32.082503.144359"
    ds.attrib["license"] = "No licence stated by the provider (W. R. Peltier, University of Toronto, " *
                           "https://www.atmosp.physics.utoronto.ca/~peltier/data.php); users are " *
                           "asked to cite Peltier (2004)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
end
println("Wrote $path")
