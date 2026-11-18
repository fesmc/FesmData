# Prepare the ice-margin chronology of the North American Ice Sheet Complex of Dalton et al.
# (2020) for remapping: the ice extent of its 36 isochrones (22.1 to 0.91 cal ka), rasterized
# as ice area fractions on the 2 km grid of the North domain (../shared/outlines.jl), in one
# prepared NetCDF file, $FESMDATA_PREPARED/Dalton2020_isochrones/Dalton2020_ISOCHRONES.nc,
# with f_ice on (x, y, time).
#
# Usage:
#     julia -t 16 --project=Dalton2020_isochrones Dalton2020_isochrones/prepare.jl
#     julia fesmdata.jl remap IceHistory Dalton2020

using FesmUtils
using NCDatasets
import ArchGDAL as AG
import GeoInterface as GI
import Proj

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "outlines.jl"))

const KEY = "dalton2020_isochrones"

# The isochrones: one shapefile each, <14C age>ka_<calibrated age>cal_Dalton_et_al_2020_QSR.shp
# (ages in thousands of years before 1950 CE), ice polygons (SYMB = ICE; the file of 0.91 cal
# ka has no attribute SYMB). Oldest first.
function isochrones(dir)
    out = Tuple{String,Float64,Float64}[]
    for f in readdir(dir)
        m = match(r"^([0-9.]+)ka_([0-9.]+)cal_Dalton_et_al_2020_QSR\.shp$", f)
        m === nothing && continue
        push!(out, (joinpath(dir, f), 1000 * parse(Float64, m[1]), 1000 * parse(Float64, m[2])))
    end
    length(out) == 36 || error("$dir: $(length(out)) isochrones, expected 36")
    return sort(out; by=s -> -s[3])
end

# Only the polygons of ice (all of them in the files of 2020)
function is_ice(f)
    k = AG.findfieldindex(f, "SYMB")
    (k === nothing || k < 0) && return true
    return AG.getfield(f, k) == "ICE"
end

dir = download_dataset(manifest(), KEY)
slices = isochrones(dir)
g = north_outline_grid("Dalton2020")
nt = length(slices)

path = joinpath(prepared_dir("Dalton2020_isochrones"), "Dalton2020_ISOCHRONES.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "x", g.xc, ("x",); attrib=["units" => "km", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", g.yc, ("y",); attrib=["units" => "km", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "time", Float64[round(c) for (_, _, c) in slices], ("time",);
           attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)",
                   "comment" => "calibrated age of each isochrone, as given by Dalton et al. (2020) in the names of its shapefiles"])
    defVar(ds, "age_14c", Float64[a for (_, a, _) in slices], ("time",);
           attrib=["units" => "14C years BP", "long_name" => "radiocarbon age of the isochrone"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic", "proj_params" => NORTH_PROJ])
    defVar(ds, "f_ice", Float32, ("x", "y", "time"); deflatelevel=1, shuffle=true, chunksizes=(1000, 1000, 1),
           attrib=["units" => "1", "long_name" => "ice area fraction", "grid_mapping" => "crs"])
    ds.attrib["title"] = "Ice-margin chronology of the North American Ice Sheet Complex, 22.1 to 0.91 cal ka (Dalton et al., 2020)"
    ds.attrib["references"] = "Dalton, A. S., Margold, M., Stokes, C. R., et al.: An updated radiocarbon-based ice " *
                              "margin chronology for the last deglaciation of the North American Ice Sheet Complex, Quat. Sci. Rev., 234, 106223, 2020, " *
                              "doi:10.1016/j.quascirev.2020.106223 (shapefiles: supplementary data, mmc4)"
    ds.attrib["doi"] = "10.1016/j.quascirev.2020.106223"
    ds.attrib["license"] = "None stated for the supplementary data (Elsevier); cite Dalton et al. (2020)"
    ds.attrib["comment"] = "Shapefiles of the isochrones rasterized as the fraction of 8x8 samples per cell inside the " *
                           "ice polygons; the isochrones include Greenland and the ice caps of the Canadian Arctic"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))

    for (k, (shp, a14, cal)) in enumerate(slices)
        polys, st = read_outlines(shp, g; keep=is_ice)
        F = outline_fraction(g, polys)
        ds["f_ice"][:, :, k] = F
        println("$(round(cal / 1000; digits=2)) cal ka ($(a14 / 1000) 14C ka): $(basename(shp)), $(st.features) polygons, ",
                "$(st.rings) rings ($(st.dropped) outside the grid, $(st.partly) partly), ",
                "ice area $(round(outline_area(g, F); digits=2)) million km2 (projected)")
    end
end
println("Wrote $path")
