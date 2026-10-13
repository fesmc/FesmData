# Prepare the Earth structure of Pan et al. (2022) for remapping: the lithosphere
# thickness (pan2022.llz) and the 3D mantle viscosity (pan2022.nc) on their global 0.5°
# grid, from the isostasy_data archive (datamanifest key isostasy_data_v0_2), as one
# prepared NetCDF file, $FESMDATA_PREPARED/Pan2022_litho/Pan2022_EarthStructure.nc,
# with z_litho and log10_visc (on depth).
#
# Usage:
#     julia --project=Pan2022_litho Pan2022_litho/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_PREPARED/Pan2022_litho/Pan2022_EarthStructure.nc Antarctica

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "isostasy_data_v0_2"
const R_EARTH = 6371e3      # Earth radius of the model (m): depth = R_EARTH - r

db = manifest()
dir = get_dataset_path(db, KEY)
isdir(dir) || (dir = download_dataset(db, KEY))
root = joinpath(dir, only(filter(startswith("JanJereczek-isostasy_data"), readdir(dir))))

# Longitudes to -180:180 (ascending), dropping a repeated column (360 = 0, or a
# duplicated 0): returns the longitudes and the column indices to keep.
function lon_columns(lon)
    l = mod.(Float64.(lon) .+ 180, 360) .- 180
    keep = unique(i -> l[i], eachindex(l))
    ix = keep[sortperm(l[keep])]
    return l[ix], ix
end

# Lithosphere thickness: text file "Lon. Lat. Depth(km)", lon 0:0.5:360 varying
# fastest, lat 90:-0.5:-90
M = readdlm(joinpath(root, "earth_structure", "lithothickness", "pan2022.llz"); skipstart=1)
lon_t = unique(M[:, 1])
lat_t = unique(M[:, 2])
size(M, 1) == length(lon_t) * length(lat_t) || error("pan2022.llz is not a full lon-lat grid")
T = reshape(Float64.(M[:, 3]), length(lon_t), length(lat_t))
isequal(T[1, :], T[end, :]) || error("pan2022.llz: columns at 0° and 360° differ")
lon, ix = lon_columns(lon_t)
iy = sortperm(lat_t)
lat = Float64.(lat_t[iy])
z_litho = Float32.(1e3 .* T[ix, iy])

# Viscosity: log10 of the viscosity in Pa s (variable eta, "Pascal seconds"), (lon, lat,
# r) in Julia order, lon -179.5:0.5:180 with 0 repeated, lat -90:0.5:90, r in m
vpath = joinpath(root, "earth_structure", "viscosity", "pan2022.nc")
visc, depth = NCDataset(vpath) do ds
    lon_raw = ds["lon"][:]
    lon_v, ixv = lon_columns(lon_raw)
    E = Float64.(ds["eta"].var[:, :, :])
    for l in unique(lon_raw)
        i = findall(==(l), lon_raw)
        all(k -> isequal(E[k, :, :], E[i[1], :, :]), i) || error("$vpath: repeated longitude $l with different values")
    end
    lat_v = Float64.(ds["lat"][:])
    (lon_v == lon && sort(lat_v) == lat) || error("$vpath is not on the grid of pan2022.llz")
    r = Float64.(ds["r"][:])
    iz = sortperm(r; rev=true)                                # surface first
    E[ixv, sortperm(lat_v), iz], R_EARTH .- r[iz]
end

path = joinpath(prepared_dir("Pan2022_litho"), "Pan2022_EarthStructure.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "depth", depth, ("depth",);
           attrib=["units" => "m", "standard_name" => "depth", "positive" => "down",
                   "long_name" => "depth below the surface (Earth radius 6371 km minus radius)"])
    defVar(ds, "z_litho", z_litho, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "m", "long_name" => "lithosphere thickness"])
    defVar(ds, "log10_visc", Float32.(visc), ("lon", "lat", "depth"); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "log10(Pa s)", "long_name" => "log10 of mantle viscosity in Pa s"])
    ds.attrib["title"] = "Lithosphere thickness and 3D mantle viscosity (Pan et al., 2022)"
    ds.attrib["references"] = "Pan, L., Milne, G. A., Latychev, K., Goldberg, S. L., Austermann, J., " *
                              "Hoggard, M. J. and Mitrovica, J. X.: The influence of lateral Earth " *
                              "structure on inferences of global ice volume during the Last Glacial " *
                              "Maximum, Quat. Sci. Rev., 290, 107644, 2022; files from isostasy_data " *
                              "v0.2.0 (Swierczek-Jereczek, 2024), doi:10.5281/zenodo.11175418"
    ds.attrib["doi"] = "10.1016/j.quascirev.2022.107644"
    ds.attrib["license"] = "No licence stated: not published by the authors, obtained by personal " *
                           "communication for isostasy_data (archived under CC BY 4.0, doi:10.5281/zenodo.11175418); " *
                           "cite Pan et al. (2022)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("solidearth"))
end
println("Wrote $path")
