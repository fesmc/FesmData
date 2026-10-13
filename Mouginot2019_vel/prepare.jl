# Prepare the MEaSUREs Phase-Based Antarctica Ice Velocity Map (NSIDC-0754 v1, 450 m;
# Mouginot et al., 2019) for remapping:
# $FESMDATA_PREPARED/Mouginot2019_vel/Mouginot2019_VEL.nc, on the 450 m grid of the
# map (EPSG:3031), with the eastward and northward surface velocity (rotated from the
# components along the x and y axes of the grid), the speed and the errors along the
# grid axes.
#
# Usage:
#     julia -t 8 --project=Mouginot2019_vel Mouginot2019_vel/prepare.jl
#     julia -t 8 fesmdata.jl remap Velocity Mouginot2019

using FesmUtils
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "nsidc0754_v1_antarctica_vel"
const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

# Field `name` (y, x in the file) as (x, y) with ascending y, Float32 with NaN for no data
# (the _FillValue of the file, NaN, or Inf: ERRX and ERRY are Inf at about 1500 points
# where the velocity is given).
function read_field(ds, name, iy)
    v = ds[name]
    fill = get(v.attrib, "_FillValue", NaN32)
    A = v.var[:, :]                         # raw values; NCDatasets gives (x, y)
    return map(a -> a == fill || !isfinite(a) ? NaN32 : Float32(a), view(A, :, iy))
end

src = download_dataset(manifest(), KEY)
x, y, vx, vy, ex, ey = NCDataset(src) do ds
    haskey(ds["VX"].attrib, "grid_mapping") || error("$src: VX has no grid_mapping")
    cs = ds[ds["VX"].attrib["grid_mapping"]].attrib
    (get(cs, "latitude_of_projection_origin", nothing) == -90 && get(cs, "standard_parallel", nothing) == -71 &&
     get(cs, "straight_vertical_longitude_from_pole", nothing) == 0) ||
        error("$src: unexpected projection: $(Dict(cs))")
    dimnames(ds["VX"]) == ("x", "y") || error("$src: VX is not on (x, y)")
    x, y = ds["x"][:], ds["y"][:]
    issorted(x) || error("$src: x is not ascending")
    iy = sortperm(y)
    return x, y[iy], (read_field(ds, n, iy) for n in ("VX", "VY", "ERRX", "ERRY"))...
end

# Eastward and northward components (the grid of the map is polar stereographic)
g = ProjGrid("nsidc0754", x ./ 1000, y ./ 1000, replace(PROJ, "+units=m" => "+units=km"))
ue, vn = rotate_to_geographic(grid_angle(g), vx, vy)
speed = hypot.(vx, vy)
vx = vy = nothing
GC.gc()

path = joinpath(prepared_dir("Mouginot2019_vel"), "Mouginot2019_VEL.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "crs", Int32(0), (); attrib=["proj_params" => PROJ, "epsg_code" => "EPSG:3031",
                                            "long_name" => "Antarctic Polar Stereographic"])
    fields = (("ux_srf", ue, "eastward surface velocity", "eastward_land_ice_surface_velocity"),
              ("uy_srf", vn, "northward surface velocity", "northward_land_ice_surface_velocity"),
              ("uxy_srf", speed, "surface speed", "land_ice_surface_speed"),
              ("ux_srf_err", ex, "error of the surface velocity along the x axis of EPSG:3031", ""),
              ("uy_srf_err", ey, "error of the surface velocity along the y axis of EPSG:3031", ""))
    for (name, F, long_name, std) in fields
        attrib = ["units" => "m yr-1", "long_name" => long_name, "grid_mapping" => "crs"]
        isempty(std) || push!(attrib, "standard_name" => std)
        defVar(ds, name, Float32.(F), ("x", "y"); fillvalue=NaN32, deflatelevel=1, attrib)
    end
    ds.attrib["title"] = "Antarctic ice surface velocity, phase-based, 1996-2018 (MEaSUREs NSIDC-0754 v1)"
    ds.attrib["references"] = "Mouginot, J., Rignot, E. and Scheuchl, B.: Continent-wide, interferometric " *
                              "SAR phase, mapping of Antarctic ice velocity, Geophys. Res. Lett., 46, " *
                              "9710-9718, doi:10.1029/2019GL083826, 2019. " *
                              "Data: Mouginot, J., Rignot, E. and Scheuchl, B.: MEaSUREs Phase-Based " *
                              "Antarctica Ice Velocity Map, Version 1, NASA NSIDC DAAC, " *
                              "doi:10.5067/PZ3NJ5RXRH10, 2019"
    ds.attrib["doi"] = "10.5067/PZ3NJ5RXRH10"
    ds.attrib["license"] = "NASA Earth science data, no restrictions on use or redistribution " *
                           "(cite the data set and the article)"
    ds.attrib["comment"] = "ux_srf and uy_srf are rotated from the x and y components of the map; " *
                           "ux_srf_err and uy_srf_err are the errors of the x and y components (EPSG:3031 axes)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("velocity"))
end
println("Wrote $path")
