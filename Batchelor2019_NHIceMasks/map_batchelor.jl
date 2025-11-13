cd(@__DIR__)
import Pkg; Pkg.activate(".")

using Shapefile
using Proj
using GeoDataFrames
using GeoFormatTypes
using Rasters
using NCDatasets

# 1. Output grid definition
begin
    # Define coordinate ranges
    lon = -180:0.5:180
    lat = 0:0.5:90

    # Also define times of output
    # 18 time slices available with undefined time values for some
    time_label = [
        "Early Matuyama Chron",
        "Late Gauss Chron",
        "MIS 20-24",
        "MIS 16",
        "MIS 12",
        "MIS 10",
        "MIS 8",
        "MIS 6",
        "MIS 5d",
        "MIS 5c",
        "MIS 5b",
        "MIS 5a",
        "MIS 4",
        "45 ka",
        "40 ka",
        "35 ka",
        "30 ka",
        "LGM"]         
    time = 1:length(time_label)

    nx = length(lon)
    ny = length(lat)
    nt = length(time)

    # Create the raster: lon/lat
    r = Rasters.Raster(zeros(length(lon), length(lat)); dims=(X(lon), Y(lat)))

    # Optional: add CRS metadata (e.g., WGS84)
    r = Rasters.setcrs(r, EPSG(4326))

    # Create the raster: x/y proj
    crs = ProjString("+proj=laea +lat_0=90 +lon_0=0 +x_0=0 +y_0=0 +units=m +datum=WGS84")
    x = range(-9e6,9e6,step=100e3)
    y = range(-9e6,9e6,step=100e3)
    rxy = Rasters.Raster(zeros(length(x), length(y)); dims=(X(x), Y(y)))
    rxy = Rasters.setcrs(rxy, crs)

end

# Initialize NCDataset
begin
    path_out = "Batchelor2019_ice_masks.nc"
    ds = NCDataset(path_out, "c")

    # Define reference information
    ds.attrib["source"] = "Batchelor et al. (2019) https://www.nature.com/articles/s41467-019-11601-2"

    defDim(ds, "lon", nx)
    defDim(ds, "lat", ny)
    defDim(ds, "time", nt)

    # Define coordinate variables (with CF-compliant attributes)
    lon_var = defVar(ds, "lon", Float32, ("lon",), attrib = Dict(
        "standard_name" => "longitude",
        "long_name"     => "longitude",
        "units"         => "degrees_east",
        "axis"          => "X"
    ))
    lon_var[:] = lon

    lat_var = defVar(ds, "lat", Float32, ("lat",), attrib = Dict(
        "standard_name" => "latitude",
        "long_name"     => "latitude",
        "units"         => "degrees_north",
        "axis"          => "Y"
    ))
    lat_var[:] = lat
    
    timevar = defVar(ds, "time", Float32, ("time",))
    timevar[:] = time

    timelabelvar = defVar(ds, "label", String, ("time",))
    timelabelvar[:] = time_label

    maskvar = defVar(ds, "mask", Int8, ("lon","lat","time"))
    maskvar[:,:,1] = r

    maskvar.attrib["long_name"] = " Ice mask (1=ice,0=no ice)"

    close(ds)

    println("Initialized ", path_out)
    
end

# Update fields in new dataset file
begin
    ds = NCDataset("Batchelor2019_ice_masks.nc", "a")
    
    # Update output dataset for each time slice
    for k in 1:nt
        
        # Read shapefile and convert to raster grid
        fldr_str = string(time_label[k])
        dir = "Batchelor2019_NHextent/$(fldr_str)/hypothesised ice-sheet reconstructions/"
        filename = filter(f -> endswith(f, "_best_estimate.shp"), readdir(dir))[1]
        path_now = joinpath(dir,filename)
        shp = GeoDataFrames.read(path_now)
        if k < nt
            #shp.geometry = GeoDataFrames.reproject(shp.geometry, proj_str, GeoFormatTypes.EPSG(4326))
            mask_xy = Rasters.rasterize(last,shp,fill=1,to=rxy)
            mask = Rasters.resample(mask_xy; to=r, method=:mode)
        else
            mask = rasterize(last,shp,fill=1,to=r)
        end
        
        Rasters.replace_missing!(mask, 0)
        #mask[ismissing.(mask)] .= 0

        # Write to the file
        ds["mask"][:, :, k] = mask
        
        println("Updated time index ", k)
    end

    close(ds)
end

# Now the lonlat NetCDF dataset has been written.
# Use code below to map to a given domain+grid

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
Generate a raster object that is consistent with an 
available cdo griddes grid description file.
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

# Generate a raster object matching our target grid,
# and load a grid description file. Note this should be created
# externally before calling the next function.

rg, gd = gen_grid_raster("NH-32KM")

# Define new NetCDF dataset
# Initialize NCDataset
begin
    path_out = "$(grid_name_tgt)_Batchelor2019_ice_masks.nc"
    ds = NCDataset(path_out, "c")

    # Define reference information
    ds.attrib["source"] = "Batchelor et al. (2019) https://www.nature.com/articles/s41467-019-11601-2"

    # Define crs
    crsvar = defVar(ds, "crs", Int32, () )
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

    nx, ny = size(rg)
    defDim(ds, "x", nx)
    defDim(ds, "y", ny)
    defDim(ds, "time", nt)

    xvar = defVar(ds, "x", Float64, ("x",))
    xvar.attrib["standard_name"] = "projection_x_coordinate"
    xvar.attrib["units"] = "km"
    xvar[:] = x
    
    yvar = defVar(ds, "y", Float64, ("y",))
    yvar.attrib["standard_name"] = "projection_y_coordinate"
    yvar.attrib["units"] = "km"
    yvar[:] = y
    
    timevar = defVar(ds, "time", Float64, ("time",))
    timevar[:] = time

    timelabelvar = defVar(ds, "label", String, ("time",))
    timelabelvar[:] = time_label

    maskvar = defVar(ds, "mask", Int8, ("x","y","time"))
    maskvar.attrib["long_name"] = " Ice mask (1=ice,0=no ice)"
    maskvar.attrib["grid_mapping"] = "crs"
    maskvar[:,:,1] = rg

    close(ds)

    println("Initialized ", path_out)
    
end

# Open original dataset and our target grid dataset,
# map variable to target grid and write to file.

begin
    ds = NCDataset("Batchelor2019_ice_masks.nc")
    nt = length(ds["time"])

    dsg = NCDataset("$(grid_name_tgt)_Batchelor2019_ice_masks.nc", "a")

    # Redefine corresponding lon/lat vectors here, so that they are "evenly spaced"
    # (when reading from nc file, apparently interpreted as not evenly spaced)
    lon = -180:0.5:180
    lat = 0:0.5:90

    for k in 1:nt
        # Create the raster: lon/lat
        r = Rasters.Raster(ds["mask"][:,:,k]; dims=(X(lon), Y(lat)))
        r = Rasters.setcrs(r, EPSG(4326))
        maskg = Rasters.resample(r; to=rg, method=:mode)
        dsg["mask"][:,:,k] = maskg
    end

    close(ds)
    close(dsg)
end
