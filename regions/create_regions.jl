cd(@__DIR__)
import Pkg; Pkg.activate(".")

using NCDatasets
using Shapefile
using GeoDataFrames
using Rasters
using CairoMakie

using CSV
using Glob
#using GeometryBasics
import ArchGDAL

# Several useful functions
include("../grid/grids.jl")



# Path to your ASCII polygon files
files = Glob.glob("polygons_custom/*.txt")

polys = []
names = String[]

for f in files
    # Read lon/lat table
    df = CSV.read(f, DataFrame; delim=' ', ignorerepeated=true, comment="#")

    # Create a polygon from the coordinates
    coords = [(row.lon, row.lat) for row in eachrow(df)]
    polygon = ArchGDAL.createpolygon([coords])

    push!(polys, polygon)
    push!(names, splitext(basename(f))[1])
end

# Create a GeoDataFrame with the polygon
gdf = DataFrame(:id => 1:length(names), :name => names,:geometry => polys)