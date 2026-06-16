#
# Resample the regular lon/lat Batchelor ice masks onto a projected target
# grid, writing e.g. `NH-32KM_Batchelor2019_ice_masks.nc`.
#
# Prerequisite: the lon/lat dataset `Batchelor2019_ice_masks.nc` must already
# exist (run `build_lonlat_dataset.jl` first).
#
# Usage:
#     julia --project=. build_projected_dataset.jl [--grid NAME] [--lonlat-nc PATH]
#
# The target grid is described by `../maps/grid_<grid>.txt`, which must exist
# beforehand (generate with `cdo griddes`).
#
cd(@__DIR__)
import Pkg; Pkg.activate(".")

using Proj
using GeoFormatTypes
using Rasters
import ArchGDAL   # backend required by Rasters.resample
using NCDatasets

const SOURCE_ATTR = "Batchelor et al. (2019) https://www.nature.com/articles/s41467-019-11601-2"

# ---------------------------------------------------------------------------
# Grid description helpers
# ---------------------------------------------------------------------------

"""
Read and parse a cdo derived (cdo griddes) grid description file.
"""
function read_cdo_griddes(filename)

    grid_info = Dict{String, Any}()

    for line in eachline(filename)
        if !isempty(line) && !startswith(line, "#") # Skip empty or commented lines
            key, value = split(line, "=")
            grid_info[strip(key)] = strip(value)
        end
    end

    out = Dict{String, Any}()
    out["gridtype"] = grid_info["gridtype"]
    out["xunits"]   = grid_info["xunits"]
    out["yunits"]   = grid_info["yunits"]
    out["xsize"] = parse(Int, grid_info["xsize"])
    out["ysize"] = parse(Int, grid_info["ysize"])
    out["xfirst"] = parse(Float64, grid_info["xfirst"])
    out["xinc"] = parse(Float64, grid_info["xinc"])
    out["yfirst"] = parse(Float64, grid_info["yfirst"])
    out["yinc"] = parse(Float64, grid_info["yinc"])

    proj_keys = [
        "grid_mapping",
        "grid_mapping_name",
        "straight_vertical_longitude_from_pole",
        "latitude_of_projection_origin",
        "standard_parallel",
        "false_easting",
        "false_northing",
        "semi_major_axis",
        "inverse_flattening",
        "proj_params"]

    for key in proj_keys
        if key in keys(grid_info)
            if key in ["grid_mapping","grid_mapping_name","proj_params"]
                out[key] = grid_info[key]
            else
                out[key] = parse(Float64, grid_info[key])
            end
        end
    end

    out["proj_str"] = "undefined"

    if "proj_params" in keys(out)
        out["proj_str"] = out["proj_params"]
    else
        # Generate a valid proj_str
        if "grid_mapping_name" in keys(out) &&
            out["grid_mapping_name"] == "polar_stereographic"

            out["proj_str"] = "+proj=stere " *
            "+lat_0=$(out["latitude_of_projection_origin"]) " *
            "+lat_ts=$(out["standard_parallel"]) " *
            "+lon_0=$(out["straight_vertical_longitude_from_pole"]) " *
            "+a=$(out["semi_major_axis"]) " *
            "+rf=$(out["inverse_flattening"]) " *
            "+x_0=$(out["false_easting"]) " *
            "+y_0=$(out["false_northing"]) " *
            "+units=$(out["xunits"]) +datum=WGS84"

        end
    end

    return out
end

"""
Generate a raster object that is consistent with an available cdo griddes grid
description file. Note this file should be created externally (`cdo griddes ...`)
before calling this function.
"""
function gen_grid_raster(grid_name_tgt)

    gd = read_cdo_griddes("../maps/grid_$(grid_name_tgt).txt")
    x = gd["xfirst"] .+ gd["xinc"] .* (0:gd["xsize"] .- 1)
    y = gd["yfirst"] .+ gd["yinc"] .* (0:gd["ysize"] .- 1)

    crs = ProjString(gd["proj_str"])
    r = Rasters.Raster(zeros(length(x), length(y)); dims=(X(x), Y(y)))
    r = Rasters.setcrs(r, crs)

    return r, gd
end

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

"""
Resample the lon/lat ice masks onto a projected target grid (described by
`../maps/grid_<grid_name>.txt`) and write the result to a CF-compliant NetCDF
file with grid-mapping metadata.
"""
function build_projected_dataset(grid_name; src_nc, path_out)

    if !isfile(src_nc)
        error("Lon/lat dataset '$(src_nc)' not found. " *
              "Run build_lonlat_dataset.jl first.")
    end

    rg, gd = gen_grid_raster(grid_name)
    nx, ny = size(rg)

    isfile(path_out) && rm(path_out)
    ds = NCDataset(src_nc)
    dsg = NCDataset(path_out, "c")
    try
        nt = length(ds["time"])

        dsg.attrib["source"] = SOURCE_ATTR

        # Define crs
        crsvar = defVar(dsg, "crs", Int32, ())
        proj_keys = [
            "grid_mapping",
            "grid_mapping_name",
            "straight_vertical_longitude_from_pole",
            "latitude_of_projection_origin",
            "standard_parallel",
            "false_easting",
            "false_northing",
            "semi_major_axis",
            "inverse_flattening"]
        for key in proj_keys
            crsvar.attrib[key] = gd[key]
        end

        defDim(dsg, "x", nx)
        defDim(dsg, "y", ny)
        defDim(dsg, "time", nt)

        xvar = defVar(dsg, "x", Float64, ("x",))
        xvar.attrib["standard_name"] = "projection_x_coordinate"
        xvar.attrib["units"] = gd["xunits"]
        xvar[:] = parent(lookup(rg.dims[1]))

        yvar = defVar(dsg, "y", Float64, ("y",))
        yvar.attrib["standard_name"] = "projection_y_coordinate"
        yvar.attrib["units"] = gd["yunits"]
        yvar[:] = parent(lookup(rg.dims[2]))

        timevar = defVar(dsg, "time", Float64, ("time",))
        timevar[:] = ds["time"][:]

        timelabelvar = defVar(dsg, "label", String, ("time",))
        timelabelvar[:] = ds["label"][:]

        maskvar = defVar(dsg, "mask", Int8, ("x","y","time"))
        maskvar.attrib["long_name"] = "Ice mask (1=ice,0=no ice)"
        maskvar.attrib["grid_mapping"] = "crs"

        # Reconstruct evenly-spaced lon/lat ranges. When read straight from the
        # file the coordinate vectors are not recognised as a regular range,
        # which Rasters.resample requires.
        lonv = ds["lon"][:]
        latv = ds["lat"][:]
        lon = range(lonv[1], lonv[end], length=length(lonv))
        lat = range(latv[1], latv[end], length=length(latv))

        for k in 1:nt
            r = Rasters.Raster(ds["mask"][:,:,k]; dims=(X(lon), Y(lat)))
            r = Rasters.setcrs(r, EPSG(4326))
            maskg = Rasters.resample(r; to=rg, method=:mode)
            Rasters.replace_missing!(maskg, 0)
            maskvar[:, :, k] = maskg

            println("  $(grid_name) slice $(k)/$(nt)")
        end
    finally
        close(ds)
        close(dsg)
    end

    println("Wrote ", path_out)
    return path_out
end

# ---------------------------------------------------------------------------
# Command-line interface
# ---------------------------------------------------------------------------

function parse_args(args)
    opts = Dict{String,Any}(
        "grid"      => "NH-32KM",
        "lonlat_nc" => "Batchelor2019_ice_masks.nc",
    )

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--grid"
            opts["grid"] = args[i+1]; i += 2
        elseif a == "--lonlat-nc"
            opts["lonlat_nc"] = args[i+1]; i += 2
        elseif a in ("-h", "--help")
            println("""
            Resample the lon/lat Batchelor ice masks onto a projected grid.

            Usage:
                julia --project=. build_projected_dataset.jl [options]

            Options:
                --grid NAME       Target grid, matching ../maps/grid_NAME.txt
                                  (default: NH-32KM)
                --lonlat-nc PATH  Source lon/lat NetCDF file
                                  (default: Batchelor2019_ice_masks.nc)
                -h, --help        Show this help
            """)
            exit(0)
        else
            error("Unknown argument: $(a). Use --help for usage.")
        end
    end

    return opts
end

opts = parse_args(ARGS)
grid_name = opts["grid"]
build_projected_dataset(grid_name;
    src_nc=opts["lonlat_nc"],
    path_out="$(grid_name)_Batchelor2019_ice_masks.nc")
