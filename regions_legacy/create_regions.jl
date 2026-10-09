cd(@__DIR__)
import Pkg; Pkg.activate(".")

using NCDatasets
using Shapefile
import ArchGDAL
using GeoDataFrames
using Rasters
using CairoMakie

using CSV
using Glob

# Several useful functions
include("../grid/grids.jl")


# Load a set of custom polygons from ascii files
begin

    # Path to your ASCII polygon files
    files = Glob.glob("polygons_custom/*.txt")

    polys = []
    regnames = String[]

    for f in files
        # Read lon/lat table
        df = CSV.read(f, DataFrame; delim=' ', ignorerepeated=true, comment="#")
        
        # Check if the polygon is closed, if not, close it
        if df[1, :lon] != df[end, :lon] || df[1, :lat] != df[end, :lat]
            push!(df, df[1, :])
        end

        # Create a polygon from the coordinates
        coords = [(row.lon, row.lat) for row in eachrow(df)]
        polygon = ArchGDAL.createpolygon([coords])

        name = splitext(basename(f))[1]
        name = replace(name,"polygon_"=>"")

        push!(polys, polygon)
        push!(regnames, name)
    end

    # Create a GeoDataFrame with the polygon
    n = length(regnames)
    gdf = DataFrame(
        :id => 1:n,
        :name => regnames,
        :geometry => polys,
        :hemisphere_value => zeros(Float32, n),
        :region_value => zeros(Float32, n),
        :mask_value => zeros(Float32, n)
    )

    # Add indices associated with each region

    mask_index_north = 1.0  # North
    mask_index_south = 2.0  # Antarctica

    region_defs_south = DataFrame(
        "antarctica" => 1.0,
        "antarctica_inner" => 1.1,
    )

    region_defs_north = DataFrame(
        "laurentide" => 1.0,
        "eis" => 2.0,
        "grl_and_ellesmere" => 3.0,
        "asia" => 4.0,
        "ellesmere" => 1.1,
        "barents-kara" => 2.1,
        "britain" => 2.2,
        "svalbard" => 2.3,
        "iceland" => 3.1,
        "hudson" => 1.2,
    )

    # Populate gdf with the right mask value for each region
    for k in 1:n
        if gdf.name[k] in names(region_defs_south)
            gdf.hemisphere_value[k] = mask_index_south
            regval = getproperty(region_defs_south[1,:], Symbol(gdf.name[k]))
        else
            gdf.hemisphere_value[k] = mask_index_north
            regval = getproperty(region_defs_north[1,:], Symbol(gdf.name[k]))
        end

        gdf.region_value[k] = regval
        gdf.mask_value[k] = gdf.hemisphere_value[k] + gdf.region_value[k]*0.1
    end
    
end

# Bring polygons into one global grid

begin
    # Define coordinate ranges
    lon = -180:0.5:180
    lat = -90:0.5:90

    nx = length(lon)
    ny = length(lat)

    # Create the raster: lon/lat
    r = Rasters.Raster(zeros(length(lon), length(lat)); dims=(X(lon), Y(lat)))
    r = Rasters.setcrs(r, EPSG(4326))

    # Set indices
    r[:, At(lat[lat .> 0])] .= mask_index_north
    r[:, At(lat[lat .<= 0])] .= mask_index_south
    
    for k in 1:n
        mask = Rasters.rasterize(last, gdf.geometry[k], fill=gdf.mask_value[k], to=r)
        Rasters.replace_missing!(mask, 0)

        for i in 1:nx, j in 1:ny
            if mask[i,j] > 0
                r[i,j] = mask[i,j]
            end
        end
    end
end

