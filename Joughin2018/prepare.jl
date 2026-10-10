# Prepare the MEaSUREs multi-year Greenland ice velocity mosaic (NSIDC-0670 v1, 250 m;
# Joughin et al., 2018) for remapping: $FESMDATA_WORK/prepared/Joughin2018/Joughin2018_VEL.nc,
# on the 250 m grid of the mosaic (EPSG:3413), with the eastward and northward surface
# velocity (rotated from the components along the x and y axes of the grid), the speed and
# the errors along the grid axes.
#
# Usage:
#     julia -t 8 --project=Joughin2018 Joughin2018/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Joughin2018/Joughin2018_VEL.nc Greenland --name=VEL-Joughin2018

using FesmUtils
using NCDatasets
import ArchGDAL as AG

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "nsidc0670_v1_greenland_vel"

"""
    read_tif(path) -> (x, y, proj, A)

Cell centres (m, ascending), PROJ string (m) and band 1 (Float32, NaN for no data) of a
north-up GeoTIFF.
"""
function read_tif(path)
    AG.read(path) do ds
        x0, dx, rx, y0, ry, dy = AG.getgeotransform(ds)
        (rx == 0 && ry == 0 && dy < 0) || error("$path: not a north-up grid")
        nx, ny = AG.width(ds), AG.height(ds)
        x = x0 .+ dx .* ((1:nx) .- 0.5)
        y = reverse(y0 .+ dy .* ((1:ny) .- 0.5))
        proj = strip(AG.toPROJ4(AG.importWKT(AG.getproj(ds))))
        b = AG.getband(ds, 1)
        nd = AG.getnodatavalue(b)
        A = reverse(AG.read(b); dims=2)
        return collect(x), collect(y), proj, map(v -> v == nd ? NaN32 : Float32(v), A)
    end
end

dir = download_dataset(manifest(), KEY)
tif(c) = joinpath(dir, "greenland_vel_mosaic250_$(c)_v1.tif")
x, y, proj, vx = read_tif(tif("vx"))
occursin("+units=m", proj) || error("projection of the mosaic not in metres: $proj")
vy, ex, ey = (read_tif(tif(c))[4] for c in ("vy", "ex", "ey"))

# Eastward and northward components (the grid of the mosaic is polar stereographic)
g = ProjGrid("nsidc0670", x ./ 1000, y ./ 1000, replace(proj, "+units=m" => "+units=km"))
ue, vn = rotate_to_geographic(grid_angle(g), vx, vy)
speed = hypot.(vx, vy)
vx = vy = nothing
GC.gc()

path = joinpath(prepared_dir("Joughin2018"), "Joughin2018_VEL.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "crs", Int32(0), (); attrib=["proj_params" => proj, "epsg_code" => "EPSG:3413",
                                            "long_name" => "NSIDC Sea Ice Polar Stereographic North"])
    fields = (("ux_srf", ue, "eastward surface velocity", "eastward_land_ice_surface_velocity"),
              ("uy_srf", vn, "northward surface velocity", "northward_land_ice_surface_velocity"),
              ("uxy_srf", speed, "surface speed", "land_ice_surface_speed"),
              ("ux_srf_err", ex, "error of the surface velocity along the x axis of EPSG:3413", ""),
              ("uy_srf_err", ey, "error of the surface velocity along the y axis of EPSG:3413", ""))
    for (name, F, long_name, std) in fields
        attrib = ["units" => "m/yr", "long_name" => long_name, "grid_mapping" => "crs"]
        isempty(std) || push!(attrib, "standard_name" => std)
        defVar(ds, name, Float32.(F), ("x", "y"); fillvalue=NaN32, deflatelevel=1, attrib)
    end
    ds.attrib["title"] = "Greenland ice surface velocity, multi-year mosaic 1995-2015 (MEaSUREs NSIDC-0670 v1)"
    ds.attrib["references"] = "Joughin, I., Smith, B. and Howat, I.: A complete map of Greenland ice " *
                              "velocity derived from satellite data collected over 20 years, J. Glaciol., " *
                              "64(243), 1-11, doi:10.1017/jog.2017.73, 2018. Data: Joughin, I., Smith, B. " *
                              "and Howat, I.: MEaSUREs Multi-year Greenland Ice Sheet Velocity Mosaic, " *
                              "Version 1, NASA NSIDC DAAC, doi:10.5067/QUA5Q9SVMSJG, 2016"
    ds.attrib["doi"] = "10.5067/QUA5Q9SVMSJG"
    ds.attrib["license"] = "NASA Earth science data, no restrictions on use or redistribution " *
                           "(cite the data set and the article)"
    ds.attrib["comment"] = "ux_srf and uy_srf are rotated from the x and y components of the mosaic; " *
                           "ux_srf_err and uy_srf_err are the errors of the x and y components (EPSG:3413 axes)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("velocity"))
end
println("Wrote $path")
