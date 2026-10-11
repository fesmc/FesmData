# Prepare the sediment properties of North America and Greenland of Gowan et al. (2019)
# for remapping: grain size, sediment distribution and their combination (classes) on
# the 5 km Lambert conformal conic grid of the data, as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/Gowan2019_sed/Gowan2019_sed.nc.
#
# Usage:
#     julia --project=Gowan2019_sed Gowan2019_sed/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Gowan2019_sed/Gowan2019_sed.nc Laurentide

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

dir = joinpath(download_dataset(manifest(), "gowan2019_geology"), "data", "netcdf")    # downloads it if missing

# Lambert conformal conic of the shapefiles and NetCDF files (Clarke 1866 ellipsoid,
# as in their WKT; data/readme.txt calls it EPSG:3979, which has the same parameters on
# GRS80).
const PROJ = "+proj=lcc +lat_0=49 +lon_0=-95 +lat_1=49 +lat_2=77 +x_0=0 +y_0=0 +ellps=clrk66 +units=m"
const FILL = Int32(-1)

# The three files are on the same 5 km grid (cell centres, ascending x and y), with the
# classes as floats and NaN where there are no data.
function read_classes(file, var)
    NCDataset(joinpath(dir, file)) do ds
        x, y = Float64.(ds["x"][:]), Float64.(ds["y"][:])
        dimnames(ds[var]) == ("x", "y") || error("$file: unexpected dimensions $(dimnames(ds[var]))")
        A = nomissing(ds[var][:, :], NaN)
        x, y, map(a -> isnan(a) ? FILL : Int32(a), A)
    end
end
x, y, grain = read_classes("grain_size.nc", "z")
x2, y2, distribution = read_classes("distribution.nc", "z")
x3, y3, composite = read_classes("final_sed.nc", "Band1")
(x == x2 == x3 && y == y2 == y3) || error("the grids of the files differ")
(all(≈(5000), diff(x)) && all(≈(5000), diff(y))) || error("expected a 5 km grid")

# composite (final_sed.nc, converted from the shapefile) is 3 * distribution + grain
# size, with distribution 0 blanket, 1 veneer, 2 rock and grain size 0 sand, 1 silt,
# 2 clay (data/readme.txt and the attributes of the shapefile). grain_size.nc follows
# the readme (1 clay, 2 sand, 3 silt), but distribution.nc has 2 for rock and 3 for
# veneer (the readme says 2 veneer, 3 rock), and 1 (blanket) where there are no data:
# it is recoded to the readme (1 blanket, 2 veneer, 3 rock) and set missing where the
# other two are.
nodata = composite .== FILL
(grain .== FILL) == nodata || error("grain size and composite differ in coverage")
all(in(Int32(1):Int32(3)), distribution) || error("distribution: unexpected classes")
all(==(Int32(1)), distribution[nodata]) || error("distribution: expected 1 where there are no data")
distribution = map(d -> d == 2 ? Int32(3) : d == 3 ? Int32(2) : d, distribution)
distribution[nodata] .= FILL
grain_index = Dict(Int32(2) => 0, Int32(3) => 1, Int32(1) => 2)    # sand, silt, clay
mismatch = count(k -> composite[k] != 3 * (distribution[k] - 1) + grain_index[grain[k]], findall(.!nodata))
println("composite differs from distribution and grain size in $mismatch of $(count(.!nodata)) cells")
mismatch <= 10 || error("composite does not match distribution and grain size")

fields = [("grain", grain, "grain size of the surface sediments", Int32[1, 2, 3], "clay sand silt"),
          ("distribution", distribution, "sediment distribution", Int32[1, 2, 3],
           "blanket veneer rock"),
          ("composite", composite, "sediment distribution and grain size", Int32.(0:8),
           "blanket_sand blanket_silt blanket_clay veneer_sand veneer_silt veneer_clay " *
           "rock_sand rock_silt rock_clay")]

path = joinpath(prepared_dir("Gowan2019_sed"), "Gowan2019_sed.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "lambert_conformal_conic",
                                             "longitude_of_central_meridian" => -95.0,
                                             "latitude_of_projection_origin" => 49.0,
                                             "standard_parallel" => [49.0, 77.0],
                                             "false_easting" => 0.0, "false_northing" => 0.0,
                                             "semi_major_axis" => 6378206.4,
                                             "inverse_flattening" => 294.9786982,
                                             "proj_params" => PROJ])
    for (name, F, long_name, values, meanings) in fields
        defVar(ds, name, F, ("x", "y"); fillvalue=FILL, deflatelevel=1,
               attrib=["units" => "1", "long_name" => long_name, "flag_values" => values,
                       "flag_meanings" => meanings, "grid_mapping" => "crs"])
    end
    ds["distribution"].attrib["comment"] = "blanket: continuous sediment cover; veneer: discontinuous; " *
                                           "rock: mostly bare rock"
    ds.attrib["title"] = "Sediment properties of North America, Greenland and Iceland for ice sheet " *
                         "models (Gowan et al., 2019)"
    ds.attrib["references"] = "Gowan, E. J., Niu, L., Knorr, G. and Lohmann, G.: Geology datasets in " *
                              "North America, Greenland and surrounding areas for use with ice sheet models, " *
                              "Earth Syst. Sci. Data, 11, 375-391, doi:10.5194/essd-11-375-2019, 2019; " *
                              "data: doi:10.1594/PANGAEA.895889"
    ds.attrib["doi"] = "10.1594/PANGAEA.895889"
    ds.attrib["license"] = "CC BY 4.0 (PANGAEA, doi:10.1594/PANGAEA.895889)"
    ds.attrib["comment"] = "data/netcdf/grain_size.nc, distribution.nc and final_sed.nc (composite); " *
                           "distribution recoded to 1 blanket, 2 veneer, 3 rock (2 and 3 are swapped in " *
                           "distribution.nc with respect to its readme) and missing where there are no data"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("sediment"))
end
println("Wrote $path")
