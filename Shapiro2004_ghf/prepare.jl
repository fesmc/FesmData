# Prepare the Shapiro and Ritzwoller (2004) geothermal heat flow for remapping: the 1°
# global map hfmap.asc (datamanifest key shapiro2004_ghf, gzipped) as a prepared NetCDF
# file, $FESMDATA_WORK/prepared/Shapiro2004_ghf/Shapiro2004_GHF.nc, with ghf and ghf_sd.
#
# Usage:
#     julia --project=Shapiro2004_ghf Shapiro2004_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Shapiro2004_ghf/Shapiro2004_GHF.nc all

using CodecZlib
using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const DB = manifest()
const INPUT = let path = get_dataset_path(DB, "shapiro2004_ghf")
    ispath(path) ? path : download_dataset(DB, "shapiro2004_ghf")
end

# Columns: lon (0:359), lat (-90:90), heat flow, its standard deviation (mW m-2); one
# row per point of the 1° grid
A = open(io -> readdlm(GzipDecompressorStream(io), Float64), INPUT)
lon0 = sort(unique(A[:, 1]))
lat = sort(unique(A[:, 2]))
nx, ny = length(lon0), length(lat)
size(A, 1) == nx * ny || error("$INPUT is not a full lon-lat grid")

# Longitudes in -180:180
lon = sort(mod.(lon0 .+ 180, 360) .- 180)
ghf = fill(NaN32, nx, ny)
ghf_sd = fill(NaN32, nx, ny)
for r in eachrow(A)
    i = searchsortedfirst(lon, mod(r[1] + 180, 360) - 180)
    j = searchsortedfirst(lat, r[2])
    ghf[i, j] = r[3]
    ghf_sd[i, j] = r[4]
end

path = joinpath(prepared_dir("Shapiro2004_ghf"), "Shapiro2004_GHF.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, F, long_name) in (("ghf", ghf, "geothermal heat flow"),
                                 ("ghf_sd", ghf_sd, "standard deviation of geothermal heat flow"))
        defVar(ds, name, F, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "mW m-2", "long_name" => long_name])
    end
    ds.attrib["title"] = "Global geothermal heat flow (Shapiro and Ritzwoller, 2004)"
    ds.attrib["references"] = "Shapiro, N. M. and Ritzwoller, M. H.: Inferring surface heat flux " *
                              "distributions guided by a global seismic model: particular application " *
                              "to Antarctica, Earth Planet. Sci. Lett., 223, 213-224, 2004"
    ds.attrib["doi"] = "10.1016/j.epsl.2004.04.011"
    ds.attrib["license"] = "No licence stated by the authors"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
