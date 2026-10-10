# Prepare ERA5 (Hersbach et al., 2020) monthly climatologies for remapping, from the
# monthly means of the DKRZ ERA5 pool (GRIB, reduced Gaussian N320): for 1981-2010 and
# 1991-2020, surface fields and fields on pressure levels, as
#     $FESMDATA_WORK/prepared/Hersbach2020_era5/Hersbach2020_ERA5_<period>.nc
#     $FESMDATA_WORK/prepared/Hersbach2020_era5/Hersbach2020_ERA5-plev_<period>.nc
# cdo makes the climatology of each field on the regular Gaussian grid (intermediate
# files in $FESMDATA_WORK/era5/), which is converted here to the prepared files.
# Needs cdo (module load cdo) and about 150 GB of reading: run on a compute node,
#     sbatch Hersbach2020_era5/prepare.sbatch
#
# Usage:
#     julia --project=Hersbach2020_era5 Hersbach2020_era5/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Hersbach2020_era5/Hersbach2020_ERA5_1991-2020.nc all

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "era5_dkrz_pool"
const SOURCE = "Hersbach2020_era5"
const PERIODS = [(1981, 2010), (1991, 2020)]
const G0 = 9.80665                                       # m s-2, as used by ECMWF
const LEVELS = [1000, 950, 850, 750, 700, 650, 600, 550, 500]   # hPa

# Fields: name => (pool folder, parameter code, scale, units, long_name, standard_name).
# The 1M files are monthly means of daily means, or of daily sums for accumulated
# fields (tp, sf in m of water per day, here kg m-2 d-1).
const SURFACE = [
    "sp" => ("sf/an", "134", 1, "Pa", "surface pressure", "surface_air_pressure"),
    "t2m" => ("sf/an", "167", 1, "K", "2 m air temperature", "air_temperature"),
    "sst" => ("sf/an", "034", 1, "K", "sea surface temperature", "sea_surface_temperature"),
    "u10" => ("sf/an", "165", 1, "m s-1", "10 m eastward wind", "eastward_wind"),
    "v10" => ("sf/an", "166", 1, "m s-1", "10 m northward wind", "northward_wind"),
    "ws10" => ("sf/an", "207", 1, "m s-1", "10 m wind speed (mean of the daily mean speed)", "wind_speed"),
    "tcc" => ("sf/an", "164", 1, "1", "total cloud cover", "cloud_area_fraction"),
    "tcw" => ("sf/an", "136", 1, "kg m-2", "total column water (vapour, cloud liquid and ice, rain, snow)", ""),
    "tclw" => ("sf/fc", "078", 1, "kg m-2", "total column cloud liquid water", "atmosphere_mass_content_of_cloud_liquid_water"),
    "tciw" => ("sf/fc", "079", 1, "kg m-2", "total column cloud ice water", "atmosphere_mass_content_of_cloud_ice"),
    "al" => ("sf/an", "243", 1, "1", "surface albedo, including snow and sea ice (forecast albedo)", "surface_albedo"),
    "pr" => ("sf/fc", "228", 1000, "kg m-2 d-1", "total precipitation (mm water equivalent per day)", "precipitation_amount"),
    "sf" => ("sf/fc", "144", 1000, "kg m-2 d-1", "snowfall (mm water equivalent per day)", "snowfall_amount"),
]
# Invariant fields
const INVARIANT = [
    "zs" => ("sf/an", "129", 1 / G0, "m", "surface elevation of the model (surface geopotential / g)", "surface_altitude"),
    "lsm" => ("sf/an", "172", 1, "1", "land fraction of the model", "land_area_fraction"),
]
const PLEV = [
    "t" => ("pl/an", "130", 1, "K", "air temperature", "air_temperature"),
    "z" => ("pl/an", "129", 1 / G0, "m", "geopotential height (geopotential / g)", "geopotential_height"),
    "u" => ("pl/an", "131", 1, "m s-1", "eastward wind", "eastward_wind"),
    "v" => ("pl/an", "132", 1, "m s-1", "northward wind", "northward_wind"),
    "w" => ("pl/an", "135", 1, "Pa s-1", "vertical velocity (pressure tendency)", "lagrangian_tendency_of_air_pressure"),
]

workdir() = joinpath(_env("FESMDATA_WORK"), "era5")

# Monthly files of a field for the years y0:y1, e.g. sf/an/1M/134/E5sf00_1M_1981_134.grb
function monthly_files(pool, dir, param, y0, y1)
    typeid = endswith(dir, "/fc") ? "12" : "00"
    level = split(dir, "/")[1]
    files = [joinpath(pool, dir, "1M", param, "E5$(level)$(typeid)_1M_$(y)_$(param).grb") for y in y0:y1]
    for f in files
        isfile(f) || error("missing ERA5 file $f")
    end
    return files
end

"""
    cdo_climatology(name, files, out; levels=nothing)

Monthly climatology (12 steps) of the GRIB files `files` with cdo, on the regular Gaussian
grid (`setgridtype,regular`: each latitude row of the reduced grid is filled to the full
number of longitudes by linear interpolation along the row, rows are not changed), as the
NetCDF file `out` with the field `name`. Kept if it exists.
"""
function cdo_climatology(name, files, out; levels=nothing)
    isfile(out) && return out
    sel = levels === nothing ? String[] : ["-sellevel," * join(levels .* 100, ",")]
    tmp = out * ".tmp"
    run(`cdo -s -f nc4 -b F32 -setname,$name -setgridtype,regular -ymonmean $sel -mergetime $files $tmp`)
    mv(tmp, out; force=true)
    return out
end

function cdo_invariant(name, file, out)
    isfile(out) && return out
    tmp = out * ".tmp"
    run(`cdo -s -f nc4 -b F32 -setname,$name -setgridtype,regular $file $tmp`)
    mv(tmp, out; force=true)
    return out
end

# Longitudes 0:360 to -180:180 (180 becomes -180), latitudes as in the file (N to S)
function read_grid(path)
    NCDataset(path) do ds
        lon0 = Float64.(ds["lon"][:])
        lon = ifelse.(lon0 .>= 180, lon0 .- 360, lon0)
        perm = sortperm(lon)
        return lon[perm], Float64.(ds["lat"][:]), perm
    end
end

# Field `name` of an intermediate file, scaled, in Float32 with missing values as NaN:
# a climatology as (lon, lat, month) or, on pressure levels, (lon, lat, plev, month) in
# the order of LEVELS; an invariant field (one time step) as (lon, lat).
function read_field(path, name, perm, scale)
    NCDataset(path) do ds
        A = Float32.(coalesce.(Array(ds[name]), NaN32)) .* Float32(scale)
        if !haskey(ds, "time") || length(ds["time"]) == 1
            return A[perm, :, ntuple(_ -> 1, ndims(A) - 2)...]
        end
        months = Dates.month.(ds["time"][:])
        months == 1:12 || error("$path: expected the months 1:12, found $months")
        haskey(ds, "plev") || return A[perm, :, :]
        p = round.(Int, Float64.(ds["plev"][:]) ./ 100)
        k = [something(findfirst(==(l), p), 0) for l in LEVELS]
        all(>(0), k) || error("$path: expected the levels $LEVELS hPa, found $p")
        return A[perm, :, k, :]
    end
end

function define_grid!(ds, lon, lat)
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",);
           attrib=["units" => "degrees_north", "standard_name" => "latitude",
                   "comment" => "Gaussian latitudes of the ERA5 N320 grid (spacing 0.2787 to 0.2811 degrees)"])
    defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
end

function define_field!(ds, name, A, dims, units, long_name, standard_name)
    attrib = ["units" => units, "long_name" => long_name]
    isempty(standard_name) || push!(attrib, "standard_name" => standard_name)
    chunks = (size(A, 1), size(A, 2), ones(Int, ndims(A) - 2)...)
    defVar(ds, name, A, dims; fillvalue=NaN32, deflatelevel=1, chunksizes=chunks, attrib=attrib)
end

function global_attrib!(ds, title, y0, y1)
    ds.attrib["title"] = title
    ds.attrib["references"] = "Hersbach, H., Bell, B., Berrisford, P., et al.: The ERA5 global reanalysis, " *
                              "Q. J. R. Meteorol. Soc., 146, 1999-2049, 2020"
    ds.attrib["doi"] = "10.1002/qj.3803"
    ds.attrib["license"] = "Copernicus licence (free use and redistribution with attribution): contains " *
                           "modified Copernicus Climate Change Service information $(Dates.year(now())); " *
                           "neither the European Commission nor ECMWF is responsible for any use of it"
    ds.attrib["period"] = "$y0-$y1"
    ds.attrib["comment"] = "Monthly climatology ($y0-$y1) of the ERA5 monthly means of the DKRZ data pool " *
                           "(/pool/data/ERA5/E5, data distribution by DKRZ), on the regular Gaussian N320 grid " *
                           "(the reduced Gaussian grid of the pool filled along its latitude rows)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("atmosphere"))
end

function prepare(pool, y0, y1; ntasks=16)
    wd = joinpath(workdir(), "$y0-$y1")
    mkpath(wd)
    fields = [SURFACE; PLEV]
    paths = asyncmap(fields; ntasks=ntasks) do (name, (dir, param, _...))
        levels = any(f -> f[1] == name, PLEV) ? LEVELS : nothing
        tag = levels === nothing ? name : "p_$name"
        out = joinpath(wd, "$tag.nc")
        cdo_climatology(name, monthly_files(pool, dir, param, y0, y1), out; levels=levels)
    end
    path_of = Dict(f[1] => p for (f, p) in zip(fields, paths))
    inv = Dict(name => cdo_invariant(name, joinpath(pool, dir, "IV", param, "E5$(split(dir, "/")[1])00_IV_INVARIANT_$(param).grb"),
                                     joinpath(workdir(), "$name.nc"))
               for (name, (dir, param, _...)) in INVARIANT)

    lon, lat, perm = read_grid(path_of["sp"])
    outdir = prepared_dir(SOURCE)
    mkpath(outdir)

    # Surface: invariant fields (lon, lat) and climatologies (lon, lat, month)
    path = joinpath(outdir, "Hersbach2020_ERA5_$y0-$y1.nc")
    rm(path; force=true)
    NCDataset(path, "c") do ds
        define_grid!(ds, lon, lat)
        for (name, (_, _, scale, units, long_name, std)) in INVARIANT
            define_field!(ds, name, read_field(inv[name], name, perm, scale), ("lon", "lat"), units, long_name, std)
        end
        for (name, (_, _, scale, units, long_name, std)) in SURFACE
            define_field!(ds, name, read_field(path_of[name], name, perm, scale), ("lon", "lat", "month"),
                          units, long_name, std)
        end
        global_attrib!(ds, "ERA5 monthly climatology $y0-$y1, surface fields", y0, y1)
    end
    println("Wrote $path")

    # Pressure levels (lon, lat, plev, month), with the speed of the mean wind
    path = joinpath(outdir, "Hersbach2020_ERA5-plev_$y0-$y1.nc")
    rm(path; force=true)
    NCDataset(path, "c") do ds
        define_grid!(ds, lon, lat)
        defVar(ds, "plev", Float64.(LEVELS), ("plev",);
               attrib=["units" => "hPa", "long_name" => "pressure level", "standard_name" => "air_pressure",
                       "positive" => "down"])
        dims = ("lon", "lat", "plev", "month")
        uv = Dict{String,Array{Float32,4}}()
        for (name, (_, _, scale, units, long_name, std)) in PLEV
            A = read_field(path_of[name], name, perm, scale)
            name in ("u", "v") && (uv[name] = A)
            define_field!(ds, name, A, dims, units, long_name, std)
        end
        define_field!(ds, "uv", hypot.(uv["u"], uv["v"]), dims, "m s-1",
                      "wind speed of the monthly mean wind (magnitude of u, v)", "wind_speed")
        global_attrib!(ds, "ERA5 monthly climatology $y0-$y1, pressure levels", y0, y1)
    end
    println("Wrote $path")
end

pool = download_dataset(manifest(), KEY)
for (y0, y1) in PERIODS
    prepare(pool, y0, y1)
end
