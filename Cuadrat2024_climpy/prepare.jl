# Prepare CLIMPY, the daily gridded climate of the Pyrenees (Cuadrat et al., 2024),
# for remapping: monthly climatologies of the daily maximum, minimum and mean temperature
# and of the precipitation, for 1981-2010 and 1991-2020, on the 1 km grid of the data
# (UTM zone 30N, GRS80), as
#     $FESMDATA_PREPARED/Cuadrat2024_climpy/Cuadrat2024_CLIMPY_<period>.nc
#
# The original files (Zenodo, datamanifest keys climpy_<var>) are daily, 1981-2020, one per
# variable, each with the field named `pcp`. They are read one year at a time.
#
# Usage:
#     julia --project=Cuadrat2024_climpy Cuadrat2024_climpy/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_PREPARED/Cuadrat2024_climpy/Cuadrat2024_CLIMPY_1981-2010.nc PYR-1KM

using NCDatasets
using Dates

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const SOURCE = "Cuadrat2024_climpy"
const PERIODS = [(1981, 2010), (1991, 2020)]
const T0 = 273.15f0
# The PROJ string of the files (crs:proj4): UTM zone 30N on the GRS80 ellipsoid, in m
const PROJ = "+proj=utm +zone=30 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"

db = manifest()
files = Dict(v => download_dataset(db, "climpy_$v") for v in ("tmax", "tmin", "pcp"))

# Grid: cell centres in m (easting, northing), checked to be the same in the three files
function read_grid(path)
    NCDataset(path) do ds
        dimnames(ds["pcp"]) == ("easting", "northing", "time") || error("$path: unexpected dimensions of pcp")
        x, y = Float64.(ds["easting"][:]), Float64.(ds["northing"][:])
        proj = strip(ds["crs"].attrib["proj4"])
        proj == PROJ || error("$path: unexpected projection $proj")
        return x, y
    end
end
x, y = read_grid(files["tmax"])
all(read_grid(f) == (x, y) for f in values(files)) || error("the grids of the CLIMPY files differ")
issorted(x) || error("easting not ascending")
yperm = sortperm(y)          # northing as ascending
nx, ny = length(x), length(y)

"""
    monthly_climatology(path, y0, y1) -> Array{Float32,3}

Mean over the days of each month of the years y0:y1 (nx, ny, 12) of the field `pcp` of
`path` (missing values excluded day by day), read one year at a time.
"""
function monthly_climatology(path, y0, y1)
    s = zeros(Float64, nx, ny, 12)
    n = zeros(Int32, nx, ny, 12)
    NCDataset(path) do ds
        dates = ds["time"][:]
        years = Dates.year.(dates)
        months = Dates.month.(dates)
        for yr in y0:y1
            k = findall(==(yr), years)
            isempty(k) && error("$path: no days in $yr")
            A = ds["pcp"][:, :, first(k):last(k)]            # missing where no data
            for (j, kk) in enumerate(first(k):last(k))
                m = months[kk]
                @inbounds for iy in 1:ny, ix in 1:nx
                    v = A[ix, iy, j]
                    ismissing(v) && continue
                    s[ix, iy, m] += v
                    n[ix, iy, m] += 1
                end
            end
        end
    end
    C = Float32.(ifelse.(n .> 0, s ./ max.(n, 1), NaN))
    return C[:, yperm, :]
end

dir = prepared_dir(SOURCE)
mkpath(dir)
for (y0, y1) in PERIODS
    tasmax = monthly_climatology(files["tmax"], y0, y1) .+ T0
    tasmin = monthly_climatology(files["tmin"], y0, y1) .+ T0
    pr = monthly_climatology(files["pcp"], y0, y1)                 # mm d-1 = kg m-2 d-1
    tas = 0.5f0 .* (tasmax .+ tasmin)

    path = joinpath(dir, "Cuadrat2024_CLIMPY_$y0-$y1.nc")
    rm(path; force=true)
    NCDataset(path, "c") do ds
        defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
        defVar(ds, "y", y[yperm], ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
        defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
        defVar(ds, "crs", Int32(0), (); attrib=["proj_params" => PROJ,
                                                "long_name" => "UTM zone 30N on the GRS80 ellipsoid (CLIMPY grid)"])
        for (name, A, units, long_name, std) in (
                ("tas", tas, "K", "near-surface air temperature, monthly mean (mean of the daily maximum and minimum)", "air_temperature"),
                ("tasmax", tasmax, "K", "daily maximum near-surface air temperature, monthly mean", "air_temperature"),
                ("tasmin", tasmin, "K", "daily minimum near-surface air temperature, monthly mean", "air_temperature"),
                ("pr", pr, "kg m-2 d-1", "precipitation, monthly mean (mm water equivalent per day)", "precipitation_amount"))
            defVar(ds, name, A, ("x", "y", "month"); fillvalue=NaN32, deflatelevel=1,
                   chunksizes=[nx, ny, 1],
                   attrib=["units" => units, "long_name" => long_name, "standard_name" => std, "grid_mapping" => "crs"])
        end
        ds.attrib["title"] = "CLIMPY, climate of the Pyrenees: monthly climatology $y0-$y1"
        ds.attrib["references"] = "Cuadrat, J. M., Serrano-Notivoli, R., Prohom, M., Cunillera, J., Tejedor, E., " *
                                  "Saz, M. A., de Luis, M., Llabres-Brustenga, A., and Soubeyroux, J.-M.: Climate of " *
                                  "the Pyrenees: Extremes indices and long-term trends, Sci. Total Environ., 933, " *
                                  "173052, doi:10.1016/j.scitotenv.2024.173052, 2024. Data: Climate of the Pyrenees " *
                                  "(CLIMPY), Zenodo, doi:10.5281/zenodo.10972236"
        ds.attrib["doi"] = "10.5281/zenodo.10972236"
        ds.attrib["license"] = "CC BY 4.0"
        ds.attrib["period"] = "$y0-$y1"
        ds.attrib["comment"] = "Monthly means over the days of $y0-$y1 of the daily CLIMPY grids (1 km, UTM 30N). " *
                               "tas is the mean of tasmax and tasmin. Missing outside the area of the data set " *
                               "(the Pyrenees and their forelands)."
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("atmosphere"))
    end
    println("Wrote $path")
end
