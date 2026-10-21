# Prepare the CHELSA V2.1 monthly climatologies 1981-2010 (Karger et al., 2017; 30 arc
# seconds, about 1 km) for remapping, over the Pyrenees: the monthly mean, maximum and
# minimum near-surface air temperature and the precipitation, as
#     $FESMDATA_PREPARED/Karger2017_chelsa/Karger2017_CHELSA-V2.1_1981-2010_Pyrenees.nc
#
# The global Cloud-Optimized GeoTIFFs (one per variable and month) are not downloaded:
# only the box BOX is read, through GDAL /vsicurl/, and kept as clipped GeoTIFFs in the
# storage folder of the datamanifest entry chelsa_v21 (about 50 MB for the 48 files).
#
# Usage:
#     julia --project=Karger2017_chelsa Karger2017_chelsa/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_PREPARED/Karger2017_chelsa/Karger2017_CHELSA-V2.1_1981-2010_Pyrenees.nc PYR-1KM

using NCDatasets
import ArchGDAL as AG

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "chelsa_v21"
const SOURCE = "Karger2017_chelsa"
const URL = "https://os.zhdk.cloud.switch.ch/chelsav2/GLOBAL/climatologies/1981-2010"
const VARS = ["tas", "tasmax", "tasmin", "pr"]
# Box read from the global files, as gdal_translate -projwin (ulx, uly, lrx, lry; degrees):
# the PYR domain (about 1.85W-2.85E, 41.9-43.6N) with a margin of at least 0.4 degrees
const BOX = (-2.5, 44.0, 3.5, 41.3)
# Mean length of the months (days; February 28.25), to convert monthly sums to daily rates
const MONTH_DAYS = Float32[31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

"""
    clip(url, out; tries=3) -> out

The box BOX of the GeoTIFF at `url` (read through /vsicurl/), written to `out` as a
GeoTIFF (kept if it exists).
"""
function clip(url, out; tries=3)
    isfile(out) && return out
    tmp = out * ".tmp"
    for k in 1:tries
        try
            AG.read("/vsicurl/" * url) do ds
                AG.gdaltranslate(ds, ["-of", "GTiff", "-co", "COMPRESS=DEFLATE",
                                      "-projwin", string.(BOX)...]; dest=tmp) do _ end
            end
            mv(tmp, out; force=true)
            return out
        catch err
            k == tries && rethrow(err)
            sleep(10k)
        end
    end
end

"""
    read_tif(path) -> (lon, lat, A)

Cell centres (degrees, latitudes ascending) and band 1 of a north-up lon-lat GeoTIFF,
with the scale and offset of the band applied (Float32, NaN for no data).
"""
function read_tif(path)
    AG.read(path) do ds
        x0, dx, rx, y0, ry, dy = AG.getgeotransform(ds)
        (rx == 0 && ry == 0 && dy < 0) || error("$path: not a north-up grid")
        nx, ny = AG.width(ds), AG.height(ds)
        lon = x0 .+ dx .* ((1:nx) .- 0.5)
        lat = reverse(y0 .+ dy .* ((1:ny) .- 0.5))
        b = AG.getband(ds, 1)
        nd, scale, offset = AG.getnodatavalue(b), AG.getscale(b), AG.getoffset(b)
        A = reverse(AG.read(b); dims=2)
        F = map(v -> (nd !== nothing && v == nd) ? NaN32 : Float32(v * scale + offset), A)
        return collect(lon), collect(lat), F
    end
end

db = manifest()
store = get_dataset_path(db, KEY)
mkpath(store)
files = Dict((v, m) => clip("$URL/$v/CHELSA_$(v)_$(lpad(m, 2, '0'))_1981-2010_V.2.1.tif",
                            joinpath(store, "CHELSA_$(v)_$(lpad(m, 2, '0'))_1981-2010_V.2.1_Pyrenees.tif"))
             for v in VARS for m in 1:12)

lon, lat, _ = read_tif(files[("tas", 1)])
nx, ny = length(lon), length(lat)
fields = Dict{String,Array{Float32,3}}()
for v in VARS
    A = Array{Float32}(undef, nx, ny, 12)
    for m in 1:12
        l, b, F = read_tif(files[(v, m)])
        (l ≈ lon && b ≈ lat) || error("$(files[(v, m)]): grid differs from the other files")
        # Temperatures: the scale and offset of the files give degC; precipitation: kg m-2 month-1
        A[:, :, m] = v == "pr" ? F ./ MONTH_DAYS[m] : F .+ 273.15f0
    end
    fields[v] = A
end

dir = prepared_dir(SOURCE)
mkpath(dir)
path = joinpath(dir, "Karger2017_CHELSA-V2.1_1981-2010_Pyrenees.nc")
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
    for (name, units, long_name, std) in (
            ("tas", "K", "near-surface air temperature, monthly mean", "air_temperature"),
            ("tasmax", "K", "daily maximum near-surface air temperature, monthly mean", "air_temperature"),
            ("tasmin", "K", "daily minimum near-surface air temperature, monthly mean", "air_temperature"),
            ("pr", "kg m-2 d-1", "precipitation, monthly mean (mm water equivalent per day)", "precipitation_amount"))
        defVar(ds, name, fields[name], ("lon", "lat", "month"); fillvalue=NaN32, deflatelevel=1,
               chunksizes=[nx, ny, 1], attrib=["units" => units, "long_name" => long_name, "standard_name" => std])
    end
    ds.attrib["title"] = "CHELSA V2.1 monthly climatology 1981-2010, Pyrenees"
    ds.attrib["references"] = "Karger, D. N., Conrad, O., Boehner, J., Kawohl, T., Kreft, H., Soria-Auza, R. W., " *
                              "Zimmermann, N. E., Linder, H. P., and Kessler, M.: Climatologies at high resolution " *
                              "for the earth's land surface areas, Sci. Data, 4, 170122, doi:10.1038/sdata.2017.122, " *
                              "2017. Data: Karger, D. N. et al.: Climatologies at high resolution for the earth's " *
                              "land surface areas, EnviDat, doi:10.16904/envidat.228, 2021"
    ds.attrib["doi"] = "10.16904/envidat.228"
    ds.attrib["license"] = "CC0 1.0"
    ds.attrib["period"] = "1981-2010"
    ds.attrib["comment"] = "CHELSA V2.1 climatologies, 30 arc seconds, clipped to $(BOX[1])-$(BOX[3]) E, " *
                           "$(BOX[4])-$(BOX[2]) N (gdal_translate -projwin through /vsicurl/). Temperatures from " *
                           "the scale and offset of the files (degC) + 273.15; pr from kg m-2 month-1 divided by " *
                           "the mean length of the month (February 28.25 days)."
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("atmosphere"))
end
println("Wrote $path")
