# Prepare the 3D mantle viscosity of Bagge et al. (2021) for remapping: 8 of the 18 Earth
# structures of the GFZ data publication (datamanifest key bagge2021_visc) on their
# Gaussian grid (512 x 256) and 164 layers, as a prepared NetCDF file,
# $FESMDATA_PREPARED/Bagge2021_visc/Bagge2021_visc.nc, with log10_visc (on depth and
# structure), the latitude bounds of the Gaussian grid and the depth bounds of the layers.
#
# Usage:
#     julia --project=Bagge2021_visc Bagge2021_visc/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_PREPARED/Bagge2021_visc/Bagge2021_visc.nc Antarctica

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

const KEY = "bagge2021_visc"
const R_EARTH = 6371e3          # Earth radius of VILMA (m): depth = R_EARTH - radius

# Structures v_<r>_<RVP> (reduction factor r of the activation enthalpy, radial
# viscosity profile RVP), in the order of the dimension `structure`: the 8 of the 18 that
# Bagge et al. (2021) use with NAICE (Sect. 3, Table S1), all r with s16 and r = 0.4
# (their reference value) with sc06 and sc06b. Add others (r = 0.2857, 0.3, 0.4, 0.5,
# 0.75, 1.0 with RVP s16, sc06, sc06b) to this list to prepare them too.
const STRUCTURES = [("0.2857", "s16"), ("0.3", "s16"), ("0.4", "s16"), ("0.5", "s16"),
                    ("0.75", "s16"), ("1.0", "s16"), ("0.4", "sc06"), ("0.4", "sc06b")]
names = ["v_$(f)_$(p)" for (f, p) in STRUCTURES]

db = manifest()
dir = get_dataset_path(db, KEY)
isdir(dir) || (dir = download_dataset(db, KEY))

# lgvisc (lon, lat, radius) in Julia order; lon 0:360/512:..., lat 89.46:-89.46
# (Gaussian), radius ascending in m (the units attribute says km); the same grid and
# radii in all files
read_structure(name) = NCDataset(joinpath(dir, "$name.nc")) do ds
    Float64.(ds["lon"][:]), Float64.(ds["lat"][:]), Float64.(ds["radius"][:]), ds["lgvisc"].var[:, :, :]
end
lon0, lat0, r0, _ = read_structure(names[1])
maximum(r0) < R_EARTH || error("radius of $(names[1]) is not in m")

# Longitudes to -180:180, latitudes ascending, layers from the surface down
lon = mod.(lon0 .+ 180, 360) .- 180
ix = sortperm(lon)
iy = sortperm(lat0)
iz = sortperm(r0; rev=true)
lon, lat, r = lon[ix], lat0[iy], r0[iz]

log10_visc = Array{Float32}(undef, length(lon), length(lat), length(r), length(names))
for (k, name) in enumerate(names)
    l, b, rr, V = read_structure(name)
    (l == lon0 && b == lat0 && rr == r0) || error("$name.nc is not on the grid of $(names[1]).nc")
    log10_visc[:, :, :, k] = Float32.(V[ix, iy, iz])
end

# Gaussian latitudes and their cell edges (sin of the edges = cumulated weights)
lat_g, lat_edges = gaussian_latitudes(length(lat))
maximum(abs.(lat_g .- lat)) < 1e-6 || error("latitudes are not the Gaussian latitudes")
lat_bnds = permutedims(hcat(lat_edges[1:end-1], lat_edges[2:end]))       # (2, nlat)

# Layers: the radii are the mid-points of layers (5 km thick at the top, 10 km below
# 5951 km, about 40 km below 5701 km), from the surface (6371 km) down to the
# core-mantle boundary (3480 km)
r_edges = vcat(R_EARTH, (r[1:end-1] .+ r[2:end]) ./ 2, r[end] - (r[end-1] - r[end]) / 2)
depth = R_EARTH .- r
depth_bnds = permutedims(hcat(R_EARTH .- r_edges[1:end-1], R_EARTH .- r_edges[2:end]))   # (2, ndepth)

path = joinpath(prepared_dir("Bagge2021_visc"), "Bagge2021_visc.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",);
           attrib=["units" => "degrees_north", "standard_name" => "latitude", "bounds" => "lat_bnds",
                   "comment" => "Gaussian latitudes (256)"])
    defVar(ds, "lat_bnds", lat_bnds, ("nv", "lat"); attrib=["units" => "degrees_north"])
    defVar(ds, "depth", depth, ("depth",);
           attrib=["units" => "m", "standard_name" => "depth", "positive" => "down", "bounds" => "depth_bnds",
                   "long_name" => "depth below the surface of the layer mid-point (Earth radius 6371 km minus radius)"])
    defVar(ds, "depth_bnds", depth_bnds, ("nv", "depth"); attrib=["units" => "m"])
    defVar(ds, "structure", Int32.(1:length(names)), ("structure",);
           attrib=["long_name" => "Earth structure v_<reduction_factor>_<radial_viscosity_profile>",
                   "units" => "1",
                   "structure_names" => join(names, " "),
                   "reduction_factor" => [parse(Float64, f) for (f, _) in STRUCTURES],
                   "radial_viscosity_profile" => join(last.(STRUCTURES), " ")])
    defVar(ds, "log10_visc", log10_visc, ("lon", "lat", "depth", "structure");
           fillvalue=NaN32, deflatelevel=1, chunksizes=[length(lon), length(lat), 1, 1],
           attrib=["units" => "log10(Pa s)", "long_name" => "log10 of mantle viscosity in Pa s"])
    ds.attrib["title"] = "3D mantle viscosity, 8 of the 18 Earth structures (Bagge et al., 2021)"
    ds.attrib["references"] = "Bagge, M., Klemann, V., Steinberger, B., Latinovic, M. and Thomas, M.: " *
                              "Glacial-isostatic adjustment models using geodynamically constrained 3D " *
                              "Earth structures, Geochem. Geophys. Geosyst., 22, e2021GC009853, 2021, " *
                              "doi:10.1029/2021GC009853; data: Bagge, M., Klemann, V., Steinberger, B., " *
                              "Latinovic, M. and Thomas, M.: 3D Earth structures for glacial-isostatic " *
                              "adjustment models, V. 1.0, GFZ Data Services, 2020"
    ds.attrib["doi"] = "10.5880/GFZ.1.3.2020.004"
    ds.attrib["license"] = "CC BY 4.0 (GFZ Data Services)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("solidearth"))
end
println("Wrote $path")
