# Prepare CHELSA-TraCE21k v1.0 (Karger et al., 2023; 30 arc seconds, about 1 km), the
# TraCE-21ka transient simulation downscaled to 1 km, over the Pyrenees, for remapping:
# monthly mean, maximum and minimum near-surface air temperature and precipitation of the
# 221 centennial time steps from the Last Glacial Maximum to the present, with the
# paleo-orography and the glacier layers of each step, as
#     $FESMDATA_PREPARED/Karger2023_chelsatrace21k/Karger2023_CHELSA-TraCE21k_Pyrenees.nc
# and the ice extent at the first time step (the Last Glacial Maximum) as
#     $FESMDATA_PREPARED/Karger2023_chelsatrace21k/Karger2023_CHELSA-TraCE21k-LGM-ice_Pyrenees.nc
#
# The global Cloud-Optimized GeoTIFFs (one per variable, month and time step; about 6-7 TB
# in all) are not downloaded: only the box BOX is read, through GDAL /vsicurl/, and kept as
# clipped GeoTIFFs in the storage folder of the datamanifest entry chelsa_trace21k (about
# 8,600 files, 1 GB). Run with threads (parallel requests), on a node with internet access:
#     julia -t 16 --project=Karger2023_chelsatrace21k Karger2023_chelsatrace21k/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_PREPARED/Karger2023_chelsatrace21k/Karger2023_CHELSA-TraCE21k_Pyrenees.nc PYR-1KM

using NCDatasets
import ArchGDAL as AG

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "chelsa_trace21k"
const SOURCE = "Karger2023_chelsatrace21k"
const URL = "https://os.zhdk.cloud.switch.ch/chelsav1/chelsa_trace"
const IDS = -200:20                         # time IDs of the files (centennial steps)
const MONTHLY = ["tasmax", "tasmin", "pr"]
const STEP = ["dem", "gle", "glz"]          # one per time step, in the folder orog/
# Box read from the global files, as gdal_translate -projwin (ulx, uly, lrx, lry; degrees):
# the PYR domain (about 1.85W-2.85E, 41.9-43.6N) with a margin of at least 0.4 degrees
const BOX = (-2.5, 44.0, 3.5, 41.3)
const MONTH_DAYS = Float32[31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

# File names: CHELSA_TraCE21k_<var>_<month>_<id>_V1.0.tif (month not zero-padded) and
# CHELSA_TraCE21k_<dem|gle|glz>_<id>_V1.0.tif
fname(v, m, id) = "CHELSA_TraCE21k_$(v)_$(m)_$(id)_V1.0.tif"
fname(v, id) = "CHELSA_TraCE21k_$(v)_$(id)_V1.0.tif"
url(v, m, id) = "$URL/$v/$(fname(v, m, id))"
url(v, id) = "$URL/orog/$(fname(v, id))"

"""
    clip(url, out; tries=3) -> Bool

Write the box BOX of the GeoTIFF at `url` (read through /vsicurl/) to `out` (kept if it
exists). False if the file does not exist on the server.
"""
function clip(url, out; tries=3)
    isfile(out) && return true
    tmp = out * ".tmp"
    for k in 1:tries
        try
            AG.read("/vsicurl/" * url) do ds
                AG.gdaltranslate(ds, ["-of", "GTiff", "-co", "COMPRESS=DEFLATE",
                                      "-projwin", string.(BOX)...]; dest=tmp) do _ end
            end
            mv(tmp, out; force=true)
            return true
        catch err
            # GDAL cannot open a missing file (HTTP 404, or no dataset to translate): no retry
            occursin(r"404|does not exist|No such file|not recognized|No source dataset"i, sprint(showerror, err)) && return false
            k == tries && rethrow(err)
            sleep(10k)
        end
    end
end

"""
    read_tif(path) -> (lon, lat, A)

Cell centres (degrees, latitudes ascending) and band 1 (raw values, Float32, NaN for no
data) of a north-up lon-lat GeoTIFF.
"""
function read_tif(path)
    AG.read(path) do ds
        x0, dx, rx, y0, ry, dy = AG.getgeotransform(ds)
        (rx == 0 && ry == 0 && dy < 0) || error("$path: not a north-up grid")
        nx, ny = AG.width(ds), AG.height(ds)
        lon = x0 .+ dx .* ((1:nx) .- 0.5)
        lat = reverse(y0 .+ dy .* ((1:ny) .- 0.5))
        b = AG.getband(ds, 1)
        nd = AG.getnodatavalue(b)
        A = reverse(AG.read(b); dims=2)
        return collect(lon), collect(lat), map(v -> (nd !== nothing && v == nd) ? NaN32 : Float32(v), A)
    end
end

db = manifest()
store = get_dataset_path(db, KEY)
mkpath(store)

# Clip all files (threads: parallel requests); record the ones missing on the server
jobs = [[(url(v, m, id), joinpath(store, fname(v, m, id))) for v in MONTHLY for m in 1:12 for id in IDS];
        [(url(v, id), joinpath(store, fname(v, id))) for v in STEP for id in IDS]]
found = Vector{Bool}(undef, length(jobs))
Threads.@threads for k in eachindex(jobs)
    found[k] = clip(jobs[k]...)
end
missing_files = basename.(last.(jobs[.!found]))
println("Clipped $(count(found)) files, $(length(missing_files)) missing on the server: ", join(missing_files, ", "))

lon, lat, _ = read_tif(joinpath(store, fname("gle", first(IDS))))
nx, ny, nt = length(lon), length(lat), length(IDS)
ok(path) = isfile(path) && (path ∉ joinpath.(store, missing_files))

# Time: the time IDs are centuries of the calendar (-200 = 20,000 BCE, about 22 ka, the
# start of TraCE-21ka; 19 = 1900 CE; 20 = 2000 CE), written as years before 1950 CE
# (21950 to -50), oldest first; the IDs are kept as time_id.
age = 1950 .- 100 .* collect(IDS)

dir = prepared_dir(SOURCE)
mkpath(dir)
attrib_common(ds) = begin
    ds.attrib["references"] = "Karger, D. N., Nobis, M. P., Normand, S., Graham, C. H., and Zimmermann, N. E.: " *
                              "CHELSA-TraCE21k - high-resolution (1 km) downscaled transient temperature and " *
                              "precipitation data since the Last Glacial Maximum, Clim. Past, 19, 439-456, " *
                              "doi:10.5194/cp-19-439-2023, 2023. Data: CHELSA-TraCE21k, EnviDat, " *
                              "doi:10.16904/envidat.211"
    ds.attrib["doi"] = "10.16904/envidat.211"
    ds.attrib["license"] = "CC BY-SA 4.0 (EnviDat record; the CHELSA website states CC0 1.0): " *
                           "derived products must keep the ShareAlike terms"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("paleoclimate"))
end
define_grid!(ds) = begin
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
end

path = joinpath(dir, "Karger2023_CHELSA-TraCE21k_Pyrenees.nc")
rm(path; force=true)
interpolated = String[]
NCDataset(path, "c") do ds
    define_grid!(ds)
    defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
    defVar(ds, "time", Float64.(age), ("time",);
           attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)",
                   "comment" => "centennial steps of CHELSA-TraCE21k: time = 1950 - 100 time_id"])
    defVar(ds, "time_id", Int32.(collect(IDS)), ("time",);
           attrib=["units" => "1", "long_name" => "time ID of the CHELSA-TraCE21k files (century of the calendar)"])
    dims3, dims4 = ("lon", "lat", "time"), ("lon", "lat", "month", "time")
    v = Dict(
        "tas" => defVar(ds, "tas", Float32, dims4; fillvalue=NaN32, deflatelevel=1, chunksizes=[nx, ny, 1, 1],
                        attrib=["units" => "K", "long_name" => "near-surface air temperature, monthly mean (mean of tasmax and tasmin)",
                                "standard_name" => "air_temperature"]),
        "tasmax" => defVar(ds, "tasmax", Float32, dims4; fillvalue=NaN32, deflatelevel=1, chunksizes=[nx, ny, 1, 1],
                           attrib=["units" => "K", "long_name" => "daily maximum near-surface air temperature, monthly mean",
                                   "standard_name" => "air_temperature"]),
        "tasmin" => defVar(ds, "tasmin", Float32, dims4; fillvalue=NaN32, deflatelevel=1, chunksizes=[nx, ny, 1, 1],
                           attrib=["units" => "K", "long_name" => "daily minimum near-surface air temperature, monthly mean",
                                   "standard_name" => "air_temperature"]),
        "pr" => defVar(ds, "pr", Float32, dims4; fillvalue=NaN32, deflatelevel=1, chunksizes=[nx, ny, 1, 1],
                       attrib=["units" => "kg m-2 d-1", "long_name" => "precipitation, monthly mean (mm water equivalent per day)",
                               "standard_name" => "precipitation_amount"]),
        "dem" => defVar(ds, "dem", Float32, dims3; fillvalue=NaN32, deflatelevel=1, chunksizes=[nx, ny, 1],
                        attrib=["units" => "m", "long_name" => "paleo-orography of the downscaling (surface elevation of the time step)",
                                "standard_name" => "surface_altitude"]),
        "glz" => defVar(ds, "glz", Float32, dims3; fillvalue=NaN32, deflatelevel=1, chunksizes=[nx, ny, 1],
                        attrib=["units" => "m", "long_name" => "glacier surface elevation of the TraCE-21ka ice sheets (glacier layer glz), only over glaciers"]),
        "gle" => defVar(ds, "gle", Int8, dims3; fillvalue=Int8(-1), deflatelevel=1, chunksizes=[nx, ny, 1],
                        attrib=["units" => "1", "long_name" => "glacier extent (glacier layer gle)",
                                "flag_values" => Int8[0, 1], "flag_meanings" => "no_ice ice"]),
    )
    for (k, id) in enumerate(IDS)
        # Monthly fields: tasmax, tasmin in K x 10, pr in kg m-2 month-1 (no scale metadata)
        F = Dict(var => Array{Float32}(undef, nx, ny, 12) for var in MONTHLY)
        for var in MONTHLY, m in 1:12
            f = joinpath(store, fname(var, m, id))
            if ok(f)
                _, _, A = read_tif(f)
                F[var][:, :, m] = var == "pr" ? A ./ MONTH_DAYS[m] : A .* 0.1f0
            else
                # Missing on the server: linear interpolation in time between the neighbouring
                # steps of the same month
                fa, fb = joinpath(store, fname(var, m, id - 1)), joinpath(store, fname(var, m, id + 1))
                (ok(fa) && ok(fb)) || error("$(fname(var, m, id)) and a neighbouring step are missing")
                A = 0.5f0 .* (read_tif(fa)[3] .+ read_tif(fb)[3])
                F[var][:, :, m] = var == "pr" ? A ./ MONTH_DAYS[m] : A .* 0.1f0
                push!(interpolated, fname(var, m, id))
            end
        end
        v["tasmax"][:, :, :, k] = F["tasmax"]
        v["tasmin"][:, :, :, k] = F["tasmin"]
        v["tas"][:, :, :, k] = 0.5f0 .* (F["tasmax"] .+ F["tasmin"])
        v["pr"][:, :, :, k] = F["pr"]
        v["dem"][:, :, k] = read_tif(joinpath(store, fname("dem", id)))[3]
        v["glz"][:, :, k] = read_tif(joinpath(store, fname("glz", id)))[3]
        g = read_tif(joinpath(store, fname("gle", id)))[3]
        v["gle"][:, :, k] = Int8.(ifelse.(isnan.(g), 0, g))
    end
    ds.attrib["title"] = "CHELSA-TraCE21k v1.0, monthly climate of 221 centennial time steps from the Last " *
                         "Glacial Maximum to the present, Pyrenees"
    attrib_common(ds)
    ds.attrib["comment"] = "CHELSA-TraCE21k v1.0, 30 arc seconds, clipped to $(BOX[1])-$(BOX[3]) E, $(BOX[4])-$(BOX[2]) N " *
                           "(gdal_translate -projwin through /vsicurl/). tasmax, tasmin from K x 10; tas = (tasmax + " *
                           "tasmin) / 2; pr from kg m-2 month-1 divided by the mean length of the month (February " *
                           "28.25 days). The temperatures refer to the paleo-orography dem of each step. gle: 1 where " *
                           "the file has 1, 0 where it has no data. The lapse rate tz of the data set (on the TraCE-21ka " *
                           "grid, about 3.75 degrees) is not included." *
                           (isempty(interpolated) ? "" : " Not on the server, interpolated in time between the neighbouring " *
                                                         "steps: " * join(interpolated, ", ") * ".")
end
println("Wrote $path")

# Ice extent at the Last Glacial Maximum (first time step, ID -200)
path = joinpath(dir, "Karger2023_CHELSA-TraCE21k-LGM-ice_Pyrenees.nc")
rm(path; force=true)
NCDataset(path, "c") do ds
    define_grid!(ds)
    g = read_tif(joinpath(store, fname("gle", first(IDS))))[3]
    defVar(ds, "mask_ice", Int8.(ifelse.(isnan.(g), 0, g)), ("lon", "lat"); fillvalue=Int8(-1), deflatelevel=1,
           attrib=["units" => "1", "long_name" => "ice extent at the Last Glacial Maximum (glacier layer gle, time ID $(first(IDS)), $(first(age)) years before 1950 CE)",
                   "flag_values" => Int8[0, 1], "flag_meanings" => "no_ice ice"])
    ds.attrib["title"] = "CHELSA-TraCE21k v1.0, ice extent at the Last Glacial Maximum, Pyrenees"
    attrib_common(ds)
    ds.attrib["comment"] = "gle of the first time step of CHELSA-TraCE21k (ID $(first(IDS))), 30 arc seconds, " *
                           "clipped to $(BOX[1])-$(BOX[3]) E, $(BOX[4])-$(BOX[2]) N"
end
println("Wrote $path")
