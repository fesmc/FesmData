cd(@__DIR__)
import Pkg; Pkg.activate(".")
# add CSV, DataFrames, Proj, Rasters, NCDatasets, CairoMakie

using CSV
using DataFrames
using Proj
using Rasters
using NCDatasets
using CairoMakie
using Dates

df = CSV.read("ECM1/ECM1.txt",DataFrame)

lon = unique(df.Lon)  # -179.5:1.0:179.5
lat = unique(df.Lat)   # -89.5:1.0:89.5
nx, ny = length(lon), length(lat)
n = nx*ny

H_sed = reshape(df.Sed, nx, ny) .* 1e3  # km => m
#T_lith = reshape(df.Hc, nx, ny)  # This is apparently not effective elastic thickness, but something else.

# Write to NetCDF output
begin
    # Define filename
    outfile = "Mooney2023_Sediments.nc"

    # Create a new NetCDF file (overwrite if exists)
    ds = Dataset(outfile, "c", format=:netcdf4)

    # Define dimensions
    defDim(ds, "lon", length(lon))
    defDim(ds, "lat", length(lat))

    # Define coordinate variables (with CF-compliant attributes)
    lon_var = defVar(ds, "lon", Float32, ("lon",), attrib = Dict(
        "standard_name" => "longitude",
        "long_name"     => "longitude",
        "units"         => "degrees_east",
        "axis"          => "X"
    ))

    lat_var = defVar(ds, "lat", Float32, ("lat",), attrib = Dict(
        "standard_name" => "latitude",
        "long_name"     => "latitude",
        "units"         => "degrees_north",
        "axis"          => "Y"
    ))

    # Define data variables
    sed_var     = defVar(ds, "H_sed", Float32, ("lon", "lat"), attrib = Dict(
        "units" => "m",
        "long_name" => "Sediment thickness"
    ))

    # Write coordinate data
    lon_var[:] = lon
    lat_var[:] = lat

    # Write field data
    sed_var[:, :] = H_sed

    # Optional global attributes
    ds.attrib["title"] = "Earth Crustal Model 1 (ECM1): A 1°x 1° Global Seismic and Density Model "
    ds.attrib["source"] = "Mooney, Walter D., et al.: Earth Crustal Model 1 (ECM1): A 1° x 1° Global Seismic and Density Model, Earth Science Rev., 243, 104493, doi:10.1016/j.earscirev.2023.104493, 2023."
    ds.attrib["history"] = "Created on $(Dates.now())"

    # Close the file
    close(ds)
end
