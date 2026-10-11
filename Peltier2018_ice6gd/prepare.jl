# Prepare ICE-6G_D (VM5a) (Peltier et al., 2018) for remapping: ice thickness, grounded
# ice thickness and topography of Antarctica (south of 60°S) from 122.5 ka to 0.25 ka
# after present on the Gaussian grid of the model (1024 x 512, the 86 southernmost
# latitudes), from the isostasy_data archive (datamanifest key isostasy_data_v0_2), as
# one prepared NetCDF file with a time dimension, $FESMDATA_WORK/prepared/Peltier2018_ice6gd/Peltier2018_ICE6G_D.nc,
# with H_ice, H_ice_grounded and z_topo and the latitude bounds of the Gaussian grid.
#
# Usage:
#     julia --project=Peltier2018_ice6gd Peltier2018_ice6gd/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Peltier2018_ice6gd/Peltier2018_ICE6G_D.nc Antarctica

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

"""
    gaussian_latitudes(n) -> (lat, edges)

Gaussian latitudes of a grid with `n` latitudes (ascending, degrees: the zeros of the
Legendre polynomial of degree `n`) and the `n + 1` edges of their cells, whose sines
are the cumulated Gauss weights (so each cell has the area of its weight).
"""
function gaussian_latitudes(n)
    x, w = zeros(n), zeros(n)
    for i in 1:n
        z = cos(pi * (i - 0.25) / (n + 0.5))
        dp = 0.0
        for _ in 1:100
            p1, p2 = 1.0, 0.0
            for j in 1:n
                p1, p2 = ((2j - 1) * z * p1 - (j - 1) * p2) / j, p1
            end
            dp = n * (z * p1 - p2) / (z^2 - 1)
            dz = p1 / dp
            z -= dz
            abs(dz) < 1e-15 && break
        end
        x[i], w[i] = z, 2 / ((1 - z^2) * dp^2)
    end
    x, w = reverse(x), reverse(w)
    s = clamp.(vcat(-1.0, -1.0 .+ cumsum(w)), -1.0, 1.0)
    s[end] = 1.0
    return asind.(x), asind.(s)
end

const KEY = "isostasy_data_v0_2"
const NLAT_GLOBAL = 512         # Gaussian grid of the model: 1024 x 512

db = manifest()
dir = get_dataset_path(db, KEY)
isdir(dir) || (dir = download_dataset(db, KEY))
root = joinpath(dir, only(filter(startswith("JanJereczek-isostasy_data"), readdir(dir))))
file(var) = joinpath(root, "ice_history", "ICE6G_D", "ICE6GD_$var.nc")

# Source fields (Lon, Lat, Time) in Julia order; Lon 0:360/1024:..., Lat -89.73:-59.88,
# Time in ka BP from 122.5 to -0.25 (the last slice is 250 years after present: the ice
# thickness of 0 ka, the grounded ice and topography of the sea-level solver then)
lon0, lat, t = NCDataset(file("IceT")) do ds
    Float64.(ds["Lon"][:]), Float64.(ds["Lat"][:]), Float64.(ds["Time"][:])
end
issorted(lat) || error("ICE6GD_IceT.nc: latitudes not ascending")
issorted(t; rev=true) || error("ICE6GD_IceT.nc: times not from the oldest")
lon = mod.(lon0 .+ 180, 360) .- 180
ix = sortperm(lon)
lon = lon[ix]

# Gaussian latitudes of the global grid and the edges of their cells (the latitudes of
# the files differ from the exact ones by up to 2e-4°, single precision in the source)
lat_g, edges_g = gaussian_latitudes(NLAT_GLOBAL)
jy = [argmin(abs.(lat_g .- l)) for l in lat]
maximum(abs.(lat_g[jy] .- lat)) < 1e-3 || error("latitudes are not those of the $NLAT_GLOBAL Gaussian grid")
jy == jy[1]:jy[end] || error("latitudes are not consecutive on the Gaussian grid")
lat_bnds = permutedims(hcat(edges_g[jy], edges_g[jy.+1]))       # (2, nlat)

# name => (source file and variable, long_name)
const FIELDS = [
    "H_ice" => ("IceT", "ice thickness"),
    "H_ice_grounded" => ("IceG", "grounded ice thickness"),
    "z_topo" => ("Topo", "topography (bedrock altitude plus grounded ice thickness; sea floor in the ocean)"),
]

data = Dict{String,Array{Float32,3}}()
for (name, (var, _)) in FIELDS
    NCDataset(file(var)) do ds
        (Float64.(ds["Lat"][:]) == lat && Float64.(ds["Time"][:]) == t) || error("ICE6GD_$var.nc: different grid or times")
        data[name] = Float32.(ds[var].var[:, :, :])[ix, :, :]
    end
end
path = joinpath(prepared_dir("Peltier2018_ice6gd"), "Peltier2018_ICE6G_D.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",);
           attrib=["units" => "degrees_north", "standard_name" => "latitude", "bounds" => "lat_bnds",
                   "comment" => "Gaussian latitudes (the 86 southernmost of 512)"])
    defVar(ds, "lat_bnds", lat_bnds, ("nv", "lat"); attrib=["units" => "degrees_north"])
    defVar(ds, "time", round.(1000 .* t), ("time",);
           attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)"])
    for (name, (var, long_name)) in FIELDS
        defVar(ds, name, data[name], ("lon", "lat", "time"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "m", "long_name" => long_name, "source_file" => "ICE6GD_$var.nc"])
    end
    ds.attrib["title"] = "ICE-6G_D (VM5a) ice thickness and topography of Antarctica, 122.5-0 ka " *
                         "(Peltier et al., 2018)"
    ds.attrib["references"] = "Peltier, W. R., Argus, D. F. and Drummond, R.: Comment on \"An assessment " *
                              "of the ICE-6G_C (VM5a) glacial isostatic adjustment model\" by Purcell et " *
                              "al., J. Geophys. Res. Solid Earth, 123, 2019-2028, 2018; Argus, D. F., " *
                              "Peltier, W. R., Drummond, R. and Moore, A. W.: The Antarctica component " *
                              "of postglacial rebound model ICE-6G_C (VM5a) based on GPS positioning, " *
                              "exposure age dating of ice thicknesses, and relative sea level histories, " *
                              "Geophys. J. Int., 198, 537-563, 2014; Peltier, W. R., Argus, D. F. and " *
                              "Drummond, R.: Space geodesy constrains ice age terminal deglaciation: The " *
                              "global ICE-6G_C (VM5a) model, J. Geophys. Res. Solid Earth, 120, 450-487, " *
                              "2015; files from isostasy_data v0.2.0 (Swierczek-Jereczek, 2024), " *
                              "doi:10.5281/zenodo.11175418"
    ds.attrib["doi"] = "10.1002/2016JB013844"
    ds.attrib["license"] = "Supporting information of an AGU article (Wiley standard terms, no open " *
                           "licence), obtained through the isostasy_data archive (CC BY 4.0); " *
                           "redistribution assumed to be allowed; cite Peltier et al. (2018), Argus et " *
                           "al. (2014) and Peltier et al. (2015)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
end
println("Wrote $path")
