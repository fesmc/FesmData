cd(@__DIR__)
import Pkg; Pkg.activate(".")
# add MAT

# add CSV, Shapefile, Proj, GeoDataFrames, GeoFormatTypes, Rasters, NCDatasets, CairoMakie

# using CSV
# using Shapefile
# using Proj
# using GeoDataFrames
# using GeoFormatTypes
# using Rasters
# using NCDatasets
using MAT
#using CairoMakie


# Load dataset
dat = matread("Antarctica_Initialization.mat")