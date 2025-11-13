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

df = CSV.read("2019GC008389-sup-0003-Data_Set_SI-S01/HFgrid14.csv",DataFrame)
rename!(df, names(df)[1] => "longitude")

lon = unique(df.longitude)  # -179.75:0.5:179.75
lat = unique(df.latitude)   # -89.75:0.5:89.75
nx, ny = length(lon), length(lat)
n = nx*ny

ghf = reshape(df.HF_pred, nx, ny)
ghf_err = reshape(df.sHF_pred, nx, ny)

# Write to NetCDF output
begin
    # Define filename
    outfile = "Lucazeau2019_GHF.nc"

    # Create a new NetCDF file (overwrite if exists)
    ds = Dataset(outfile, "c", format=:netcdf4)

    # Define dimensions
    defDim(ds, "lon", length(lon))
    defDim(ds, "lat", length(lat))

    # Define coordinate variables
    lon_var = defVar(ds, "lon", Float32, ("lon",))
    lat_var = defVar(ds, "lat", Float32, ("lat",))

    # Define data variables
    ghf_var     = defVar(ds, "ghf", Float32, ("lon", "lat"), attrib = Dict(
        "units" => "mW m^-2",
        "long_name" => "Geothermal heat flow"
    ))
    ghf_err_var = defVar(ds, "ghf_err", Float32, ("lon", "lat"), attrib = Dict(
        "units" => "mW m^-2",
        "long_name" => "Geothermal heat flow standard deviation"
    ))

    # Write coordinate data
    lon_var[:] = lon
    lat_var[:] = lat

    # Write field data
    ghf_var[:, :]     = ghf
    ghf_err_var[:, :] = ghf_err

    # Optional global attributes
    ds.attrib["title"] = "Global geothermal heat flow and uncertainty"
    ds.attrib["source"] = "Lucazeau, F. Analysis and Mapping of an Updated Terrestrial Heat Flow Data Set. Geochemistry, Geophysics, Geosystems, 20(8), 4001-4024, doi:10.1029/2019gc008389, 2019."
    ds.attrib["history"] = "Created on $(Dates.now())"

    # Close the file
    close(ds)
end
