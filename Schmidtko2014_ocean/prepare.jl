# Prepare the Schmidtko et al. (2014) Antarctic shelf bottom water for remapping: the
# list of 0.25° x 0.125° shelf cells of Antarctic_shelf_data.txt (datamanifest key
# schmidtko2014_shelf) on its lon-lat grid, missing off the shelf, as
# $FESMDATA_WORK/prepared/Schmidtko2014_ocean/Schmidtko2014_OCEAN.nc.
#
# Usage:
#     julia --project=Schmidtko2014_ocean Schmidtko2014_ocean/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Schmidtko2014_ocean/Schmidtko2014_OCEAN.nc Antarctica

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const DLON = 0.25
const DLAT = 0.125

# Columns: LONGITUDE (0:360), LATITUDE (rounded to 0.01°), DEPTH (m, negative),
# C_T, C_T_STD (°C), ABS_S, ABS_S_STD (g kg-1); one row per shelf cell
data, header = readdlm(download_dataset(manifest(), "schmidtko2014_shelf"), Float64; header=true)
vec(header) == ["LONGITUDE", "LATITUDE", "DEPTH", "C_T", "C_T_STD", "ABS_S", "ABS_S_STD"] ||
    error("unexpected columns $header")

# Cell centres on the 0.25° x 0.125° grid, longitudes in (-180, 180]
lon_pts = [l > 180 ? l - 360 : l for l in data[:, 1]]
lat_pts = data[:, 2]
lon = collect(-180 + DLON:DLON:180)
lat = collect(round(minimum(lat_pts) / DLAT) * DLAT:DLAT:round(maximum(lat_pts) / DLAT) * DLAT)
i = round.(Int, (lon_pts .- lon[1]) ./ DLON) .+ 1
j = round.(Int, (lat_pts .- lat[1]) ./ DLAT) .+ 1
maximum(abs.(lon[i] .- lon_pts)) < 1e-6 && maximum(abs.(lat[j] .- lat_pts)) <= 0.0051 ||
    error("points are not on the $(DLON)° x $(DLAT)° grid")
length(unique(zip(i, j))) == size(data, 1) || error("duplicate cells")

function field(col)
    F = fill(NaN32, length(lon), length(lat))
    for (k, (ik, jk)) in enumerate(zip(i, j))
        F[ik, jk] = data[k, col]
    end
    return F
end

const FIELDS = (("z_bottom", 3, "m", "height of the sea floor relative to sea level (negative below)"),
                ("ct_bottom", 4, "degC", "conservative temperature of shelf bottom water, mean 1975-2012"),
                ("ct_bottom_std", 5, "degC", "standard deviation of conservative temperature of shelf bottom water"),
                ("sa_bottom", 6, "g kg-1", "absolute salinity of shelf bottom water, mean 1975-2012"),
                ("sa_bottom_std", 7, "g kg-1", "standard deviation of absolute salinity of shelf bottom water"))

path = joinpath(prepared_dir("Schmidtko2014_ocean"), "Schmidtko2014_OCEAN.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, col, units, long_name) in FIELDS
        defVar(ds, name, field(col), ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => units, "long_name" => long_name])
    end
    ds.attrib["title"] = "Antarctic continental shelf bottom water temperature and salinity (Schmidtko et al., 2014)"
    ds.attrib["references"] = "Schmidtko, S., Heywood, K. J., Thompson, A. F. and Aoki, S.: Multidecadal " *
                              "warming of Antarctic waters, Science, 346, 1227-1231, 2014"
    ds.attrib["doi"] = "10.1126/science.1256117"
    ds.attrib["license"] = "No licence stated by the authors (data file on the GEOMAR web page of S. Schmidtko)"
    ds.attrib["comment"] = "Shelf cells shallower than 1500 m only (TEOS-10 conservative temperature and " *
                           "absolute salinity); missing elsewhere"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ocean"))
end
println("Wrote $path")
