# Prepare the topographic correction of geothermal heat flow of Colgan et al. (2021) for
# remapping: the dimensionless relative correction and its uncertainty on the BedMachine grids
# (TopoHeat_<Region>_20210224.nc, GEUS Dataverse, datamanifest keys
# colgan2021_topocorr_antarctica and colgan2021_topocorr_greenland), at their own
# resolution, written to $FESMDATA_WORK/prepared/Colgan2021_topocorr/Colgan2021_topocorr_<ANT|GRL>.nc
# with ghf_corr and ghf_corr_unc.
#
# Usage (about 4 GB of memory):
#     julia --project=Colgan2021_topocorr Colgan2021_topocorr/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Colgan2021_topocorr/Colgan2021_topocorr_GRL.nc Greenland

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

# Region => (manifest key, name, PROJ string, EPSG code). The files give the PROJ string
# as "+init=epsg:<code>" (their CF attributes of Antarctica name another ellipsoid).
const REGIONS = [
    "ANT" => ("colgan2021_topocorr_antarctica", "Antarctica",
              "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs", "EPSG:3031"),
    "GRL" => ("colgan2021_topocorr_greenland", "Greenland",
              "+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs", "EPSG:3413"),
]

"Regular axis (m, Float64) through the Float32 coordinates `c` of the file, with a whole-metre spacing."
function axis(c)
    c = Float64.(c)
    d = round((c[end] - c[1]) / (length(c) - 1))
    ax = round(c[1]) .+ d .* (0:length(c)-1)
    maximum(abs.(ax .- c)) < 1 || error("coordinates are not on a regular $d m grid")
    return collect(ax)
end

for (region, (key, name, proj, epsg)) in REGIONS
    input = download_dataset(manifest(), key)
    path = joinpath(prepared_dir("Colgan2021_topocorr"), "Colgan2021_topocorr_$region.nc")
    mkpath(dirname(path))
    isfile(path) && rm(path)
    NCDataset(input) do src
        NCDataset(path, "c") do ds
            defVar(ds, "x", axis(src["x"][:]), ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
            defVar(ds, "y", axis(src["y"][:]), ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
            gm = src["polar_stereographic"].attrib
            defVar(ds, "polar_stereographic", Int32(0), ();
                   attrib=["grid_mapping_name" => "polar_stereographic",
                           "straight_vertical_longitude_from_pole" => gm["straight_vertical_longitude_from_pole"],
                           "latitude_of_projection_origin" => gm["latitude_of_projection_origin"],
                           "standard_parallel" => gm["standard_parallel"],
                           "false_easting" => 0.0, "false_northing" => 0.0,
                           "semi_major_axis" => 6378137.0, "inverse_flattening" => 298.257223563,
                           "proj_params" => proj, "crs_epsg" => epsg])
            for (v, out, long_name) in (("correction", "ghf_corr",
                                         "relative topographic correction of geothermal heat flow (corrected = (1 + ghf_corr) x heat flow)"),
                                        ("correction_uncertainty", "ghf_corr_unc",
                                         "uncertainty of the relative topographic correction of geothermal heat flow"))
                F = Float32.(nomissing(src[v][:, :], NaN32))     # (x, y)
                defVar(ds, out, F, ("x", "y"); fillvalue=NaN32, deflatelevel=1, shuffle=true,
                       attrib=["units" => "1", "long_name" => long_name, "grid_mapping" => "polar_stereographic"])
                F = nothing
                GC.gc()
            end
            ds.attrib["title"] = "Topographic correction of geothermal heat flow, $name (Colgan et al., 2021)"
            ds.attrib["references"] = "Colgan, W., MacGregor, J. A., Mankoff, K. D., Haagenson, R., Rajaram, H., " *
                                      "Martos, Y. M., Morlighem, M., Fahnestock, M. A. and Kjeldsen, K. K.: " *
                                      "Topographic correction of geothermal heat flux in Greenland and Antarctica, " *
                                      "J. Geophys. Res. Earth Surf., 126, e2020JF005598, 2021, doi:10.1029/2020JF005598; " *
                                      "data: Colgan, W.: Topographic Correction for Geothermal Heat Flow in Greenland " *
                                      "and Antarctica, GEUS Dataverse, V1, 2021, doi:10.22008/FK2/BQGYYG " *
                                      "($(basename(input)))"
            ds.attrib["doi"] = "10.22008/FK2/BQGYYG"
            ds.attrib["license"] = "CC0 1.0"
            ds.attrib["comment"] = "Dimensionless relative correction (Delta G / G, Colgan et al., 2021, Eq. 1), to be applied to any " *
                                   "geothermal heat flow field: corrected heat flow = (1 + ghf_corr) x heat flow. " *
                                   "On the BedMachine grid of $name " *
                                   "($(round(Int, ds["x"][2] - ds["x"][1])) m)"
            foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
        end
    end
    println("Wrote $path")
end
