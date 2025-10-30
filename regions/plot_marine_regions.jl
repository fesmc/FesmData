cd(@__DIR__)
import Pkg; Pkg.activate(".")

using Shapefile
using CairoMakie
using GeoInterface
using GeometryBasics
using GeometryOps

using NCDatasets

# Several useful functions
include("../grid/grids.jl")

# Load shapefile (change path to your own shapefile)
#table = Shapefile.Table("marineregions/World_EEZ_v12_20231025/eez_boundaries_v12.shp")
table = Shapefile.Table("marineregions/World_EEZ_v12_20231025/eez_v12.shp")

myregions = Dict{String,Any}()
myregions["Greenland"] = "Greenland (Denmark)"
myregions["North America"] = ["Canadian Exclusive Economic Zone",
                              "Overlapping claim: Canada / United States",
                              "United States Exclusive Economic Zone",
                              "Alaska (United States)"]
myregions["Russia"] = "Russia"
myregions["Svalbard"] = "Svalbard (Norway)"

function find_index_of_region(geonames,geoname)
    # Find region(s) of interest
    kk = []
    for (k,reg) in enumerate(table.GEONAME)
        if reg == geoname
            println(reg)
            push!(kk,k)
        elseif occursin(geoname,reg)
            println(reg)
            push!(kk,k)
        end
    end

    return kk
end

# Get region indices
kk = find_index_of_region(table.GEONAME,"Greenland")

# Extract geometries
geoms = GeoInterface.geometry.(table)

begin
    # Start the figure and axis
    fig = Figure()
    ax = Axis(fig[1, 1]; aspect=DataAspect())

    #for geom in geoms
    #    lines!(ax,geom, color=:black)
    #end

    k = kk[1]
    geom = geoms[k]
    lines!(ax,geom, color=:red)

    pt = Point2f(-45.0, 70.0)
    scatter!(ax,pt,color=:green)
end
fig


# Extract coordinates of the polygon(s) for this region
k = kk[1]
geom = geoms[k]
coords = GeoInterface.coordinates(geom)

# If it's a multipolygon or polygon with holes, you might have a nested structure
# For a multipolygon, each polygon can be isolated like this:

if typeof(coords) <: Vector{Vector{<:Real}}  # Simple polygon with one outer boundary
    rings = [coords[1]]  # Just one region
else
    rings = coords[1]  # Multipolygon: List of polygons
end

# Now, `rings` contains individual polygon parts (rings)

# Example: Plot the first ring of the first polygon
ring = rings[1]  # Outer boundary of the first polygon (or the first multipolygon part)
xs = first.(ring)
ys = last.(ring)

# Plot the isolated region
fig = Figure()
ax = Axis(fig[1, 1]; aspect=DataAspect())
lines!(ax, xs, ys, color=:black)
fig

# Testing to see if it works
pt = Point2f(-45.0, 70.0)
polygon = GeometryOps.Polygon(Point2f.(ring))
GeometryOps.contains(polygon, pt)

### Saving a region ###

function mask_of_region(grid,ring::AbstractVector{<:Real})

    # Get a polygon representation of the current ring
    polygon = GeometryOps.Polygon(Point2f.(ring))

    # Loop over grid points and find which points are inside ring
    mask = fill(0.0,grid["nx"],grid["ny"])
    for i in 1:grid["nx"], j in 1:grid["ny"]
        pt = Point2f(grid["lon2D"][i,j],grid["lat2D"][i,j])
        if GeometryOps.contains(polygon, pt)
            mask[i,j] = 1.0
        end
    end

    return mask
end

function mask_of_regions(grid,rings)

    mask = fill(0.0,grid["nx"],grid["ny"])
    
    for i in 1:grid["nx"], j in 1:grid["ny"]
        pt = Point2f(grid["lon2D"][i,j],grid["lat2D"][i,j])
        for ring in rings
            polygon = GeometryOps.Polygon(Point2f.(ring))
            if GeometryOps.contains(polygon, pt)
                mask[i,j] = 1.0
                break
            end
        end
    end

    return mask
end

# Define the grid
grid = generate_grid("North","NH-32KM")

mask = mask_of_regions(grid,rings[1:3])

# Write a new file with the mask
filename_out = "../out/$(grid["grid_name"])_REGIONS.nc"
grid_write_nc(grid,filename_out)
write_2d_variable(filename_out,"mask",mask)

begin
    fig = Figure()
    ax = Axis(fig[1, 1]; aspect=DataAspect())
    lines!(ax, polygon, color=:black)
    kk = findall(mask .> 0.0)
    scatter!(ax,grid["lon2D"][kk],grid["lat2D"][kk])
    fig
end

begin
    fig = Figure()
    ax = Axis(fig[1, 1]; aspect=DataAspect())
    heatmap!(ax,grid["xc"],grid["yc"],mask)
    fig
end

