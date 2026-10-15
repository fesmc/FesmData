# Prepare the CLIMBER-3α present-day and LGM climatologies of Montoya and Levermann
# (2008) for remapping (github.com/fesmc/Montoya2008-CLIMBER3a, datamanifest key
# montoya2008_climber3a): for each simulation, the atmosphere fields with the surface
# height and land fraction of the atmosphere model, and the ocean potential temperature,
# each on its own model grid:
#     $FESMDATA_PREPARED/Montoya2008_climber3a/CLIMBER3a_<simulation>.nc
#     $FESMDATA_PREPARED/Montoya2008_climber3a/CLIMBER3a_<simulation>_ocean.nc
#
# Usage:
#     julia --project=Montoya2008_climber3a Montoya2008_climber3a/prepare.jl
#     julia fesmdata.jl remap Paleoclimate

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "montoya2008_climber3a"

# Simulation => (atmosphere file, surface height of horo.cdf, ocean file, years averaged)
const SIMULATIONS = [
    "present" => ("present.cdf", "HORO_PRESENT", "lgm_present_ocean.cdf",
                  "atmosphere: model year 13651; ocean: model year 13652"),
    "lgm_1p7weak" => ("lgm_1p7weak.cdf", "HORO_LGM", "lgm_1p7weak_ocean.cdf",
                      "atmosphere: model years 4701-4800; ocean: model year 4798-4799"),
    "lgm_1p7strong" => ("lgm_1p7strong.cdf", "HORO_LGM", "lgm_1p7strong_ocean.cdf",
                        "atmosphere: model years 7886-7985; ocean: model year 7992-7993"),
]

const TITLES = Dict(
    "present" => "present-day control",
    "lgm_1p7weak" => "Last Glacial Maximum, wind stress x 1.7, weak AMOC state",
    "lgm_1p7strong" => "Last Glacial Maximum, wind stress x 1.7, strong AMOC state",
)

# Prepared field => (original field, units, long name)
const FIELDS = [
    "t2m_ann" => ("TS_ANN", "degC", "near-surface air temperature, annual mean"),
    "t2m_jja" => ("TS_JJA", "degC", "near-surface air temperature, JJA mean"),
    "pr_ann" => ("PRC_ANN", "mm d-1", "precipitation (water equivalent), annual mean"),
]

const REFERENCES =
    "Montoya, M. and Levermann, A.: Surface wind-stress threshold for glacial Atlantic " *
    "overturning, Geophys. Res. Lett., 35, L03608, 2008, doi:10.1029/2007GL032560; " *
    "Montoya, M., Griesel, A., Levermann, A., Mignot, J., Hofmann, M., Ganopolski, A., and " *
    "Rahmstorf, S.: The earth system model of intermediate complexity CLIMBER-3alpha. Part I: " *
    "description and performance for present-day conditions, Clim. Dyn., 25, 237-263, 2005, " *
    "doi:10.1007/s00382-005-0044-1"

const LICENSE = "CC BY 4.0 (https://github.com/fesmc/Montoya2008-CLIMBER3a)"

_float(A) = Float32.(coalesce.(A, NaN32))

"""
    lon180(lon) -> (lon, ix)

Longitudes of 0:360 shifted to -180:180 and sorted, with the permutation `ix` of the
columns.
"""
function lon180(lon)
    l = mod.(Float64.(lon) .+ 180, 360) .- 180
    ix = sortperm(l)
    return l[ix], ix
end

function write_lonlat(ds, lon, lat)
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", Float64.(lat), ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
end

function write_attrib(ds, simulation, kind, years, original_files)
    ds.attrib["title"] = "CLIMBER-3alpha $kind climatology, $(TITLES[simulation]) (Montoya and Levermann, 2008)"
    ds.attrib["simulation"] = simulation
    ds.attrib["years"] = years
    ds.attrib["references"] = REFERENCES
    ds.attrib["doi"] = "10.1029/2007GL032560"
    ds.attrib["license"] = LICENSE
    ds.attrib["original_files"] = original_files
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("paleoclimate"))
end

# Atmosphere grid (22.5° x 7.5°): the fields, the surface height of the atmosphere model
# (0 over the ocean, at least 1 m over land) and the land fraction (1 where land)
function prepare_atmosphere(dir, outdir, simulation, file, horo, years)
    path = joinpath(outdir, "CLIMBER3a_$simulation.nc")
    zs = NCDataset(joinpath(dir, "atmosphere", "horo.cdf")) do src
        _float(src[horo][:, :, 1])
    end
    NCDataset(joinpath(dir, "atmosphere", file)) do src
        lon, ix = lon180(src["XT_I"][:])
        lat = src["YT_J"][:]
        size(zs) == (length(lon), length(lat)) || error("horo.cdf is not on the grid of $file")
        NCDataset(path, "c") do ds
            write_lonlat(ds, lon, lat)
            for (name, (var, units, long_name)) in FIELDS
                defVar(ds, name, _float(src[var][:, :])[ix, :], ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
                       attrib=["units" => units, "long_name" => long_name])
            end
            defVar(ds, "z_srf", zs[ix, :], ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => "m", "long_name" => "surface height of the atmosphere model ($horo)"])
            defVar(ds, "f_land", Float32.(zs[ix, :] .> 0), ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => "1", "long_name" => "land fraction (1 where the surface height > 0)"])
            write_attrib(ds, simulation, "atmosphere", years, "atmosphere/$file, atmosphere/horo.cdf ($horo)")
        end
    end
    println("Wrote $path")
end

# Ocean grid (3.75° x 3.75°, 24 levels): potential temperature, missing over land and
# below the sea floor
function prepare_ocean(dir, outdir, simulation, file, years)
    path = joinpath(outdir, "CLIMBER3a_$(simulation)_ocean.nc")
    NCDataset(joinpath(dir, "ocean", file)) do src
        lon, ix = lon180(src["XT_I"][:])
        lat = src["YT_J"][:]
        depth = Float32.(src["ZT_K"][:])
        NCDataset(path, "c") do ds
            write_lonlat(ds, lon, lat)
            defVar(ds, "depth", depth, ("depth",);
                   attrib=["units" => "m", "positive" => "down", "long_name" => "depth of the T levels"])
            defVar(ds, "to", _float(src["TEMP"][:, :, :])[ix, :, :], ("lon", "lat", "depth"); fillvalue=NaN32,
                   deflatelevel=1, attrib=["units" => "degC", "long_name" => "sea water potential temperature, annual mean"])
            write_attrib(ds, simulation, "ocean", years, "ocean/$file")
        end
    end
    println("Wrote $path")
end

db = manifest()
dir = get_dataset_path(db, KEY)
isdir(dir) || (dir = download_dataset(db, KEY))
# The GitHub archive holds one folder, Montoya2008-CLIMBER3a-<version>
isdir(joinpath(dir, "atmosphere")) || (dir = only(filter(isdir, readdir(dir; join=true))))

outdir = prepared_dir("Montoya2008_climber3a")
mkpath(outdir)
for (simulation, (file, horo, ocean_file, years)) in SIMULATIONS
    prepare_atmosphere(dir, outdir, simulation, file, horo, years)
    prepare_ocean(dir, outdir, simulation, ocean_file, years)
end
