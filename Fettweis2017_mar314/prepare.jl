# Prepare the MAR v3.14 (ERA5) surface mass balance and surface climate of Greenland for
# remapping: from the monthly outputs on the 1 km ISMIP6 grid (one file per year), write
# to $FESMDATA_WORK/prepared/Fettweis2017_mar314/
#
#   MARv3.14_ERA5_1981-2010.nc, MARv3.14_ERA5_1991-2020.nc   monthly climatologies (x, y, month)
#   MARv3.14_ERA5_annual_1940-2025.nc                        annual time series (x, y, time)
#
# with smb, melt, runoff, sf, rf, pr (kg m-2 yr-1), t2m, T_srf (K), and z_srf, mask, f_ice:
# the names and units of the SMB dataset (as RACMO, vanDalum2025_racmo24).
#
# Usage:
#     julia --project=Fettweis2017_mar314 Fettweis2017_mar314/prepare.jl download   # only download (107 GB)
#     julia --project=Fettweis2017_mar314 Fettweis2017_mar314/prepare.jl            # download if missing, prepare

using DataManifest
using Dates
using Downloads
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "mar314_era5_1km_monthly"
const YEARS = 1940:2025
const PERIODS = (1981:2010, 1991:2020)

# EPSG:3413 (WGS84 polar stereographic north, true scale at 70N, central meridian 45W)
const PROJ = "+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +x_0=0 +y_0=0 +ellps=WGS84 +units=m"

# Fields: name, MAR variable, long name. The fluxes are in mm w.e. (kg m-2) per month
# in MAR; the *corr variables are corrected for the elevation of the 1 km grid.
const FLUXES = [("smb", "SMBcorr", "surface mass balance"),
                ("melt", "MEcorr", "melt"),
                ("runoff", "RUcorr", "runoff"),
                ("sf", "SF", "snowfall"),
                ("rf", "RF", "rainfall")]
const PR = ("pr", "precipitation (snowfall + rainfall)")
const TEMPS = [("t2m", "T2Mcorr", "near-surface (2 m) air temperature"),
               ("T_srf", "STcorr", "surface temperature")]
const NAMES = [first.(FLUXES); PR[1]; first.(TEMPS)]

# Classes of the MAR mask MSK. 2 and 3 are glaciers and ice caps separate from the ice
# sheet (MAR counts 3 and 4 in its ice sheet totals).
const MASK_FLAGS = Int8[0, 1, 2, 3, 4]
const MASK_MEANINGS = "ocean ice_free_land glaciers_and_ice_caps_2 glaciers_and_ice_caps_3 ice_sheet"

# ---------------------------------------------------------------------------
# Original files
# ---------------------------------------------------------------------------

"Download the files of the years missing from the datasets folder; return their paths."
function original_files()
    db = manifest()
    dir = get_dataset_path(db, KEY)
    mkpath(dir)
    uris = Dict(basename(u) => u for u in db.datasets[KEY].uris)
    paths = String[]
    for year in YEARS
        name = "MARv3.14-monthly-ERA5-$year.nc"
        path = joinpath(dir, name)
        if !isfile(path)
            println("Downloading $(uris[name])")
            Downloads.download(uris[name], path * ".part")
            mv(path * ".part", path)
        end
        push!(paths, path)
    end
    return paths
end

# A MAR field as (x, y[, month]), with NaN for its fill value (-1e19)
function read_mar(ds, name)
    A = Array(ds[name].var)
    @inbounds for i in eachindex(A)
        abs(A[i]) > 1.0f18 && (A[i] = NaN32)
    end
    return A
end

# Days per year of the rates of the monthly climatologies (kg m-2 yr-1)
const DAYS_PER_YEAR = 365.25

"Monthly fields of one year: fluxes in kg m-2 d-1, temperatures in K."
function read_year(path, year)
    NCDataset(path) do ds
        length(ds["time"]) == 12 || error("$path has $(length(ds["time"])) months")
        F = Dict{String,Array{Float32,3}}()
        for (name, var, _) in FLUXES
            A = read_mar(ds, var)
            for m in 1:12
                A[:, :, m] ./= daysinmonth(year, m)
            end
            F[name] = A
        end
        F[PR[1]] = F["sf"] .+ F["rf"]
        for (name, var, _) in TEMPS
            F[name] = read_mar(ds, var) .+ 273.15f0
        end
        return F
    end
end

# Annual total (fluxes, kg m-2 yr-1) or mean (temperatures) of monthly fields
function annual(A, year, total)
    S = zeros(Float32, size(A, 1), size(A, 2))
    for m in 1:12
        S .+= daysinmonth(year, m) .* view(A, :, :, m)
    end
    return total ? S : S ./ daysinyear(year)
end

# ---------------------------------------------------------------------------
# Prepared files
# ---------------------------------------------------------------------------

function define_file(path, x, y, static, extra_dim, extra_values, extra_attrib, title)
    ds = NCDataset(path, "c")
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate",
                                        "long_name" => "x"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate",
                                        "long_name" => "y"])
    defVar(ds, extra_dim, extra_values, (extra_dim,); attrib=extra_attrib)
    defVar(ds, "crs", Int32, (); attrib=[
        "grid_mapping_name" => "polar_stereographic", "proj_params" => PROJ,
        "straight_vertical_longitude_from_pole" => -45.0, "standard_parallel" => 70.0,
        "latitude_of_projection_origin" => 90.0, "false_easting" => 0.0, "false_northing" => 0.0,
        "semi_major_axis" => 6378137.0, "inverse_flattening" => 298.257223563])
    gm = "grid_mapping" => "crs"
    defVar(ds, "z_srf", static.z_srf, ("x", "y"); deflatelevel=1,
           attrib=["units" => "m", "long_name" => "surface elevation", gm])
    defVar(ds, "mask", static.mask, ("x", "y"); deflatelevel=1,
           attrib=["units" => "1", "long_name" => "land and ice mask of MAR (MSK)",
                   "flag_values" => MASK_FLAGS, "flag_meanings" => MASK_MEANINGS, gm])
    defVar(ds, "f_ice", static.f_ice, ("x", "y"); deflatelevel=1,
           attrib=["units" => "1", "long_name" => "ice-covered fraction (ice sheet, glaciers and ice caps)", gm])
    nx, ny = length(x), length(y)
    cm = extra_dim == "month" ? "time: mean within months time: mean over years" : "time: sum within years"
    for (name, long_name) in [[(n, l) for (n, _, l) in FLUXES]; PR]
        defVar(ds, name, Float32, ("x", "y", extra_dim); fillvalue=NaN32, deflatelevel=1, shuffle=true,
               chunksizes=[nx, ny, 1], attrib=["units" => "kg m-2 yr-1", "long_name" => long_name,
                                               "cell_methods" => cm, gm])
    end
    cm = extra_dim == "month" ? "time: mean within months time: mean over years" : "time: mean within years"
    for (name, _, long_name) in TEMPS
        defVar(ds, name, Float32, ("x", "y", extra_dim); fillvalue=NaN32, deflatelevel=1, shuffle=true,
               chunksizes=[nx, ny, 1], attrib=["units" => "K", "long_name" => long_name,
                                               "cell_methods" => cm, gm])
    end
    ds.attrib["title"] = title
    ds.attrib["references"] =
        "Fettweis, X., Box, J. E., Agosta, C., Amory, C., Kittel, C., Lang, C., van As, D., Machguth, H., " *
        "and Gallée, H.: Reconstructions of the 1900-2015 Greenland ice sheet surface mass balance using " *
        "the regional climate MAR model, The Cryosphere, 11, 1015-1033, 2017, doi:10.5194/tc-11-1015-2017; " *
        "Timmermans, G., Noël, B., Kittel, C., Dethinne, T., Ghilain, N., and Fettweis, X.: Evaluation of " *
        "MARv3.14 over the Greenland Ice Sheet, EGUsphere [preprint], 2026, doi:10.5194/egusphere-2026-2341"
    ds.attrib["doi"] = "10.5194/tc-11-1015-2017"
    ds.attrib["license"] = "No licence stated by the provider (University of Liège, X. Fettweis); outputs " *
                           "freely available at http://ftp.climato.be/fettweis/MARv3.14/Greenland/, " *
                           "to be cited as in references"
    ds.attrib["source_data"] = "MAR v3.14.3 forced by ERA5, monthly outputs on the 1 km ISMIP6 grid: " *
                               "http://ftp.climato.be/fettweis/MARv3.14/Greenland/ERA5-1km-monthly/"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("smb"))
    return ds
end

function prepare(paths)
    x, y, static = NCDataset(paths[1]) do ds
        msk = ds["MSK"].var[:, :]
        x, y = Float64.(ds["x"][:]), Float64.(ds["y"][:])
        z = ds["SRF"].var[:, :]
        x, y, (z_srf=z, mask=Int8.(msk), f_ice=Float32.(msk .>= 2))
    end
    dir = prepared_dir("Fettweis2017_mar314")
    mkpath(dir)

    path = joinpath(dir, "MARv3.14_ERA5_annual_$(first(YEARS))-$(last(YEARS)).nc")
    ts = define_file(path, x, y, static, "time", [DateTime(yr, 7, 1) for yr in YEARS],
                     ["units" => "days since 1940-01-01 00:00:00", "calendar" => "standard",
                      "standard_name" => "time", "long_name" => "time (middle of the year)"],
                     "Greenland surface mass balance and surface climate, MAR v3.14 (ERA5), annual $(first(YEARS))-$(last(YEARS))")
    sums = [Dict(n => zeros(Float64, length(x), length(y), 12) for n in NAMES) for _ in PERIODS]

    for (k, (year, file)) in enumerate(zip(YEARS, paths))
        t = @elapsed begin
            F = read_year(file, year)
            for (name, _, _) in FLUXES
                ts[name][:, :, k] = annual(F[name], year, true)
            end
            ts[PR[1]][:, :, k] = annual(F[PR[1]], year, true)
            for (name, _, _) in TEMPS
                ts[name][:, :, k] = annual(F[name], year, false)
            end
            for (p, period) in enumerate(PERIODS)
                year in period || continue
                foreach(n -> sums[p][n] .+= F[n], NAMES)
            end
        end
        println("$year: $(round(t; digits=1)) s")
    end
    close(ts)
    println("Wrote $path")

    for (p, period) in enumerate(PERIODS)
        label = "$(first(period))-$(last(period))"
        path = joinpath(dir, "MARv3.14_ERA5_$label.nc")
        ds = define_file(path, x, y, static, "month", Int32.(1:12),
                         ["units" => "1", "long_name" => "month of the year"],
                         "Greenland surface mass balance and surface climate, MAR v3.14 (ERA5), monthly climatology $label")
        ds.attrib["period"] = label
        # Monthly means: fluxes as rates in kg m-2 yr-1, temperatures as they are
        for n in NAMES
            f = n in first.(TEMPS) ? 1.0 : DAYS_PER_YEAR
            ds[n][:, :, :] = Float32.(sums[p][n] .* (f / length(period)))
        end
        close(ds)
        println("Wrote $path")
    end
end

paths = original_files()
"download" in ARGS || prepare(paths)
