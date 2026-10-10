# Prepare the Martos et al. (2018) geothermal heat flux of Greenland for remapping: the
# 15 km grid (UTM zone 23N) of the PANGAEA ASCII files (x y z, land points only) as a
# prepared NetCDF file, $FESMDATA_WORK/prepared/Martos2018_ghf/Martos2018_GHF.nc, with
# ghf, ghf_sd, depth_curie and depth_curie_sd.
#
# Usage:
#     julia --project=Martos2018_ghf Martos2018_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Martos2018_ghf/Martos2018_GHF.nc Greenland

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const DX = 15000.0                      # grid spacing (m)
const PROJ = "+proj=utm +zone=23 +datum=WGS84 +units=m +no_defs"

# (name, manifest key, units, long_name)
const FIELDS = [
    ("ghf", "martos2018_ghf", "mW m-2", "geothermal heat flow"),
    ("ghf_sd", "martos2018_ghf_uncertainty", "mW m-2", "uncertainty of geothermal heat flow"),
    ("depth_curie", "martos2018_curie_depth", "km", "Curie depth (positive downwards)"),
    ("depth_curie_sd", "martos2018_curie_depth_uncertainty", "km", "uncertainty of Curie depth"),
]

db = manifest()
data = [readdlm(download_dataset(db, key), Float64) for (_, key, _, _) in FIELDS]  # downloads if missing

# All files list the same points, on a regular 15 km grid
xy = data[1][:, 1:2]
all(d -> d[:, 1:2] == xy, data) || error("the Martos (2018) files do not list the same points")
all(v -> isinteger(v / DX), xy) || error("the Martos (2018) points are not on a $(DX) m grid")
x = collect(minimum(xy[:, 1]):DX:maximum(xy[:, 1]))
y = collect(minimum(xy[:, 2]):DX:maximum(xy[:, 2]))
ii = round.(Int, (xy[:, 1] .- x[1]) ./ DX) .+ 1
jj = round.(Int, (xy[:, 2] .- y[1]) ./ DX) .+ 1
length(unique(zip(ii, jj))) == size(xy, 1) || error("duplicate points in the Martos (2018) files")

path = joinpath(prepared_dir("Martos2018_ghf"), "Martos2018_GHF.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "transverse_mercator",
                                            "utm_zone_number" => Int32(23),
                                            "proj_params" => PROJ])
    for ((name, _, units, long_name), d) in zip(FIELDS, data)
        F = fill(NaN32, length(x), length(y))
        for (k, (i, j)) in enumerate(zip(ii, jj))
            F[i, j] = d[k, 3]
        end
        defVar(ds, name, F, ("x", "y"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => units, "long_name" => long_name, "grid_mapping" => "crs"])
    end
    ds.attrib["title"] = "Geothermal heat flux and Curie depth of Greenland (Martos et al., 2018)"
    ds.attrib["references"] = "Martos, Y. M., Jordan, T. A., Catalán, M., Jordan, T. M., Bamber, J. L. " *
                              "and Vaughan, D. G.: Geothermal heat flux reveals the Iceland hotspot track " *
                              "underneath Greenland, Geophys. Res. Lett., 45, 8214-8222, 2018, " *
                              "doi:10.1029/2018GL078289. Data: Martos, Y. M.: Greenland geothermal heat " *
                              "flux distribution and estimated Curie depths, links to gridded files, " *
                              "PANGAEA, 2018, doi:10.1594/PANGAEA.892973"
    ds.attrib["doi"] = "10.1594/PANGAEA.892973"
    ds.attrib["license"] = "CC BY 3.0 (Creative Commons Attribution 3.0 Unported)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
