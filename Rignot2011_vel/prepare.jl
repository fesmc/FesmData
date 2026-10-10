# Prepare the MEaSUREs InSAR-based Antarctica ice velocity map (NSIDC-0484 v2, 450 m;
# Rignot et al., 2011; Mouginot et al., 2012, 2017) for remapping:
# $FESMDATA_WORK/prepared/Rignot2011_vel/Rignot2011_VEL.nc, on the 450 m grid of the map
# (EPSG:3031), with the eastward and northward surface velocity (rotated from the
# components along the x and y axes of the grid), the speed and the errors along the
# grid axes.
#
# Usage:
#     julia -t 8 --project=Rignot2011_vel Rignot2011_vel/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Rignot2011_vel/Rignot2011_VEL.nc Antarctica --name=VEL-Rignot2011

using FesmUtils
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "nsidc0484_v2_antarctica_vel"
const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

# Field `name` (y, x in the file) as (x, y) with ascending y, Float32 with NaN for no data
# (the _FillValue 0 of the file).
function read_field(ds, name, iy)
    v = ds[name]
    fill = v.attrib["_FillValue"]
    A = v.var[:, :]                         # raw values; NCDatasets gives (x, y)
    return map(a -> a == fill ? NaN32 : Float32(a), view(A, :, iy))
end

src = download_dataset(manifest(), KEY)
x, y, vx, vy, ex, ey = NCDataset(src) do ds
    cs = ds["coord_system"].attrib
    (cs["latitude_of_projection_origin"] == -90 && cs["standard_parallel"] == -71 &&
     cs["straight_vertical_longitude_from_pole"] == 0 && cs["ellipsoid"] == "WGS84") ||
        error("$src: unexpected projection: $(Dict(cs))")
    dimnames(ds["VX"]) == ("x", "y") || error("$src: VX is not on (x, y)")
    x, y = ds["x"][:], ds["y"][:]
    issorted(x) || error("$src: x is not ascending")
    iy = sortperm(y)
    return x, y[iy], (read_field(ds, n, iy) for n in ("VX", "VY", "ERRX", "ERRY"))...
end

# Eastward and northward components (the grid of the map is polar stereographic)
g = ProjGrid("nsidc0484", x ./ 1000, y ./ 1000, replace(PROJ, "+units=m" => "+units=km"))
ue, vn = rotate_to_geographic(grid_angle(g), vx, vy)
speed = hypot.(vx, vy)
vx = vy = nothing
GC.gc()

path = joinpath(prepared_dir("Rignot2011_vel"), "Rignot2011_VEL.nc")
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
        attrib = ["units" => "m/yr", "long_name" => long_name, "grid_mapping" => "crs"]
        isempty(std) || push!(attrib, "standard_name" => std)
        defVar(ds, name, Float32.(F), ("x", "y"); fillvalue=NaN32, deflatelevel=1, attrib)
    end
    ds.attrib["title"] = "Antarctic ice surface velocity, 1995-2016 (MEaSUREs NSIDC-0484 v2)"
    ds.attrib["references"] = "Rignot, E., Mouginot, J. and Scheuchl, B.: Ice flow of the Antarctic " *
                              "Ice Sheet, Science, 333(6048), 1427-1430, doi:10.1126/science.1208336, 2011. " *
                              "Mouginot, J., Rignot, E., Scheuchl, B. and Millan, R.: Comprehensive " *
                              "annual ice sheet velocity mapping using Landsat-8, Sentinel-1, and " *
                              "RADARSAT-2 data, Remote Sens., 9(4), 364, doi:10.3390/rs9040364, 2017. " *
                              "Data: Rignot, E., Mouginot, J. and Scheuchl, B.: MEaSUREs InSAR-Based " *
                              "Antarctica Ice Velocity Map, Version 2, NASA NSIDC DAAC, " *
                              "doi:10.5067/D7GK8F5J8M8R, 2017"
    ds.attrib["doi"] = "10.5067/D7GK8F5J8M8R"
    ds.attrib["license"] = "NASA Earth science data, no restrictions on use or redistribution " *
                           "(cite the data set and the articles)"
    ds.attrib["comment"] = "ux_srf and uy_srf are rotated from the x and y components of the map; " *
                           "ux_srf_err and uy_srf_err are the errors of the x and y components (EPSG:3031 axes)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("velocity"))
end
println("Wrote $path")
