# Prepare ANTASed (Baranov et al., 2021), the sediment thickness of Antarctica, for
# remapping: its 0.1° grid of an azimuthal equidistant projection centred on the South
# Pole as a prepared NetCDF file, $FESMDATA_WORK/prepared/Baranov2021_sed/Baranov2021_ANTASed.nc.
#
# Usage:
#     julia --project=Baranov2021_sed Baranov2021_sed/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Baranov2021_sed/Baranov2021_ANTASed.nc Antarctica

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

dir = download_dataset(manifest(), "antased")    # downloads it if missing
input = joinpath(dir, "0.1_lim_b.dat")

# 0.1_lim_b.dat: x, y, sediment thickness (km), one line per grid point on the continent
# (the grid is limited to the continent; missing elsewhere). x and y are coordinates of
# an azimuthal equidistant projection centred on the South Pole, in degrees of arc from
# the pole (x towards 90°E, y towards 0°E), on a 0.1° grid. They are converted to m on a
# sphere of radius R, the same as in the PROJ string, so the positions do not depend on R.
const R = 6371000.0
const PROJ = "+proj=aeqd +lat_0=-90 +lon_0=0 +x_0=0 +y_0=0 +R=$(Int(R)) +units=m"
const STEP = 0.1

a = readdlm(input, Float64)
size(a, 2) == 3 || error("$input: expected 3 columns, got $(size(a, 2))")
i = round.(Int, a[:, 1] ./ STEP)
j = round.(Int, a[:, 2] ./ STEP)
(all(abs.(a[:, 1] ./ STEP .- i) .< 1e-6) && all(abs.(a[:, 2] ./ STEP .- j) .< 1e-6)) ||
    error("$input: coordinates are not on a $(STEP)° grid")
length(unique(zip(i, j))) == length(i) || error("$input: duplicate grid points")
irange, jrange = minimum(i):maximum(i), minimum(j):maximum(j)
z = fill(NaN32, length(irange), length(jrange))
for k in eachindex(i)
    z[i[k]-first(irange)+1, j[k]-first(jrange)+1] = Float32(1000 * a[k, 3])    # km => m
end
minimum(filter(!isnan, z)) >= 0 || error("$input: negative sediment thickness")
x = collect(irange) .* (STEP * π / 180 * R)
y = collect(jrange) .* (STEP * π / 180 * R)

path = joinpath(prepared_dir("Baranov2021_sed"), "Baranov2021_ANTASed.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "azimuthal_equidistant",
                                             "latitude_of_projection_origin" => -90.0,
                                             "longitude_of_projection_origin" => 0.0,
                                             "false_easting" => 0.0, "false_northing" => 0.0,
                                             "earth_radius" => R, "proj_params" => PROJ])
    defVar(ds, "z_sed", z, ("x", "y"); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "m", "long_name" => "sediment thickness", "grid_mapping" => "crs",
                   "comment" => "Antarctic continent (grounded ice and ice shelves) only, missing elsewhere"])
    ds.attrib["title"] = "ANTASed: sediment thickness of Antarctica (Baranov et al., 2021)"
    ds.attrib["references"] = "Baranov, A., Morelli, A. and Chuvaev, A.: ANTASed - An updated sediment " *
                              "model for Antarctica, Front. Earth Sci., 9, 722699, " *
                              "doi:10.3389/feart.2021.722699, 2021; data: " *
                              "https://www.itpz-ran.ru/en/activity/current-projects/antased-a-new-sediment-model-for-antarctica/"
    ds.attrib["doi"] = "10.3389/feart.2021.722699"
    ds.attrib["license"] = "No licence stated for the data file (IEPT RAS web site); the article is CC BY 4.0"
    ds.attrib["comment"] = "0.1_lim_b.dat: x and y in degrees of arc of an azimuthal equidistant " *
                           "projection centred on the South Pole, converted to m on a sphere of radius $(Int(R)) m; " *
                           "thickness converted from km to m"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("sediment"))
end
println("Wrote $path")
