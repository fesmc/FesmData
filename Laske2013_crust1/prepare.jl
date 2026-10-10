# Prepare the sediment thickness of CRUST1.0 (Laske et al., 2013) for remapping: the
# thickness of its three sediment layers and their sum on the 1x1° grid of the model,
# as a prepared NetCDF file, $FESMDATA_WORK/prepared/Laske2013_crust1/Laske2013_CRUST1_sed.nc.
#
# Usage:
#     julia --project=Laske2013_crust1 Laske2013_crust1/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Laske2013_crust1/Laske2013_CRUST1_sed.nc all

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

dir = download_dataset(manifest(), "crust1")    # downloads it if missing

# crust1.bnds: one line per 1x1° cell, from 89.5°N to 89.5°S, with longitudes from
# 179.5°W to 179.5°E as the inner loop. The 9 columns are the tops of the layers (km,
# positive up): water, ice, upper, middle and lower sediments, upper, middle and lower
# crystalline crust, and the Moho. The thickness of a layer is its top minus the top of
# the next layer.
bnds = readdlm(joinpath(dir, "crust1.bnds"), Float64)
size(bnds) == (360 * 180, 9) || error("crust1.bnds: expected 64800 x 9 values, got $(size(bnds))")
lon = collect(-179.5:1.0:179.5)
lat = collect(-89.5:1.0:89.5)
layer(k) = Float32.(round.(1000 .* reverse(reshape(bnds[:, k] .- bnds[:, k+1], 360, 180); dims=2)))

fields = [("z_sed_upper", layer(3), "thickness of the upper sediments"),
          ("z_sed_middle", layer(4), "thickness of the middle sediments"),
          ("z_sed_lower", layer(5), "thickness of the lower sediments")]
pushfirst!(fields, ("z_sed", fields[1][2] .+ fields[2][2] .+ fields[3][2], "sediment thickness"))
all(F -> minimum(F) >= 0, getindex.(fields, 2)) || error("crust1.bnds: negative layer thickness")

path = joinpath(prepared_dir("Laske2013_crust1"), "Laske2013_CRUST1_sed.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, F, long_name) in fields
        defVar(ds, name, F, ("lon", "lat"); deflatelevel=1,
               attrib=["units" => "m", "long_name" => long_name])
    end
    ds["z_sed"].attrib["comment"] = "sum of the upper, middle and lower sediment layers of CRUST1.0"
    ds.attrib["title"] = "Sediment thickness of CRUST1.0 (Laske et al., 2013)"
    ds.attrib["references"] = "Laske, G., Masters, G., Ma, Z. and Pasyanos, M.: Update on CRUST1.0 - " *
                              "A 1-degree global model of Earth's crust, Geophys. Res. Abstr., 15, " *
                              "EGU2013-2658, 2013; https://igppweb.ucsd.edu/~gabi/crust1.html"
    ds.attrib["license"] = "No licence stated by the authors (https://igppweb.ucsd.edu/~gabi/crust1.html); " *
                           "cite Laske et al. (2013) and refer to the REM web site"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("sediment"))
end
println("Wrote $path")
