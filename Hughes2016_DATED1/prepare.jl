# Prepare the time-slice reconstructions of the Eurasian ice sheets of DATED-1 (Hughes et al.,
# 2016) for remapping: the most-credible, minimum and maximum ice extents every 1000 years
# from 25 to 10 ka, rasterized as ice area fractions on the 2 km grid of the North domain
# (../shared/outlines.jl), in one prepared NetCDF file,
# $FESMDATA_PREPARED/Hughes2016_DATED1/Hughes2016_DATED1.nc, with f_ice (most-credible),
# f_ice_min and f_ice_max on (x, y, time).
#
# Usage:
#     julia -t 16 --project=Hughes2016_DATED1 Hughes2016_DATED1/prepare.jl
#     julia fesmdata.jl remap IceHistory DATED1

using FesmUtils
using NCDatasets
import ArchGDAL as AG
import GeoInterface as GI
import Proj

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "outlines.jl"))

const KEY = "hughes2016_dated1"
const AGES = 25:-1:10                  # ka (calendar, before 1950 CE), the time slices TS<age>_{mc,min,max}.shp

# Fields and the suffix of their shapefiles
const ESTIMATES = [("f_ice", "mc", "most-credible"), ("f_ice_min", "min", "minimum"), ("f_ice_max", "max", "maximum")]

dir = joinpath(download_dataset(manifest(), KEY), "DATED1 TimeSlices shp")
shapefile(age, suffix) = (p = joinpath(dir, "TS$(age)_$(suffix).shp"); isfile(p) ? p : error("missing $p"))
g = north_outline_grid("DATED1")

path = joinpath(prepared_dir("Hughes2016_DATED1"), "Hughes2016_DATED1.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "x", g.xc, ("x",); attrib=["units" => "km", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", g.yc, ("y",); attrib=["units" => "km", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "time", Float64[1000 * a for a in AGES], ("time",);
           attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)",
                   "comment" => "the time slices of DATED-1 (calendar ka)"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic", "proj_params" => NORTH_PROJ])
    for (name, _, est) in ESTIMATES
        defVar(ds, name, Float32, ("x", "y", "time"); deflatelevel=1, shuffle=true, chunksizes=(1000, 1000, 1),
               attrib=["units" => "1", "long_name" => "ice area fraction, $est ice-sheet extent", "grid_mapping" => "crs"])
    end
    ds.attrib["title"] = "DATED-1: time-slice reconstructions of the Eurasian ice sheets, 25 to 10 ka (Hughes et al., 2016)"
    ds.attrib["references"] = "Hughes, A. L. C., Gyllencreutz, R., Lohne, Ø. S., Mangerud, J. and Svendsen, J. I.: The last " *
                              "Eurasian ice sheets - a chronological database and time-slice reconstruction, DATED-1, " *
                              "Boreas, 45, 1-45, 2016, doi:10.1111/bor.12142; data: PANGAEA, doi:10.1594/PANGAEA.848117"
    ds.attrib["doi"] = "10.1594/PANGAEA.848117"
    ds.attrib["license"] = "CC BY 3.0 (PANGAEA)"
    ds.attrib["comment"] = "Shapefiles TS<ka>_{mc,min,max} rasterized as the fraction of 8x8 samples per cell inside the " *
                           "outlines; the older slices of DATED-1 (38-35, 32-30, 29-28 and 27 ka, without the three " *
                           "estimates) are left out"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))

    for (k, age) in enumerate(AGES), (name, suffix, _) in ESTIMATES
        shp = shapefile(age, suffix)
        polys, st = read_outlines(shp, g)
        F = outline_fraction(g, polys)
        ds[name][:, :, k] = F
        println("$age ka $name: $(basename(shp)), $(st.features) polygons, $(st.rings) rings ($(st.dropped) outside the ",
                "grid, $(st.partly) partly), ice area $(round(outline_area(g, F); digits=2)) million km2 (projected)")
    end
end
println("Wrote $path")
