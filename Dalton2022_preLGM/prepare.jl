# Prepare the pre-LGM reconstructions of the Laurentide and Innuitian ice sheets of Dalton,
# Stokes and Batchelor (2022) for remapping: the best, minimum and maximum ice extents every
# 5000 years from 115 to 25 ka, rasterized as ice area fractions on the 2 km grid of the North
# domain (../shared/outlines.jl), in one prepared NetCDF file,
# $FESMDATA_PREPARED/Dalton2022_preLGM/Dalton2022_PRELGM.nc, with f_ice (best), f_ice_min and
# f_ice_max on (x, y, time).
#
# Usage:
#     julia -t 16 --project=Dalton2022_preLGM Dalton2022_preLGM/prepare.jl
#     julia fesmdata.jl remap IceHistory Dalton2022

using FesmUtils
using NCDatasets
import ArchGDAL as AG
import GeoInterface as GI
import Proj

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "outlines.jl"))

const KEY = "dalton2022_prelgm"
const AGES = 115:-5:25                 # ka (calendar, before 1950 CE), the 19 time slices, oldest first

# Fields and the label of their shapefiles, <age>ka_<label>_North_American_ice_Dalton_et_al_ESR.shp
const ESTIMATES = [("f_ice", "BEST", "best"), ("f_ice_min", "MIN", "minimum"), ("f_ice_max", "MAX", "maximum")]

dir = download_dataset(manifest(), KEY)
function shapefile(age, label)
    p = joinpath(dir, "$(age)ka_$(label)_North_American_ice_Dalton_et_al_ESR.shp")
    isfile(p) ? p : error("missing $p")
end
g = north_outline_grid("Dalton2022")

path = joinpath(prepared_dir("Dalton2022_preLGM"), "Dalton2022_PRELGM.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "x", g.xc, ("x",); attrib=["units" => "km", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", g.yc, ("y",); attrib=["units" => "km", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "time", Float64[1000 * a for a in AGES], ("time",);
           attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)",
                   "comment" => "the time slices of Dalton et al. (2022), every 5 kyr"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic", "proj_params" => NORTH_PROJ])
    for (name, _, est) in ESTIMATES
        defVar(ds, name, Float32, ("x", "y", "time"); deflatelevel=1, shuffle=true, chunksizes=(1000, 1000, 1),
               attrib=["units" => "1", "long_name" => "ice area fraction, $est ice-sheet extent", "grid_mapping" => "crs"])
    end
    ds.attrib["title"] = "Laurentide and Innuitian ice sheets before the LGM, 115 to 25 ka (Dalton et al., 2022)"
    ds.attrib["references"] = "Dalton, A. S., Stokes, C. R. and Batchelor, C. L.: Evolution of the Laurentide and Innuitian " *
                              "ice sheets prior to the Last Glacial Maximum (115 ka to 25 ka), Earth-Sci. Rev., 224, 103875, " *
                              "2022, doi:10.1016/j.earscirev.2021.103875 (supplementary data mmc3)"
    ds.attrib["doi"] = "10.1016/j.earscirev.2021.103875"
    ds.attrib["license"] = "CC BY 4.0 (the article; none stated for the supplementary data)"
    ds.attrib["comment"] = "Shapefiles <age>ka_{BEST,MIN,MAX} rasterized as the fraction of 8x8 samples per cell inside " *
                           "the outlines (all polygons are ice). The Cordilleran ice of the reconstructions is that of " *
                           "Batchelor et al. (2019)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))

    for (k, age) in enumerate(AGES), (name, label, _) in ESTIMATES
        shp = shapefile(age, label)
        polys, st = read_outlines(shp, g)
        F = outline_fraction(g, polys)
        ds[name][:, :, k] = F
        println("$age ka $name: $(basename(shp)), $(st.features) polygons, $(st.rings) rings ($(st.dropped) outside the ",
                "grid, $(st.partly) partly), ice area $(round(outline_area(g, F); digits=2)) million km2 (projected)")
    end
end
println("Wrote $path")
