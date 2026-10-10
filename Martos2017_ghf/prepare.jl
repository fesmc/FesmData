# Prepare the Martos et al. (2017) Antarctic geothermal heat flow for remapping: the
# 15 km polar stereographic grid of the PANGAEA files (x, y, z ASCII, grid points over
# the continent only) as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/Martos2017_ghf/Martos2017_GHF.nc, with ghf, ghf_sd,
# depth_curie and depth_curie_sd.
#
# Usage:
#     julia --project=Martos2017_ghf Martos2017_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Martos2017_ghf/Martos2017_GHF.nc Antarctica

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

# Polar stereographic, true scale at 71°S, WGS84 (EPSG:3031), as used for ADMAP-2
const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

# name => (manifest key, units, long_name)
const FIELDS = [
    "ghf" => ("martos2017_ghf", "mW m-2", "geothermal heat flow"),
    "ghf_sd" => ("martos2017_ghf_uncertainty", "mW m-2", "uncertainty of geothermal heat flow"),
    "depth_curie" => ("martos2017_curie_depth", "km", "Curie depth (positive downwards)"),
    "depth_curie_sd" => ("martos2017_curie_depth_uncertainty", "km", "uncertainty of Curie depth"),
]

"Read an x, y, z file (x, y in m) into its columns."
function read_xyz(path)
    a = readdlm(path, Float64)
    return a[:, 1], a[:, 2], a[:, 3]
end

"Regular axis through the values `v` (spacing `dx`), checking that they lie on it."
function axis(v, dx)
    ax = minimum(v):dx:maximum(v)
    all(isinteger, (v .- first(ax)) ./ dx) || error("coordinates are not on a regular $dx m grid")
    return ax
end

db = manifest()
x0, y0, _ = read_xyz(download_dataset(db, first(FIELDS[1][2])))
const DX = 15000.0
xs, ys = axis(x0, DX), axis(y0, DX)
nx, ny = length(xs), length(ys)
ix = round.(Int, (x0 .- first(xs)) ./ DX) .+ 1
iy = round.(Int, (y0 .- first(ys)) ./ DX) .+ 1
length(unique(zip(ix, iy))) == length(x0) || error("duplicate grid points")

data = Dict{String,Matrix{Float32}}()
for (name, (key, _, _)) in FIELDS
    x, y, z = read_xyz(download_dataset(db, key))
    (x == x0 && y == y0) || error("$key is not on the same points as $(FIELDS[1][2][1])")
    F = fill(NaN32, nx, ny)
    for k in eachindex(z)
        F[ix[k], iy[k]] = z[k]
    end
    data[name] = F
end

path = joinpath(prepared_dir("Martos2017_ghf"), "Martos2017_GHF.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "x", collect(xs), ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", collect(ys), ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "polar_stereographic", Int32(0), ();
           attrib=["grid_mapping_name" => "polar_stereographic",
                   "straight_vertical_longitude_from_pole" => 0.0,
                   "latitude_of_projection_origin" => -90.0,
                   "standard_parallel" => -71.0,
                   "false_easting" => 0.0, "false_northing" => 0.0,
                   "semi_major_axis" => 6378137.0, "inverse_flattening" => 298.257223563,
                   "proj_params" => PROJ, "crs_epsg" => "EPSG:3031"])
    for (name, (_, units, long_name)) in FIELDS
        defVar(ds, name, data[name], ("x", "y"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => units, "long_name" => long_name,
                       "grid_mapping" => "polar_stereographic"])
    end
    ds.attrib["title"] = "Antarctic geothermal heat flow and Curie depth (Martos et al., 2017)"
    ds.attrib["references"] = "Martos, Y. M., Catalan, M., Jordan, T. A., Golynsky, A., Golynsky, D., " *
                              "Eagles, G., and Vaughan, D. G.: Heat flux distribution of Antarctica unveiled, " *
                              "Geophys. Res. Lett., 44, 11417-11426, doi:10.1002/2017GL075609, 2017"
    ds.attrib["doi"] = "10.1594/PANGAEA.882503"
    ds.attrib["license"] = "CC BY 3.0 (PANGAEA)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
