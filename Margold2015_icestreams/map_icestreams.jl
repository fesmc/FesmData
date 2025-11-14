cd(@__DIR__)
import Pkg; Pkg.activate(".")
# add CSV, Shapefile, Proj, GeoDataFrames, GeoFormatTypes, Rasters, NCDatasets, CairoMakie

using CSV
using Shapefile
using Proj
using GeoDataFrames
using GeoFormatTypes
using Rasters
using NCDatasets
using CairoMakie

"""
    parse_wkt_projection(wkt_string::String) -> Dict

Parse a WKT (Well-Known Text) projection string and extract all parameters
into a structured dictionary.

# Arguments
- `wkt_string::String`: The WKT projection string from a .prj file

# Returns
- `Dict`: Dictionary containing the WKT string and all extracted parameters

# Example
```julia
wkt = read("file.prj", String)
params = parse_wkt_projection(wkt)
println(params["projection"])
println(params["central_meridian"])
```
"""
function parse_wkt_projection(wkt_string::String)
    result = Dict{String, Any}(
        "wkt" => wkt_string
    )
    
    # Extract PROJCS name
    if occursin(r"PROJCS\[\"([^\"]+)\"", wkt_string)
        result["projcs_name"] = match(r"PROJCS\[\"([^\"]+)\"", wkt_string).captures[1]
    end
    
    # Extract GEOGCS name
    if occursin(r"GEOGCS\[\"([^\"]+)\"", wkt_string)
        result["geogcs_name"] = match(r"GEOGCS\[\"([^\"]+)\"", wkt_string).captures[1]
    end
    
    # Extract DATUM
    if occursin(r"DATUM\[\"([^\"]+)\"", wkt_string)
        result["datum"] = match(r"DATUM\[\"([^\"]+)\"", wkt_string).captures[1]
    end
    
    # Extract SPHEROID parameters
    spheroid_match = match(r"SPHEROID\[\"([^\"]+)\",([0-9.]+),([0-9.]+)\]", wkt_string)
    if spheroid_match !== nothing
        result["spheroid_name"] = spheroid_match.captures[1]
        result["semi_major_axis"] = parse(Float64, spheroid_match.captures[2])
        result["inverse_flattening"] = parse(Float64, spheroid_match.captures[3])
    end
    
    # Extract PRIMEM
    primem_match = match(r"PRIMEM\[\"([^\"]+)\",([0-9.-]+)\]", wkt_string)
    if primem_match !== nothing
        result["prime_meridian"] = primem_match.captures[1]
        result["prime_meridian_offset"] = parse(Float64, primem_match.captures[2])
    end
    
    # Extract angular unit
    unit_degree_match = match(r"UNIT\[\"Degree\",([0-9.]+)\]", wkt_string)
    if unit_degree_match !== nothing
        result["angular_unit"] = "Degree"
        result["angular_unit_conversion"] = parse(Float64, unit_degree_match.captures[1])
    end
    
    # Extract PROJECTION
    if occursin(r"PROJECTION\[\"([^\"]+)\"", wkt_string)
        result["projection"] = match(r"PROJECTION\[\"([^\"]+)\"", wkt_string).captures[1]
    end
    
    # Extract all PARAMETER values
    parameters = Dict{String, Float64}()
    for param_match in eachmatch(r"PARAMETER\[\"([^\"]+)\",([0-9.-]+)\]", wkt_string)
        param_name = param_match.captures[1]
        param_value = parse(Float64, param_match.captures[2])
        
        # Store with both original name and lowercase/underscore version
        parameters[param_name] = param_value
        
        # Create friendly key names
        friendly_key = lowercase(replace(param_name, " " => "_"))
        result[friendly_key] = param_value
    end
    result["parameters"] = parameters
    
    # Extract linear unit (usually at the end)
    unit_match = match(r"UNIT\[\"(Meter|Metre|Foot|Feet[^\"]*)\",([0-9.]+)\]\]$", wkt_string)
    if unit_match !== nothing
        result["linear_unit"] = unit_match.captures[1]
        result["linear_unit_conversion"] = parse(Float64, unit_match.captures[2])
    end
    
    return result
end


"""
    load_projection_from_file(prj_file::String) -> Dict

Load and parse a .prj file directly.

# Arguments
- `prj_file::String`: Path to the .prj file

# Returns
- `Dict`: Dictionary containing the WKT string and all extracted parameters
"""
function load_projection_from_file(prj_file::String)
    wkt_string = Base.read(prj_file, String)
    return parse_wkt_projection(wkt_string)
end

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

# Load the ice-stream data from shapefile, to check things out
shp = GeoDataFrames.read("ISshp/IS_polygons.shp")
transform!(shp, :Stable_ID => ByRow(x -> parse(Int, x)) => :Stable_ID)
#plot(shp[!,:geomtery]) # Looks correct!

# Filter to LGM too
lgm_stream_numbers = CSV.read("lgm_ice_streams_Stokes2016.txt",DataFrame)
lgm_stream_numbers = lgm_stream_numbers[!,1]
shp_lgm = filter(row -> row.Stable_ID in lgm_stream_numbers, shp)

begin
    shp_grd = load_projection_from_file("ISshp/IS_polygons.prj")
    # Wrap the WKT string in the proper type
    wkt_string = Base.read("ISshp/IS_polygons.prj", String)
    crs = GeoFormatTypes.WellKnownText(GeoFormatTypes.CRS(), wkt_string)


    # Define bounds in projected coordinates (meters)
    # For a Canada-focused projection, reasonable bounds might be:
    # These are arbitrary but sensible for Canadian territory
    x_min = -2_200_000.0  # 2500 km west of central meridian
    x_max =  3_400_000.0  # 3500 km east of central meridian
    y_min = -1_000_000.0  # At the latitude of origin
    y_max =  4_300_000.0  # 4500 km north

    # Resolution in meters (50 km = 50,000 m)
    resolution = 10_000.0

    # Generate coordinate arrays
    x_coords = x_min:resolution:x_max
    y_coords = y_min:resolution:y_max

    # Create data matrix of zeros
    n_rows = length(y_coords)
    n_cols = length(x_coords)

    # Create the raster
    r = Raster(zeros(Float64, n_cols, n_rows),
        dims=(X(x_coords), Y(y_coords)),
        crs=crs,
        name=:my_variable)

    println("Raster dimensions: ", size(r))
    println("X range: ", extrema(x_coords), " meters")
    println("Y range: ", extrema(y_coords), " meters")
end

# Define new NetCDF dataset
begin
    # Define output filename
    path_out = "Margold2015_icestreams.nc"

    # store convenient name
    proj_dict = shp_grd

    NCDataset(path_out, "c") do ds
        
        # Create CRS variable
        defVar(ds, "crs", Int32, ())
        
        # Define reference information
        ds.attrib["source"] = "Margold, M., Stokes, C. R., Clark, C. D. & Kleman, J.: Ice streams in the Laurentide Ice Sheet: a new mapping inventory, J. Maps 11, 380–395, doi:10.1080/17445647.2014.912036, 2015."

        # Store full WKT
        ds["crs"].attrib["crs_wkt"] = proj_dict["wkt"]
        ds["crs"].attrib["spatial_ref"] = proj_dict["wkt"]
        
        # CF-compliant attributes
        ds["crs"].attrib["grid_mapping_name"] = "lambert_conformal_conic"
        ds["crs"].attrib["longitude_of_central_meridian"] = proj_dict["central_meridian"]
        ds["crs"].attrib["latitude_of_projection_origin"] = proj_dict["latitude_of_origin"]
        ds["crs"].attrib["standard_parallel"] = [
            proj_dict["standard_parallel_1"], 
            proj_dict["standard_parallel_2"]
        ]
        ds["crs"].attrib["false_easting"] = proj_dict["false_easting"]
        ds["crs"].attrib["false_northing"] = proj_dict["false_northing"]
        ds["crs"].attrib["semi_major_axis"] = proj_dict["semi_major_axis"]
        ds["crs"].attrib["inverse_flattening"] = proj_dict["inverse_flattening"]
        
        # Additional metadata
        ds["crs"].attrib["horizontal_datum_name"] = proj_dict["datum"]
        ds["crs"].attrib["reference_ellipsoid_name"] = proj_dict["spheroid_name"]
        ds["crs"].attrib["proj4_string"] = "+proj=lcc +lat_0=49 +lon_0=-95 +lat_1=49 +lat_2=77 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs"
        
        # Create coordinate variables
        nx, ny = size(r)
        defDim(ds, "x", nx)
        defDim(ds, "y", ny)

        xvar = defVar(ds, "x", Float64, ("x",))
        xvar.attrib["standard_name"] = "projection_x_coordinate"
        xvar.attrib["units"] = "m"
        xvar[:] = collect(r.dims[1].val.data) #.* 1e-3
        
        yvar = defVar(ds, "y", Float64, ("y",))
        yvar.attrib["standard_name"] = "projection_y_coordinate"
        yvar.attrib["units"] = "m"
        yvar[:] = collect(r.dims[2].val.data) #.* 1e-3
        
        # Add data variables, link it to the CRS:
        maskvar = defVar(ds, "mask", Int8, ("x","y"))
        maskvar.attrib["long_name"] = "Stream mask (1=stream,0=no stream)"
        maskvar.attrib["grid_mapping"] = "crs"
        maskvar[:,:] = r[:,:]

        masklgmvar = defVar(ds, "mask_lgm", Int8, ("x","y"))
        masklgmvar.attrib["long_name"] = "LGM stream mask (1=stream,0=no stream)"
        masklgmvar.attrib["grid_mapping"] = "crs"
        masklgmvar[:,:] = r[:,:]

    end
    
    println("Initialized ", path_out)
    
end

# Write fields in new dataset file
begin
    ds = NCDataset("Margold2015_icestreams.nc", "a")
    
    # Read shapefile and convert to raster grid
    shp = GeoDataFrames.read("ISshp/IS_polygons.shp")
    transform!(shp, :Stable_ID => ByRow(x -> parse(Int, x)) => :Stable_ID)
    #shp.geometry = GeoDataFrames.reproject(shp.geometry, proj_str, GeoFormatTypes.EPSG(4326))
    mask = Rasters.rasterize(last,shp,fill=1,to=r)
    Rasters.replace_missing!(mask, 0)
    # Write to the file
    ds["mask"][:, :] = mask
    
    # Also for LGM
    lgm_stream_numbers = CSV.read("lgm_ice_streams_Stokes2016.txt",DataFrame)
    lgm_stream_numbers = lgm_stream_numbers[!,1]
    shp_lgm = filter(row -> row.Stable_ID in lgm_stream_numbers, shp)
    #shp.geometry = GeoDataFrames.reproject(shp.geometry, proj_str, GeoFormatTypes.EPSG(4326))
    mask = Rasters.rasterize(last,shp_lgm,fill=1,to=r)
    Rasters.replace_missing!(mask, 0)
    # Write to the file
    ds["mask_lgm"][:, :] = mask
    
    close(ds)
end

# Now the NetCDF dataset has been written on original projection at a chosen resolution.
# Use code below to map to a given domain+grid

# Generate a raster object matching our target grid,
# and load a grid description file. Note this should be created
# externally before calling the next function.

grid_name_tgt = "LIS-16KM"
rg, gd = gen_grid_raster(grid_name_tgt)

# Define new NetCDF dataset
begin
    path_out = "$(grid_name_tgt)_Margold2015_icestreams.nc"
    ds = NCDataset(path_out, "c")

    # Define reference information
    ds.attrib["source"] = "Margold, M., Stokes, C. R., Clark, C. D. & Kleman, J.: Ice streams in the Laurentide Ice Sheet: a new mapping inventory, J. Maps 11, 380–395, doi:10.1080/17445647.2014.912036, 2015."

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

    xvar = defVar(ds, "x", Float64, ("x",))
    xvar.attrib["standard_name"] = "projection_x_coordinate"
    xvar.attrib["units"] = "m"
    xvar[:] = collect(rg.dims[1].val.data)
    
    yvar = defVar(ds, "y", Float64, ("y",))
    yvar.attrib["standard_name"] = "projection_y_coordinate"
    yvar.attrib["units"] = "m"
    yvar[:] = collect(rg.dims[2].val.data)
    
    maskvar = defVar(ds, "mask", Int8, ("x","y"))
    maskvar.attrib["long_name"] = "Stream mask (1=stream,0=no stream)"
    maskvar.attrib["grid_mapping"] = "crs"
    maskvar[:,:,1] = rg

    masklgmvar = defVar(ds, "mask_lgm", Int8, ("x","y"))
    masklgmvar.attrib["long_name"] = "LGM stream mask (1=stream,0=no stream)"
    masklgmvar.attrib["grid_mapping"] = "crs"
    masklgmvar[:,:,1] = rg

    close(ds)

    println("Initialized ", path_out)
    
end

# Open original dataset and our target grid dataset,
# map variable to target grid and write to file.

begin
    ds = NCDataset("Margold2015_icestreams.nc")
    dsg = NCDataset("$(grid_name_tgt)_Margold2015_icestreams.nc", "a")

    # Create the raster: lon/lat
    r = Rasters.Raster(ds["mask"])
    r = Rasters.setcrs(r, crs) 
    maskg = Rasters.resample(r; to=rg, method=:mode)
    Rasters.replace_missing!(maskg, 0)
    dsg["mask"][:,:] = maskg[:,:]

    # LGM mask
    r = Rasters.Raster(ds["mask_lgm"])
    r = Rasters.setcrs(r, crs) 
    maskg = Rasters.resample(r; to=rg, method=:mode)
    Rasters.replace_missing!(maskg, 0)
    dsg["mask_lgm"][:,:] = maskg[:,:]

    close(ds)
    close(dsg)
end

# DONE!