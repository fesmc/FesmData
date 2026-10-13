# Prepare the PaleoGrIS 1.0 isochrone buffers (Leger et al., 2024) for remapping: the age of
# deglaciation and its uncertainty on the 1 km grid of the buffer products (EPSG:3413) as
# one prepared NetCDF file, $FESMDATA_PREPARED/Leger2024_PaleoGris/Leger2024_PaleoGrIS.nc,
# with age_deglac and age_deglac_err.
#
# Usage:
#     julia --project=Leger2024_PaleoGris Leger2024_PaleoGris/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_PREPARED/Leger2024_PaleoGris/Leger2024_PaleoGrIS.nc Greenland

using NCDatasets
import Proj

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "leger2024_paleogris"
const PROJ = "+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
const DX = 1000.0       # m

dir = joinpath(download_dataset(manifest(), KEY), "Supplementary_data", "PaleoGrIS_1.0_isochrones", "NetCDF_format",
               "isochrone_buffers")
file(kind) = joinpath(dir, "PaleoGrIS_1.0_isochrone_buffers_1km_$(kind).nc")

# The coordinates are stored as Float32 (about 0.1 m precision): rebuilt from the mean
# offset of the 1 km spacing. Fields are (x, y), 0 outside the buffers.
function read_buffer(kind)
    NCDataset(file(kind)) do ds
        v = ds["isochrone"]
        dimnames(v) == ("x", "y") || error("$(file(kind)): unexpected dimensions $(dimnames(v))")
        xs, ys = Float64.(ds["x"].var[:]), Float64.(ds["y"].var[:])
        x = sum(xs .- DX .* (0:length(xs)-1)) / length(xs) .+ DX .* (0:length(xs)-1)
        y = sum(ys .- DX .* (0:length(ys)-1)) / length(ys) .+ DX .* (0:length(ys)-1)
        maximum(abs, x .- xs) < 1 && maximum(abs, y .- ys) < 1 || error("$(file(kind)): not a 1 km grid")
        # The orientation of the grid, checked against the latitudes of the file
        lat = ds["lat"].var[:, :]
        trans = Proj.Transformation(PROJ, "EPSG:4326"; always_xy=true)
        for (i, j) in ((1, 1), (length(x), 1), (1, length(y)), (length(x) ÷ 2, length(y) ÷ 3))
            abs(trans((x[i], y[j]))[2] - lat[i, j]) < 0.01 || error("$(file(kind)): coordinates do not match the latitudes")
        end
        A = Float32.(v.var[:, :])
        A[A .== 0] .= NaN32
        return x, y, A
    end
end

x, y, age = read_buffer("age")
x2, y2, err = read_buffer("error")
(x2 == x && y2 == y) || error("the age and error grids differ")
isequal(isnan.(age), isnan.(err)) || error("the age and error buffers cover different areas")

path = joinpath(prepared_dir("Leger2024_PaleoGris"), "Leger2024_PaleoGrIS.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic", "proj_params" => PROJ,
                                             "epsg_code" => "EPSG:3413"])
    defVar(ds, "age_deglac", age, ("x", "y"); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "years ago", "long_name" => "time of deglaciation (years before 1950 CE)",
                   "grid_mapping" => "crs"])
    defVar(ds, "age_deglac_err", err, ("x", "y"); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "years", "long_name" => "uncertainty of the time of deglaciation", "grid_mapping" => "crs"])
    ds.attrib["title"] = "PaleoGrIS 1.0: time of deglaciation of the Greenland Ice Sheet, isochrone buffers at 1 km " *
                         "(Leger et al., 2024)"
    ds.attrib["references"] = "Leger, T. P. M., Clark, C. D., Huynh, C., Jones, S., Ely, J. C., Bradley, S. L., " *
                              "Diemont, C. and Hughes, A. L. C.: A Greenland-wide empirical reconstruction of paleo " *
                              "ice sheet retreat informed by ice extent markers: PaleoGrIS version 1.0, Clim. Past, " *
                              "20, 701-755, 2024, doi:10.5194/cp-20-701-2024; data: Mendeley Data, " *
                              "doi:10.17632/nh57cz4gys.1"
    ds.attrib["doi"] = "10.17632/nh57cz4gys.1"
    ds.attrib["license"] = "CC BY 4.0 (Mendeley Data)"
    ds.attrib["comment"] = "From PaleoGrIS_1.0_isochrone_buffers_1km_{age,error}.nc; cells outside the buffers (0 in " *
                           "the source: the present ice sheet, and the land and ocean beyond the reconstruction) are missing"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
end
println("Wrote $path")
