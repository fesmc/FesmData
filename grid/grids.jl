cd(@__DIR__)
using NCDatasets
using Proj
using GeographicLib
using LinearAlgebra

function generate_grid(domain::String,grid_name::String,
    xc::AbstractVector{<:Real},yc::AbstractVector{<:Real};
    proj_str::String="",xunits::String="km",yunits::String="km")
    # Generate a grid object containing all handy information for grid defintion
    # Here: generate from predefined axis information
    
    # Define grid object
    grid = Dict{String,Any}()

    # Add values

    grid["domain"] = domain
    grid["grid_name"] = grid_name
    grid["proj_str"] = proj_str
    grid["proj_cf"] = proj_to_cf(grid["proj_str"])

    grid["xunits"] = xunits
    grid["yunits"] = yunits
    
    grid["x0"], grid["x1"] = extrema(xc)
    grid["y0"], grid["y1"] = extrema(yc)
    grid["dx"] = xc[2] - xc[1]
    grid["nx"] = size(xc,1)
    grid["dy"] = yc[2] - yc[1]
    grid["ny"] = size(yc,1)
    
    # Save coordinate vectors

    grid["xc"] = xc
    grid["yc"] = yc

    # Add x2D, y2D
    grid["x2D"] = xc .* ones(1, grid["ny"])
    grid["y2D"] = ones(grid["nx"], 1) .* yc'

    # Get latitude and longitude of projection
    grid["lat2D"], grid["lon2D"] = projected_to_latlon(grid["xc"], grid["yc"], grid["proj_str"])
    
    # Get cell areas
    grid["area"] = cell_areas(grid["lat2D"], grid["lon2D"])

    return grid
end

function generate_grid(domain::String,grid_name::String,
    x0::Real,dx::Real,nx::Integer,y0::Real,dy::Real,ny::Integer;
    proj_str::String="",xunits::String="km",yunits::String="km")
    # Generate a grid object containing all handy information for grid defintion
    # Here: generate from axis information
    
    # Define grid object
    grid = Dict{String,Any}()

    # Add values

    grid["domain"] = domain
    grid["grid_name"] = grid_name
    grid["proj_str"] = proj_str
    grid["proj_cf"] = proj_to_cf(grid["proj_str"])
    
    grid["xunits"] = xunits
    grid["yunits"] = yunits
    
    grid["x0"] = Float64(x0)
    grid["dx"] = Float64(dx)
    grid["nx"] = nx
    grid["y0"] = Float64(y0)
    grid["dy"] = Float64(dy)
    grid["ny"] = ny
    
    grid["x1"] = grid["x0"] + grid["dx"] * (grid["nx"] - 1)
    grid["y1"] = grid["y0"] + grid["dy"] * (grid["ny"] - 1)
    
    # Construct coordinate vectors
    grid["xc"] = collect( range(start=grid["x0"],step=grid["dx"],length=grid["nx"]) )
    grid["yc"] = collect( range(start=grid["y0"],step=grid["dy"],length=grid["ny"]) )

    # Add x2D, y2D
    grid["x2D"] = grid["xc"] .* ones(1, grid["ny"])
    grid["y2D"] = ones(grid["nx"], 1) .* grid["yc"]'

    # Get latitude and longitude of projection
    grid["lat2D"], grid["lon2D"] = projected_to_latlon(grid["xc"], grid["yc"], grid["proj_str"])
    
    # Get cell areas
    grid["area"] = cell_areas(grid["lat2D"], grid["lon2D"])

    return grid
end

function generate_grid(domain::String,grid_name::String;
            griddes::String = "../maps/grid_<GRID_NAME>.txt")
    # Generate a grid object containing all handy information for grid defintion
    # Here: generate from a cdo grid description file

    # Load cdo grid description file
    griddes = replace(griddes,"<GRID_NAME>" => grid_name)
    info = read_cdo_grid_file(griddes,grid_name,domain)

    grid = generate_grid(   domain,grid_name,
                            info["xfirst"],info["xinc"],info["xsize"],
                            info["yfirst"],info["yinc"],info["ysize"],
                            proj_str=info["proj_str"],xunits=info["xunits"], 
                            yunits=info["yunits"] )

    return grid
end

function read_cdo_grid_file(filepath::String,grid_name::String,domain::String)
    grid_info = Dict{String, Any}()

    for line in eachline(filepath)
        # Remove leading/trailing whitespace
        line = strip(line)

        # Skip empty lines or comment lines (if any)
        isempty(line) && continue
        startswith(line, "#") && continue

        # Split by '=' and strip whitespace
        if occursin("=", line)
            key, value = strip.(split(line, "=", limit=2))

            # Try to parse value as number (Int or Float), otherwise leave as String
            if occursin(r"^-?\d+\.?\d*$", value)
                parsed_value = parse(Float64, value)
                # Convert to Int if it’s actually an integer
                if isinteger(parsed_value)
                    parsed_value = Int(parsed_value)
                end
                grid_info[key] = parsed_value
            else
                grid_info[key] = String(value)
            end
        end
    end

    # Define projection string based on grid_info
    grid_info["proj_str"] = "+proj=stere " *
               "+lat_0=$(grid_info["latitude_of_projection_origin"]) " *
               "+lat_ts=$(grid_info["standard_parallel"]) " *
               "+lon_0=$(grid_info["straight_vertical_longitude_from_pole"]) " *
               "+k=1 +x_0=$(grid_info["false_easting"] * 1000) +y_0=$(grid_info["false_northing"] * 1000) " * # Convert to meters
               "+a=$(grid_info["semi_major_axis"]) +rf=$(grid_info["inverse_flattening"]) +units=m +no_defs" # Units set to meters

    # Add domain and grid_name too
    grid_info["domain"] = domain
    grid_info["grid_name"] = grid_name

    return grid_info
end

function proj_str_to_crs(proj_str)
    # Return individual crs parameters of proj string

    proj = Dict()

    for param in split(proj_str)
        if occursin("=", param)
            key, val = split(param, "=", limit=2)
            #key = replace(key,"+" => "")
            proj[key] = tryparse(Float64, val) !== nothing ? parse(Float64, val) : val
        else
            proj[param] = true  # handle flags like +no_defs
        end
    end

    return proj
end

"""
    proj_to_cf(proj::Dict)

Convert a dictionary of PROJ parameters (e.g. `"+lat_0"` => 90.0) into a CF-compliant dictionary
of NetCDF attributes for a `grid_mapping` variable.

Assumes `+proj=stere` (polar stereographic projection).
"""
function proj_to_cf(proj::Dict)
    # Convert a list of proj parameters to cf-compliant names

    # Check projection type (only supporting polar stereographic for now)
    if proj["+proj"] != "stere"
        error("Only +proj=stere (polar stereographic) is currently supported.")
    end

    # Map PROJ keys to CF-compliant names
    cf_map = Dict(
        "+lat_0"  => "latitude_of_projection_origin",
        "+lat_ts" => "standard_parallel",
        "+lon_0"  => "straight_vertical_longitude_from_pole",
        "+x_0"    => "false_easting",
        "+y_0"    => "false_northing",
        "+a"      => "semi_major_axis",
        "+rf"     => "inverse_flattening"
    )

    # Build output dictionary
    proj_cf = Dict{String,Any}(
        "grid_mapping_name" => "polar_stereographic"
    )

    for (k_proj, k_cf) in cf_map
        if haskey(proj, k_proj)
            proj_cf[k_cf] = proj[k_proj]
        end
    end

    return proj_cf
end

function proj_to_cf(proj_str::String)
    # Convert a proj string to a list of cf-compliant parameters

    proj = proj_str_to_crs(proj_str)
    proj_cf = proj_to_cf(proj)

    return proj_cf
end

function grid_write_nc(grid,filename; 
            xname::String="xc",yname::String="yc")

    # Create NetCDF file
    ds = NCDataset(filename, "c")

    # Define dimensions
    defDim(ds, xname, grid["nx"])
    defDim(ds, yname, grid["ny"])

    # Define coordinate variables
    var_xc = defVar(ds, xname, Float64, (xname,))
    var_xc.attrib["units"] = grid["xunits"]
    var_xc[:] = grid["xc"]
    
    var_yc = defVar(ds, yname, Float64, (yname,))
    var_yc.attrib["units"] = grid["yunits"]
    var_yc[:] = grid["yc"]

    # Define the projection variable 'crs'
    proj_cf = grid["proj_cf"]

    crs = defVar(ds, "crs", Int32, ())
    crs.attrib["grid_mapping_name"] = proj_cf["grid_mapping_name"]
    crs.attrib["straight_vertical_longitude_from_pole"] = proj_cf["straight_vertical_longitude_from_pole"]
    crs.attrib["latitude_of_projection_origin"] = proj_cf["latitude_of_projection_origin"]
    crs.attrib["standard_parallel"] = proj_cf["standard_parallel"]
    crs.attrib["false_easting"] = proj_cf["false_easting"]
    crs.attrib["false_northing"] = proj_cf["false_northing"]
    crs.attrib["semi_major_axis"] = proj_cf["semi_major_axis"]
    crs.attrib["inverse_flattening"] = proj_cf["inverse_flattening"]

    close(ds)

    # Add additional grid variables

    write_2d_variable(filename,"x2D",grid["x2D"],xdim=xname,ydim=yname,units=grid["xunits"])
    write_2d_variable(filename,"y2D",grid["y2D"],xdim=xname,ydim=yname,units=grid["xunits"])
    write_2d_variable(filename,"lat2D",grid["lat2D"],xdim=xname,ydim=yname,units="degrees_north")
    write_2d_variable(filename,"lon2D",grid["lon2D"],xdim=xname,ydim=yname,units="degrees_east")
    write_2d_variable(filename,"area",grid["area"],xdim=xname,ydim=yname,units="m^2")

    println("File written: $filename")
end




function projected_to_latlon(xc::Vector{<:Real}, yc::Vector{<:Real},source_crs;dest_crs = "EPSG:4326")
    # source CRS assumed to be Cartesian projected
    # destination CRS assumed to be lat/lon

    # Create the transformation object
    transformation = Proj.Transformation(source_crs, dest_crs; always_xy=true)

    # Create meshgrid of x/y (convert km to m)
    X = repeat(xc' .* 1000, length(yc), 1)  # (ysize, xsize) in meters
    Y = repeat(yc  .* 1000, 1, length(xc))  # (ysize, xsize) in meters

    # Apply the transformation
    lonlat = transformation.(X,Y)

    # Extract the longitude and latitude
    lon2D = [coord[1] for coord in lonlat]
    lat2D = [coord[2] for coord in lonlat]

    # Reshape to 2D arrays (nx, ny)
    lon2D = reshape(lon2D, length(yc), length(xc))
    lat2D = reshape(lat2D, length(yc), length(xc))

    lon2D = Matrix(lon2D')
    lat2D = Matrix(lat2D')

    return lat2D, lon2D
end

function geodesic_polygon_area(p)

    lons = first.(p);
    lats = last.(p);

    # Make sure longitudes are 0:360
    if minimum(lons) < 0
        lons .= lons .+ 180
    end

    pg = GeographicLib.Polygon(lons,lats)

    n, perimeter, area = properties(pg)

    return area
end

function extend2D(var)
    nx, ny = size(var)
    vare = fill(NaN,nx+2,ny+2)
    vare[2:nx+1,2:ny+1] .= var

    vare[1,2:ny+1]    = var[1,:] .- (var[2,:].-var[1,:])
    vare[nx+2,2:ny+1] = var[nx,:] .+ (var[nx,:].-var[nx-1,:])
    vare[:,1]    = vare[:,2] .- (vare[:,3].-vare[:,2])
    vare[:,ny+2] = vare[:,ny+1] .+ (vare[:,ny+1].-vare[:,ny])
    
    # Fill the corners
    vare[1, 1]       = var[1, 1] .- (var[2, 1] .- var[1, 1]) .- (var[1, 2] .- var[1, 1])
    vare[1, ny+2]    = var[1, ny] .- (var[2, ny] .- var[1, ny]) .+ (var[1, ny] .- var[1, ny-1])
    vare[nx+2, 1]    = var[nx, 1] .+ (var[nx, 1] .- var[nx-1, 1]) .- (var[nx, 2] .- var[nx, 1])
    vare[nx+2, ny+2] = var[nx, ny] .+ (var[nx, ny] .- var[nx-1, ny]) .+ (var[nx, ny] .- var[nx, ny-1])

    return vare
end

function cell_areas(lat2D::Matrix{Float64}, lon2D::Matrix{Float64})
    nx, ny = size(lat2D)
    area = fill(0.0, nx, ny)

    for j in 2:ny-1, i in 2:nx-1
        
        im1 = i-1
        ip1 = i+1
        jm1 = j-1
        jp1 = j+1
        
        vertices = [
            (lon2D[i,j],lat2D[i,j]),
            (lon2D[ip1,j],lat2D[ip1,j]),
            (lon2D[ip1,jp1],lat2D[ip1,jp1]),
            (lon2D[i,jp1],lat2D[i,jp1]),
            (lon2D[i,j],lat2D[i,j])     # Close the polygon
        ]
        area1 = geodesic_polygon_area(vertices)

        vertices = [
            (lon2D[i,j],lat2D[i,j]),
            (lon2D[i,jp1],lat2D[i,jp1]),
            (lon2D[im1,jp1],lat2D[im1,jp1]),
            (lon2D[im1,jm1],lat2D[im1,jm1]),
            (lon2D[i,j],lat2D[i,j])     # Close the polygon
        ]
        area2 = geodesic_polygon_area(vertices)

        vertices = [
            (lon2D[i,j],lat2D[i,j]),
            (lon2D[im1,j],lat2D[im1,j]),
            (lon2D[im1,jm1],lat2D[im1,jm1]),
            (lon2D[i,jm1],lat2D[i,jm1]),
            (lon2D[i,j],lat2D[i,j])     # Close the polygon
        ]
        area3 = geodesic_polygon_area(vertices)

        vertices = [
            (lon2D[i,j],lat2D[i,j]),
            (lon2D[i,jm1],lat2D[i,jm1]),
            (lon2D[ip1,jm1],lat2D[ip1,jm1]),
            (lon2D[ip1,j],lat2D[ip1,j]),
            (lon2D[i,j],lat2D[i,j])     # Close the polygon
        ]
        area4 = geodesic_polygon_area(vertices)

        area[i,j] = 0.25*(area1+area2+area3+area4)
    end

    # Recalculate area around the border using extended values
    area = extend2D(area[2:nx-1,2:ny-1])

    return area
end

function write_2d_variable(
    filename::String,
    varname::String,
    data::AbstractMatrix;
    xdim::String = "xc",
    ydim::String = "yc",
    units::String = "",
)

    # Open NetCDF file in append mode
    ds = Dataset(filename, "a")

    # Define the variable (infer data type from matrix)
    dtype = eltype(data)
    var = defVar(ds, varname, dtype, (xdim, ydim))

    # Write the data
    var[:, :] = data

    # Add optional attributes
    # for (k, v) in attribs
    #     var.attrib[k] = v
    # end

    var.attrib["grid_mapping"] = "crs"
    var.attrib["units"] = units
    close(ds)
end