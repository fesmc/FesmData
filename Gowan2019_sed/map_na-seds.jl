cd(@__DIR__)
import Pkg; Pkg.activate(".")
# add CSV, Proj, Rasters, NCDatasets, CairoMakie

using Dates
using CSV
using Proj
using Rasters
using NCDatasets
using CairoMakie




# Load Gowan et al. (2019) datasets
ds1 = NCDataset("data/netcdf/grain_size.nc")
ds2 = NCDataset("data/netcdf/distribution.nc")
ds3 = NCDataset("data/netcdf/final_sed.nc")
ds4 = NCDataset("data/netcdf/geology.nc")

crs = "EPSG:3979" # Lambert Conformal conic for Canada

# Combine all into one NetCDF file, and include projection information

# Write to NetCDF output
begin

    fillval = Float32(-9999)

    grain = convert.(Float32, replace(ds1["z"][:,:], missing => 3))
    distribution = convert.(Float32, replace(ds2["z"][:,:], missing => fillval))
    sed_combined = convert.(Float32, replace(ds3["Band1"][:,:], missing => 1))

    # Note: missing values are in the ocean, and lower NA (out of domain)
    # - Where grain is missing, assume it is silt
    # - Where sed_combined is missing, assume it is blanket/silt

    # This is on a different grid (same projection), omit for now
    #geology = ds4["merge_geo_holes6_lam_Polygon"][:,:]

    x, y = ds1["x"][:], ds1["y"][:]

    nx, ny = length(x), length(y)
    n = nx*ny

    
    # Define filename
    outfile = "Gowan2019_Sediments.nc"

    # Create a new NetCDF file (overwrite if exists)
    ds = Dataset(outfile, "c", format=:netcdf4)
    ds.attrib["title"] = "Geology datasets in North America, Greenland and surrounding areas for use with ice sheet models"
    ds.attrib["reference"] = "Gowan, E. J., Niu, L., Knorr, G., and Lohmann, G.: Geology datasets in North America, Greenland and surrounding areas for use with ice sheet models, Earth Syst. Sci. Data, 11, 375–391, https://doi.org/10.5194/essd-11-375-2019, 2019."
    ds.attrib["source"] = "https://doi.pangaea.de/10.1594/PANGAEA.895889"
    ds.attrib["history"] = "Created on $(Dates.now())"

    # Define dimensions
    defDim(ds, "x", length(x))
    defDim(ds, "y", length(y))

    # Define coordinate variables (with CF-compliant attributes)
    x_var = defVar(ds, "x", Float32, ("x",), attrib = Dict(
        "standard_name" => "projection_x_coordinate",
        "long_name"     => "x coordinate of projection",
        "units"         => "m",
        "axis"          => "X"
    ))
    x_var[:] = x
    
    y_var = defVar(ds, "y", Float32, ("y",), attrib = Dict(
        "standard_name" => "projection_y_coordinate",
        "long_name"     => "y coordinate of projection",
        "units"         => "m",
        "axis"          => "Y"
    ))
    y_var[:] = y

    # Define projection variable

    # Create the crs variable with no data (0-length scalar)
    defVar(ds, "crs", Int32, (), attrib = Dict(
        "grid_mapping_name"               => "lambert_conformal_conic",
        "longitude_of_central_meridian"   => -95.0,
        "latitude_of_projection_origin"   => 49.0,
        "standard_parallel"               => [49.0, 77.0],
        "false_easting"                   => 0.0,
        "false_northing"                  => 0.0,
        "semi_major_axis"                 => 6378137.0,          # GRS80
        "inverse_flattening"              => 298.257222101,      # GRS80
        "longitude_of_prime_meridian"     => 0.0,
        "epsg_code"                       => "EPSG:3979"
    ))

    # Define data variables

    var1     = defVar(ds, "grain", Float32, ("x", "y"), attrib = Dict(
        "units" => "m",
        "long_name" => "Grain type (1: clay, 2: sand, 3: silt)",
        "_FillValue" => fillval,
        "grid_mapping" => "crs"
    ))
    var1[:, :] = grain
    
    var2     = defVar(ds, "distribution", Float32, ("x", "y"), attrib = Dict(
        "units" => "m",
        "long_name" => "Sediment distribution, 1: Blanket (continuous), 2: Veneer (discontinuous), 3: Rock (mostly bare rock)",
        "_FillValue" => fillval,
        "grid_mapping" => "crs"
    ))
    var2[:, :] = distribution
    
    var3     = defVar(ds, "composite", Float32, ("x", "y"), attrib = Dict(
        "units" => "m",
        "long_name" => "Sediment class, 0: blanket/sand, 1: blanket/silt, 2: blanket/clay, 3: veneer/sand, 4: veneer/silt, 5: veneer/clay, 6: rock/sand, 7: rock/silt, 8: rock/clay",
        "_FillValue" => fillval,
        "grid_mapping" => "crs"
    ))
    var3[:, :] = sed_combined
    
    # Close the file
    close(ds)
end