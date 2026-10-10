# Prepare ICE-6G_C (VM5a) (Peltier et al., 2015) for remapping: the 48 time slices 26-0 ka
# on the 1° grid (one gzipped file each) as one prepared NetCDF file with a time dimension,
# $FESMDATA_WORK/prepared/Peltier2015_ice6g/Peltier2015_ICE6G_C.nc, with z_topo, z_srf,
# dz_topo, H_ice, f_ice and f_land.
#
# Usage:
#     julia --project=Peltier2015_ice6g Peltier2015_ice6g/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Peltier2015_ice6g/Peltier2015_ICE6G_C.nc all

using CodecZlib
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "ice6g_c_vm5a_1deg"
# The data server does not send its intermediate TLS certificate
const HOST = "www.atmosp.physics.utoronto.ca"

function original_dir()
    db = manifest()
    path = get_dataset_path(db, KEY)
    ispath(path) && return path
    return withenv(() -> download_dataset(db, KEY), "JULIA_SSL_NO_VERIFY_HOSTS" => HOST)
end

"Open a gzipped NetCDF file in memory."
open_gz(f, path) = NCDataset(f, basename(path), "r"; memory=transcode(GzipDecompressor, read(path)))

# One file per time slice, I6_C.VM5a_1deg.<age>.nc.gz, oldest first
dir = original_dir()
files = Dict(parse(Float64, m[1]) => joinpath(dir, f)
             for f in readdir(dir) for m in (match(r"^I6_C\.VM5a_1deg\.(\d+(?:\.5)?)\.nc\.gz$", f),)
             if m !== nothing)
ages = sort(collect(keys(files)); rev=true)
length(ages) == 48 || error("expected 48 time slices in $dir, found $(length(ages))")

# Longitudes 0.5:359.5 (cell centres) to -179.5:179.5
lon0, lat = open_gz(files[0.0]) do ds
    Float64.(ds["lon"].var[:]), Float64.(ds["lat"].var[:])
end
lon = ifelse.(lon0 .>= 180, lon0 .- 360, lon0)
perm = sortperm(lon)
lon = lon[perm]
nx, ny, nt = length(lon), length(lat), length(ages)

# Source fields (lat, lon in the file), _FillValue 1e20
function read_field(ds, name)
    A = Float32.(ds[name].var[:, :])[perm, :]
    A[abs.(A) .>= 1f19] .= NaN32
    return A
end

# name => (source field, scale, units, long_name)
const FIELDS = [
    "z_topo" => ("Topo", 1, "m", "topography (surface elevation, sea floor in the ocean and under ice shelves)"),
    "z_srf" => ("orog", 1, "m", "surface elevation (0 over the ocean, ice surface of ice shelves)"),
    "dz_topo" => ("Topo_Diff", 1, "m", "topography change from present (z_topo - z_topo at 0 ka)"),
    "H_ice" => ("stgit", 1, "m", "ice thickness"),
    "f_ice" => ("sftgif", 1 / 100, "1", "ice area fraction"),
    "f_land" => ("sftlf", 1 / 100, "1", "land area fraction"),
]

data = Dict(name => Array{Float32}(undef, nx, ny, nt) for (name, _) in FIELDS)
for (k, age) in enumerate(ages)
    open_gz(files[age]) do ds
        for (name, (src, scale, _, _)) in FIELDS
            data[name][:, :, k] = read_field(ds, src) .* Float32(scale)
        end
    end
end

path = joinpath(prepared_dir("Peltier2015_ice6g"), "Peltier2015_ICE6G_C.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "time", ages, ("time",);
           attrib=["units" => "ka BP", "long_name" => "age (thousands of years before present)"])
    for (name, (_, _, units, long_name)) in FIELDS
        defVar(ds, name, data[name], ("lon", "lat", "time"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => units, "long_name" => long_name])
    end
    ds.attrib["title"] = "ICE-6G_C (VM5a) ice-sheet and topography reconstruction, 26-0 ka " *
                         "(Peltier et al., 2015)"
    ds.attrib["references"] = "Peltier, W. R., Argus, D. F. and Drummond, R.: Space geodesy constrains " *
                              "ice age terminal deglaciation: The global ICE-6G_C (VM5a) model, " *
                              "J. Geophys. Res. Solid Earth, 120, 450-487, 2015; Argus, D. F., " *
                              "Peltier, W. R., Drummond, R. and Moore, A. W.: The Antarctica component " *
                              "of postglacial rebound model ICE-6G_C (VM5a) based on GPS positioning, " *
                              "exposure age dating of ice thicknesses, and relative sea level " *
                              "histories, Geophys. J. Int., 198, 537-563, 2014, doi:10.1093/gji/ggu140"
    ds.attrib["doi"] = "10.1002/2014JB011176"
    ds.attrib["license"] = "No licence stated by the provider (W. R. Peltier, University of Toronto, " *
                           "https://www.atmosp.physics.utoronto.ca/~peltier/data.php); users are " *
                           "asked to cite Peltier et al. (2015) and Argus et al. (2014)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
end
println("Wrote $path")
