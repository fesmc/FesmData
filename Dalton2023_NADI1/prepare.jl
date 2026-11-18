# Prepare NADI-1, the North American Deglacial Isochrones of Dalton et al. (2023), for
# remapping: the optimal, minimum and maximum ice extents of the Laurentide, Cordilleran and
# Innuitian ice sheets every 500 years from 25 to 1 ka (calendar), rasterized as ice area
# fractions on the 2 km grid of the North domain (../shared/outlines.jl), in one prepared
# NetCDF file, $FESMDATA_PREPARED/Dalton2023_NADI1/Dalton2023_NADI1.nc, with f_ice (optimal),
# f_ice_min and f_ice_max on (x, y, time).
#
# Usage:
#     julia -t 16 --project=Dalton2023_NADI1 Dalton2023_NADI1/prepare.jl
#     julia fesmdata.jl remap IceHistory NADI1

using FesmUtils
using NCDatasets
import ArchGDAL as AG
import GeoInterface as GI
import Proj

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "outlines.jl"))

const KEY = "dalton2023_nadi1"
const AGES = 25.0:-0.5:1.0             # ka (calendar, before 1950 CE), the 49 time steps, oldest first

# Fields and the label of their shapefiles, <age>ka_cal_<label>_NADI-1_Dalton_etal_QSR.shp
const ESTIMATES = [("f_ice", "OPTIMAL", "optimal"), ("f_ice_min", "MIN", "minimum"), ("f_ice_max", "MAX", "maximum")]

dir = joinpath(download_dataset(manifest(), KEY), "NADI-1 shapefiles Dalton et al. QSR")
agestr(a) = isinteger(a) ? string(Int(a)) : string(a)          # 25, 24.5, ..., 1 as in the file names
function shapefile(age, label)
    p = joinpath(dir, "$(agestr(age))ka_cal_$(label)_NADI-1_Dalton_etal_QSR.shp")
    isfile(p) ? p : error("missing $p")
end
g = north_outline_grid("NADI1")

path = joinpath(prepared_dir("Dalton2023_NADI1"), "Dalton2023_NADI1.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "x", g.xc, ("x",); attrib=["units" => "km", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", g.yc, ("y",); attrib=["units" => "km", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "time", Float64[1000 * a for a in AGES], ("time",);
           attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)",
                   "comment" => "the time steps of NADI-1 (calendar ka), every 500 years"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic", "proj_params" => NORTH_PROJ])
    for (name, _, est) in ESTIMATES
        defVar(ds, name, Float32, ("x", "y", "time"); deflatelevel=1, shuffle=true, chunksizes=(1000, 1000, 1),
               attrib=["units" => "1", "long_name" => "ice area fraction, $est ice-sheet extent", "grid_mapping" => "crs"])
    end
    ds.attrib["title"] = "NADI-1: North American Deglacial Isochrones, 25 to 1 ka (Dalton et al., 2023)"
    ds.attrib["references"] = "Dalton, A. S. et al.: Deglaciation of the north American ice sheet complex in calendar " *
                              "years based on a comprehensive database of chronological data: NADI-1, Quat. Sci. Rev., " *
                              "321, 108345, 2023, doi:10.1016/j.quascirev.2023.108345; data: Zenodo, doi:10.5281/zenodo.8161764"
    ds.attrib["doi"] = "10.5281/zenodo.8161764"
    ds.attrib["license"] = "CC BY 4.0 (Zenodo)"
    ds.attrib["comment"] = "Shapefiles <age>ka_cal_{OPTIMAL,MIN,MAX} rasterized as the fraction of 8x8 samples per cell " *
                           "inside the outlines (all polygons are ice)"
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
