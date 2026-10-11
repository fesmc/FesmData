# Prepare the Antarctic mantle viscosity and lithosphere thickness of Hazzard et al.
# (2023) for remapping: the mean and standard deviation of the posterior ensemble
# inferred from ANT-20 (summary_grids.zip of OSF project f4ntr, datamanifest key
# hazzard2023_visc) on its 0.5° lon-lat grid, as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/Hazzard2023_visc/Hazzard2023_visc.nc, with log10_visc and
# log10_visc_sd (on depth, 75-400 km) and z_litho and z_litho_sd.
#
# Usage:
#     julia --project=Hazzard2023_visc Hazzard2023_visc/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Hazzard2023_visc/Hazzard2023_visc.nc Antarctica

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "hazzard2023_visc"
const DEPTHS_KM = 75:25:400

db = manifest()
dir = get_dataset_path(db, KEY)
isdir(dir) || (dir = download_dataset(db, KEY))
grids = joinpath(dir, "summary_grids")

# GMT grids (gridline registered), z (x, y) in Julia order, x = lon 0:0.5:360 (360
# repeats 0, dropped; shifted to -180:180), y = lat ascending
function read_grd(path)
    NCDataset(path) do ds
        lon, lat = Float64.(ds["x"][:]), Float64.(ds["y"][:])
        z = Float32.(coalesce.(ds["z"][:, :], NaN32))
        (lon[1] == 0 && lon[end] == 360) || error("$path: longitudes $(lon[1]):$(lon[end]), expected 0:360")
        isequal(z[1, :], z[end, :]) || error("$path: columns at 0° and 360° differ")
        issorted(lat) || error("$path: latitudes not ascending")
        lon, z = lon[1:end-1], z[1:end-1, :]
        l = mod.(lon .+ 180, 360) .- 180
        ix = sortperm(l)
        return l[ix], lat, z[ix, :]
    end
end

# Viscosity: log10 of the viscosity in Pa s and its standard deviation (log10 units),
# one grid per depth, lat -90:0.5:-45
vgrid(d, s) = joinpath(grids, "viscosity_grids", "$(d)_viscosity_$s.grd")
lon, lat, _ = read_grd(vgrid(first(DEPTHS_KM), "mean"))
visc = Array{Float32}(undef, length(lon), length(lat), length(DEPTHS_KM))
visc_sd = similar(visc)
for (k, d) in enumerate(DEPTHS_KM), (A, s) in ((visc, "mean"), (visc_sd, "std"))
    l, b, z = read_grd(vgrid(d, s))
    (l == lon && b == lat) || error("$(vgrid(d, s)) is not on the grid of the other viscosity grids")
    A[:, :, k] = z
end

# Lithosphere thickness: depth of the 1200 °C isotherm (LAB, km), filtered, on lat
# -90:0.5:-60, put on the viscosity grid (missing north of 60°S)
z_litho = fill(NaN32, length(lon), length(lat))
z_litho_sd = fill(NaN32, length(lon), length(lat))
for (A, s) in ((z_litho, "mean"), (z_litho_sd, "std"))
    l, b, z = read_grd(joinpath(grids, "LAB_depth", "LAB1200_$(s)_filtered.grd"))
    l == lon || error("LAB1200_$(s)_filtered.grd: longitudes differ from the viscosity grids")
    jy = [findfirst(==(v), lat) for v in b]
    any(isnothing, jy) && error("LAB1200_$(s)_filtered.grd: latitudes not on the viscosity grid")
    A[:, jy] = 1f3 .* z
end

path = joinpath(prepared_dir("Hazzard2023_visc"), "Hazzard2023_visc.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "depth", 1e3 .* collect(DEPTHS_KM), ("depth",);
           attrib=["units" => "m", "standard_name" => "depth", "positive" => "down",
                   "long_name" => "depth below sea level"])
    for (name, A, long_name) in (("log10_visc", visc, "log10 of mantle viscosity in Pa s (mean of the posterior ensemble)"),
                                 ("log10_visc_sd", visc_sd, "standard deviation of log10 of mantle viscosity"))
        defVar(ds, name, A, ("lon", "lat", "depth"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "log10(Pa s)", "long_name" => long_name])
    end
    for (name, A, long_name) in (("z_litho", z_litho, "lithosphere thickness (depth of the 1200 degC isotherm, mean)"),
                                 ("z_litho_sd", z_litho_sd, "standard deviation of lithosphere thickness"))
        defVar(ds, name, A, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "m", "long_name" => long_name])
    end
    ds.attrib["title"] = "Antarctic mantle viscosity and lithosphere thickness (Hazzard et al., 2023)"
    ds.attrib["references"] = "Hazzard, J. A. N., Richards, F. D., Goes, S. D. B. and Roberts, G. G.: " *
                              "Probabilistic assessment of Antarctic thermomechanical structure: impacts " *
                              "on ice sheet stability, J. Geophys. Res. Solid Earth, 128, e2023JB026653, 2023"
    ds.attrib["doi"] = "10.1029/2023JB026653"
    ds.attrib["license"] = "No licence stated (OSF project https://osf.io/f4ntr, summary_grids.zip); " *
                           "redistribution of derived products assumed to be allowed"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("solidearth"))
end
println("Wrote $path")
