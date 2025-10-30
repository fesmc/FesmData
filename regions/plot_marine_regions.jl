cd(@__DIR__)
import Pkg; Pkg.activate(".")

using NCDatasets
using Shapefile
using GeoDataFrames
using Rasters
using CairoMakie

# Several useful functions
include("../grid/grids.jl")

"""
Get a vector that shows which indices of dat match
a set of possible names. Missing values in dat are necessarily
replaced with an empty string for parsing and matching.
"""
function get_matching_rows(names::Vector{Any},dat)

    dat_nomissing = coalesce.(dat, "")
    mask = [t in names for t in dat_nomissing]

    return mask
end

function check_string_match(str,dat)
    kk = occursin.(str, coalesce.(dat, ""))
    if sum(kk) > 0
        println.(dat[kk])
        check = true
    else
        check = false
    end
    return check
end 

# Load shapefile as a GeoDataFrame
shp = GeoDataFrames.read("marineregions/EEZ_land_union_v4_202410/EEZ_land_union_v4_202410.shp")
shp_ocn = GeoDataFrames.read("marineregions/GOaS_v1_20211214/goas_v01.shp")

# Define my region names of interest
begin
    myregions = Dict{String,Vector{Any}}()
    myregions["Greenland"] = ["Greenland"]
    myregions["North America"] = ["Canada", "United States", "Alaska"]
    myregions["Russia"] = ["Russia"]
    myregions["Svalbard"] = ["Svalbard"]
    myregions["Arctic"] = ["Arctic Ocean"]
end

# Get subsets of regions
mask = get_matching_rows(myregions["Greenland"],shp.TERRITORY1)
shp_grl = shp[mask, :]

mask = get_matching_rows(myregions["North America"],shp.TERRITORY1)
shp_na = shp[mask, :]

mask = get_matching_rows(myregions["Russia"],shp.TERRITORY1)
shp_russia = shp[mask, :]

mask = get_matching_rows(myregions["Svalbard"],shp.TERRITORY1)
shp_sval = shp[mask, :]

mask = get_matching_rows(myregions["Arctic"],shp_ocn.name)
shp_arctic = shp_ocn[mask, :]

#### latlon grid ####
# Put desired shapefile polygons onto latlon grid

## TO DO: add more polygons into one master latlon grid
## Example below is so far just with Greenland and 0/1, but
## real values should be assigned to each region

begin
    # Define coordinate ranges
    lon = -180:0.5:180
    lat = 0:0.5:90

    nx = length(lon)
    ny = length(lat)

    # Create the raster: lon/lat
    r = Rasters.Raster(zeros(length(lon), length(lat)); dims=(X(lon), Y(lat)))
    r = Rasters.setcrs(r, EPSG(4326))

    mask = Rasters.rasterize(last, shp_grl, fill=1, to=r)
    Rasters.replace_missing!(mask, 0)
end

# Map to target grid
begin
    # Generate target grid from grid description file
    g = generate_grid("Greenland","GRL-32KM")

    xg = range(g["x0"], step=g["dx"], length=g["nx"])
    yg = range(g["y0"], step=g["dy"], length=g["ny"])

    # Create a blank raster using the coordinate grid
    rg = Raster(zeros(Int, length(xg), length(yg)), (X(xg), Y(yg)))
    rg = Rasters.setcrs(rg, ProjString(g["proj_str"]) )

    # Remap onto target grid
    maskg = Rasters.resample(mask; to=rg)
    Rasters.replace_missing!(maskg, 0)
end

# Write data out to file
begin
    filename_out = "$(g["grid_name"])_REGIONS.nc"
    grid_write_nc(g, filename_out)

    maskg_int = coalesce.(maskg.data, 0)
    write_2d_variable(filename_out,"mask",maskg_int)

end


begin
    fig = Figure()
    ax = Axis(fig[1, 1]; aspect=DataAspect())
    hm = heatmap!(ax,g["xc"],g["yc"],maskg.data)
    Colorbar(fig[1,2],hm)
    fig
end

