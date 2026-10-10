# Prepare the ORAS5 ocean reanalysis (Zuo et al., 2019) for remapping: potential
# temperature `to` and salinity `so` on depth levels, from the monthly means regridded
# to 1°x1° (r1x1) on the DKRZ pool (ensemble member opa0), as prepared NetCDF files in
# $FESMDATA_WORK/prepared/Zuo2019_oras5/:
#
#     ORAS5_<y0>-<y1>.nc         monthly climatology, (lon, lat, depth, month)
#     ORAS5_annual_<y0>-<y1>.nc  annual means, (lon, lat, depth, time)
#
# Land and sea floor are missing (the land-sea mask tmask_r1x1.nc is applied, as
# recommended by ECMWF for the r1x1 files). Each monthly file is read once.
#
# Usage (about 20 GB are read; run on a compute node):
#     julia --project=Zuo2019_oras5 Zuo2019_oras5/prepare.jl

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const MEMBER = "opa0"
const YEARS = 1979:2018                    # all full years on the pool
const CLIMATOLOGIES = [1981:2010]          # 1991:2020 needs 2019-2020, not on the pool
const VARS = (to=(src="votemper", units="degC", long_name="sea water potential temperature"),
              so=(src="vosaline", units="PSU", long_name="sea water salinity"))

const ROOT = get_dataset_path(manifest(), "oras5_r1x1")
const OUTDIR = prepared_dir("Zuo2019_oras5")

monthly_file(src, y, m) =
    joinpath(ROOT, src, MEMBER, "$(src)_ORAS5_1m_$(y)$(lpad(m, 2, '0'))_r1x1.nc")

# Source longitudes are 0:359; rotate to -180:179
function read_grid()
    NCDataset(monthly_file("votemper", first(YEARS), 1)) do ds
        lon, lat, depth = Float64.(ds["lon"][:]), Float64.(ds["lat"][:]), Float32.(ds["deptht"][:])
        shift = findfirst(>=(180), lon) - 1
        lon = circshift(ifelse.(lon .>= 180, lon .- 360, lon), -shift)
        return lon, lat, depth, shift
    end
end

const LON, LAT, DEPTH, SHIFT = read_grid()

# Ocean cells (true) of the T grid, (lon, lat, depth)
function read_ocean()
    NCDataset(joinpath(ROOT, "LSM_r1x1", "tmask_r1x1.nc")) do ds
        m = ds["tmask"].var[:, :, :, 1]
        size(m) == (length(LON), length(LAT), length(DEPTH)) || error("tmask_r1x1.nc: unexpected size $(size(m))")
        return circshift(m .== 1, (-SHIFT, 0, 0))
    end
end

const OCEAN = read_ocean()

# One monthly field (lon, lat, depth) as Float32, NaN where missing or masked
function read_month(src, y, m)
    NCDataset(monthly_file(src, y, m)) do ds
        v = ds[src]
        A = v.var[:, :, :, 1]
        fv = v.attrib["_FillValue"]
        A = circshift(A, (-SHIFT, 0, 0))
        return Float32.(ifelse.(OCEAN .& (A .!= fv), A, NaN32))
    end
end

function check_files()
    missing_files = [f for v in VARS, y in YEARS, m in 1:12 for f in (monthly_file(v.src, y, m),) if !isfile(f)]
    isempty(missing_files) || error("missing ORAS5 files, e.g. $(first(missing_files))")
end

function define_file(path, extra; title)
    ds = NCDataset(path, "c")
    defVar(ds, "lon", LON, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", LAT, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "depth", DEPTH, ("depth",);
           attrib=["units" => "m", "positive" => "down", "long_name" => "depth of the T levels"])
    if extra == "month"
        defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
    else
        defVar(ds, "time", Int32.(YEARS), ("time",);
               attrib=["units" => "year", "long_name" => "calendar year (mean over January-December)"])
    end
    for (name, v) in pairs(VARS)
        defVar(ds, String(name), Float32, ("lon", "lat", "depth", extra); fillvalue=NaN32, deflatelevel=1,
               chunksizes=[length(LON), length(LAT), 15, 1],
               attrib=["units" => v.units, "long_name" => v.long_name])
    end
    ds.attrib["title"] = title
    ds.attrib["references"] = "Zuo, H., Balmaseda, M. A., Tietsche, S., Mogensen, K., and Mayer, M.: " *
        "The ECMWF operational ensemble reanalysis-analysis system for ocean and sea ice: " *
        "a description of the system and assessment, Ocean Sci., 15, 779-808, 2019"
    ds.attrib["doi"] = "10.5194/os-15-779-2019"
    ds.attrib["license"] = "CC BY 4.0 (Copernicus licence), ORAS5 by ECMWF / Copernicus Climate Change Service"
    ds.attrib["comment"] = "ORAS5 ensemble member $MEMBER, monthly means regridded by ECMWF from ORCA025 " *
        "to 1x1 degrees (r1x1, ICDC copy on the DKRZ pool), land-sea mask tmask_r1x1 applied; " *
        "land and sea floor are missing"
    foreach(((k, val),) -> ds.attrib[k] = val, provenance_attrib("ocean"))
    return ds
end

function main()
    check_files()
    mkpath(OUTDIR)
    days(y, m) = Float32(Dates.daysinmonth(y, m))

    annual_path = joinpath(OUTDIR, "ORAS5_annual_$(first(YEARS))-$(last(YEARS)).nc")
    annual = define_file(annual_path, "time";
        title="ORAS5 ocean reanalysis, annual means $(first(YEARS))-$(last(YEARS))")
    sz = (length(LON), length(LAT), length(DEPTH))
    clim = Dict((p, name) => zeros(Float64, sz..., 12) for p in CLIMATOLOGIES for name in keys(VARS))
    try
        for (k, y) in enumerate(YEARS), (name, v) in pairs(VARS)
            t0 = time()
            ann = zeros(Float64, sz)
            for m in 1:12
                A = read_month(v.src, y, m)
                ann .+= days(y, m) .* A
                for p in CLIMATOLOGIES
                    y in p && (clim[(p, name)][:, :, :, m] .+= A)
                end
            end
            annual[String(name)][:, :, :, k] = Float32.(ann ./ Dates.daysinyear(y))
            println("$y $name ($(round(time() - t0; digits=1)) s)")
            flush(stdout)
        end
    finally
        close(annual)
    end
    println("Wrote $annual_path")

    for p in CLIMATOLOGIES
        path = joinpath(OUTDIR, "ORAS5_$(first(p))-$(last(p)).nc")
        ds = define_file(path, "month"; title="ORAS5 ocean reanalysis, monthly climatology $(first(p))-$(last(p))")
        try
            for name in keys(VARS)
                ds[String(name)][:, :, :, :] = Float32.(clim[(p, name)] ./ length(p))
            end
        finally
            close(ds)
        end
        println("Wrote $path")
    end
end

main()
