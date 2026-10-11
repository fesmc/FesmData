# Prepare PaleoMIST 1.0 (Gowan et al., 2021) for remapping: the global 0.25° grids of the
# reconstruction (80-0 ka every 2.5 kyr), one prepared NetCDF file per scenario of the
# North American ice sheet in MIS 3, in $FESMDATA_WORK/prepared/Gowan2021_PaleoMIST1.0/:
# Gowan2021_PaleoMIST.nc (minimal scenario) and Gowan2021_PaleoMIST_max.nc (maximal
# scenario, "a1"), with z_topo, z_bed, H_ice, dz_sl and f_ice. f_ice, the ice area fraction
# of each 0.25° cell, is derived from the ice thickness of the 5 km regional
# reconstructions (supersampled).
#
# Usage:
#     julia --project=Gowan2021_PaleoMIST1.0 Gowan2021_PaleoMIST1.0/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Gowan2021_PaleoMIST1.0/Gowan2021_PaleoMIST.nc all

using NCDatasets
import Proj

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "gowan2021_paleomist"

# Samples per side of each 0.25° cell for f_ice (0.05°, about the 5 km of the regional grids)
const NSUB = 5

# Scenarios: prepared file, suffix of the files of the original data ("" or "_a1"),
# description
const SCENARIOS = [
    ("Gowan2021_PaleoMIST.nc", "", "minimal MIS 3 scenario for North America (ice-free Hudson Bay at times)"),
    ("Gowan2021_PaleoMIST_max.nc", "_a1", "maximal MIS 3 scenario for North America (ice over Hudson Bay throughout MIS 3)"),
]

# name => (source field, units, long_name)
const FIELDS = [
    "z_topo" => ("paleo_topography", "m",
                 "topography (ice surface on the ice sheets, bed elsewhere, sea floor in the ocean), relative to sea level at the time"),
    "z_bed" => ("base_topography", "m", "bed elevation (deformed base topography without ice), relative to sea level at the time"),
    "H_ice" => ("ice_thickness", "m", "grounded ice thickness"),
    "dz_sl" => ("sea_level", "m", "sea-level change from present (sea-level equation, without topography)"),
]

# Projections of the regional grids (ice_reconstruction_files/<region>/projection_info.sh,
# GMT): Lambert azimuthal equal-area grids with x and y in m from the lower-left corner of
# the region (lon, lat), and a polar stereographic grid centred on the South Pole.
const REGIONS = [
    ("North_America", "+proj=laea +lat_0=60 +lon_0=-94 +datum=WGS84 +units=m", (-135.0, 25.0)),
    ("Eurasia", "+proj=laea +lat_0=90 +lon_0=0 +datum=WGS84 +units=m", (-12.0, 47.0)),
    ("Patagonia", "+proj=laea +lat_0=-45 +lon_0=-73 +datum=WGS84 +units=m", (-80.0, -57.0)),
    ("Antarctica", "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +datum=WGS84 +units=m", nothing),
]

"""
    read_global(path) -> (lon, lat, ages, data)

The global grids: gridline registered (lon -180:0.25:180, lat -90:0.25:90), time in years
relative to 1950 (-80000:2500:0), fields (lon, lat, time). The column at 180° repeats the
one at -180° and is dropped. The grids are smoothed (Gaussian filter of 25 km) by the
author, which leaves small negative thicknesses next to the ice margins: set to 0.
"""
function read_global(path)
    NCDataset(path) do ds
        lon, lat, t = Float64.(ds["lon"].var[:]), Float64.(ds["lat"].var[:]), Float64.(ds["time"].var[:])
        (lon[1] == -180 && lon[end] == 180) || error("$path: unexpected longitudes $(lon[1]):$(lon[end])")
        nx = length(lon) - 1
        data = Dict{String,Array{Float32,3}}()
        for (name, (srcname, _, _)) in FIELDS
            v = ds[srcname]
            dimnames(v) == ("lon", "lat", "time") || error("$path: unexpected dimensions of $srcname")
            A = Float32.(v.var[1:nx, :, :])
            any(isnan, A) && error("$path: missing values in $srcname")
            data[name] = A
        end
        data["H_ice"] .= max.(data["H_ice"], 0f0)
        return lon[1:nx], lat, 0.0 .- t, data          # years before 1950, oldest first (no -0.0)
    end
end

"Cell centres x, y (m, ascending) of a regional grid."
regional_grid(dir) = NCDataset(ds -> (Float64.(ds["x"].var[:]), Float64.(ds["y"].var[:])), joinpath(dir, "thickness", "0.nc"))

"""
Indices (into the regional grid in `dir`, 0 outside it) of the NSUB x NSUB samples of
every global cell: a matrix (NSUB^2, nx * ny).
"""
function sample_index(dir, proj, corner, lon::Vector{Float64}, lat::Vector{Float64})
    nx, ny = length(lon), length(lat)
    x, y = regional_grid(dir)
    dx, dy = x[2] - x[1], y[2] - y[1]
    trans = Proj.Transformation("EPSG:4326", proj; always_xy=true)
    x0, y0 = corner === nothing ? (0.0, 0.0) : trans(corner)
    off = ((1:NSUB) .- 0.5) ./ NSUB .- 0.5            # sample offsets in cells
    idx = zeros(Int32, NSUB^2, nx * ny)
    for j in 1:ny
        for i in 1:nx
            c = i + (j - 1) * nx
            for (b, (a, s)) in enumerate(Iterators.product(off, off))
                la = clamp(lat[j] + 0.25 * s, -90, 90)
                px, py = trans((lon[i] + 0.25 * a, la))
                # Grid indices (not finite or huge far from the region, e.g. at the antipode)
                fx = (px - x0 - x[1]) / dx + 1
                fy = (py - y0 - y[1]) / dy + 1
                if 0.5 <= fx < length(x) + 0.5 && 0.5 <= fy < length(y) + 0.5
                    idx[b, c] = round(Int, fx) + (round(Int, fy) - 1) * length(x)
                end
            end
        end
    end
    return idx
end

"Set the samples (of index `idx`) where the thickness `H` is positive."
function mark_ice!(ice::BitMatrix, idx::Matrix{Int32}, H::AbstractMatrix)
    for c in axes(idx, 2), b in axes(idx, 1)
        n = idx[b, c]
        n > 0 && H[n] > 0 && (ice[b, c] = true)
    end
    return ice
end

"""
Ice area fraction (nx, ny, nt): the fraction of the samples of each cell with ice
(thickness > 0) in any of the regional reconstructions (folders `dirs`).
"""
function ice_fraction(dirs, samples, ages, nx, ny)
    f = zeros(Float32, nx, ny, length(ages))
    for (k, age) in enumerate(ages)
        ice = falses(NSUB^2, nx * ny)
        for (dir, idx) in zip(dirs, samples)
            file = joinpath(dir, "thickness", "$(round(Int, age)).nc")
            H = NCDataset(file) do ds
                dimnames(ds["z"]) == ("x", "y") || error("unexpected dimensions in $file")
                ds["z"].var[:, :]
            end
            mark_ice!(ice, idx, H)
        end
        f[:, :, k] = reshape(sum(ice; dims=1) ./ NSUB^2, nx, ny)
    end
    return f
end

function prepare_scenario(root, file, suffix, description)
    src = joinpath(root, "global_grid", "reconstruction$(suffix)_0.25_degree.nc")
    lon, lat, ages, data = read_global(src)
    nx, ny = length(lon), length(lat)
    dirs = [joinpath(root, "ice_reconstruction_files", region * suffix) for (region, _, _) in REGIONS]
    samples = [sample_index(d, proj, corner, lon, lat) for (d, (_, proj, corner)) in zip(dirs, REGIONS)]
    f_ice = ice_fraction(dirs, samples, ages, nx, ny)

    path = joinpath(prepared_dir("Gowan2021_PaleoMIST1.0"), file)
    mkpath(dirname(path))
    rm(path; force=true)
    NCDataset(path, "c") do ds
        defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
        defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
        defVar(ds, "time", ages, ("time",); attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)"])
        for (name, (_, units, long_name)) in FIELDS
            defVar(ds, name, data[name], ("lon", "lat", "time"); deflatelevel=1,
                   attrib=["units" => units, "long_name" => long_name])
        end
        defVar(ds, "f_ice", f_ice, ("lon", "lat", "time"); deflatelevel=1,
               attrib=["units" => "1", "long_name" => "ice area fraction",
                       "comment" => "fraction of $(NSUB)x$(NSUB) samples per cell with ice (thickness > 0) in the 5 km " *
                                    "regional reconstructions (ice_reconstruction_files/<region>$suffix)"])
        ds.attrib["title"] = "PaleoMIST 1.0: global ice sheet reconstruction for the past 80 000 years " *
                             "(Gowan et al., 2021), $description"
        ds.attrib["references"] = "Gowan, E. J., Zhang, X., Khosravi, S., Rovere, A., Stocchi, P., Hughes, A. L. C., " *
                                  "Gyllencreutz, R., Mangerud, J., Svendsen, J.-I. and Lohmann, G.: A new global ice " *
                                  "sheet reconstruction for the past 80 000 years, Nat. Commun., 12, 1199, 2021, " *
                                  "doi:10.1038/s41467-021-21469-w; data: Gowan, E. J. et al.: Global ice sheet " *
                                  "reconstruction for the past 80000 years, PANGAEA, doi:10.1594/PANGAEA.905800, 2021"
        ds.attrib["doi"] = "10.1594/PANGAEA.905800"
        ds.attrib["license"] = "CC BY 4.0 (PANGAEA)"
        ds.attrib["comment"] = "Fields from global_grid/$(basename(src)) ($description; smoothed by the author " *
                               "with a 25 km Gaussian filter), negative ice thickness set to 0; f_ice from the " *
                               "unsmoothed 5 km regional grids"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
    end
    println("Wrote $path")
end

root = joinpath(download_dataset(manifest(), KEY), "ice_reconstruction")
for (file, suffix, description) in SCENARIOS
    prepare_scenario(root, file, suffix, description)
end
