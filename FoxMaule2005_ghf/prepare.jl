# Prepare the Fox Maule et al. (2005) geothermal heat flow (updated with the MF7
# magnetic field model) for remapping: the equal-area points of Antarctica
# (heatflux_mf7_foxmaule05.txt, south of 60°S) and of the land north of 55°N
# (heatflux_mf7_foxmaule05_npolar.txt, mct_mf7_foxmaule05_npolar.txt) on one regular
# lon-lat grid, written to $FESMDATA_WORK/prepared/FoxMaule2005_ghf/FoxMaule2005_GHF.nc
# with ghf and h_mag (magnetic crustal thickness, north only).
#
# Usage:
#     julia --project=FoxMaule2005_ghf FoxMaule2005_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/FoxMaule2005_ghf/FoxMaule2005_GHF.nc Antarctica Greenland

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "ringgrid.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

"Longitude spacing (degrees) of the regular grid the equal-area cells are put on."
const DLON = 0.1

# Columns: lon, lat, value (heat flow in mW m-2, magnetic crustal thickness in km).
# The Greenland points of heatflux_mf7_foxmaule05.txt are also in the npolar file
# (same values), so only its Antarctic points are used.
db = manifest()
polar = readdlm(download_dataset(db, "foxmaule2005_ghf"), Float64)
npolar = readdlm(download_dataset(db, "foxmaule2005_ghf_npolar"), Float64)
mct = readdlm(download_dataset(db, "foxmaule2005_mct_npolar"), Float64)
hf = vcat(polar[polar[:, 2] .< 0, :], npolar)

lons, lats, (ghf,) = ring_grid(hf[:, 1], hf[:, 2], (hf[:, 3],); dlon=DLON)
lons_m, lats_m, (h,) = ring_grid(mct[:, 1], mct[:, 2], (mct[:, 3],); dlon=DLON)
lons_m == lons || error("the crustal thickness is not on the longitudes of the heat flow")
jm = [findfirst(l -> isapprox(l, φ; atol=1e-6), lats) for φ in lats_m]
any(isnothing, jm) && error("the crustal thickness is not on the rings of the heat flow")
h_mag = fill(NaN32, size(ghf))
h_mag[:, jm] = h

path = joinpath(prepared_dir("FoxMaule2005_ghf"), "FoxMaule2005_GHF.nc")
mkpath(dirname(path))
isfile(path) && rm(path)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lons, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lats, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, F, units, long_name) in (("ghf", ghf, "mW m-2", "geothermal heat flow"),
                                        ("h_mag", h_mag, "km", "magnetic crustal thickness (depth to the Curie isotherm)"))
        defVar(ds, name, F, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => units, "long_name" => long_name])
    end
    ds.attrib["title"] = "Geothermal heat flow of Antarctica and the northern high latitudes " *
                         "(Fox Maule et al., 2005, updated with MF7)"
    ds.attrib["references"] = "Fox Maule, C., Purucker, M. E., Olsen, N. and Mosegaard, K.: Heat flux " *
                              "anomalies in Antarctica revealed by satellite magnetic data, Science, 309, " *
                              "464-467, 2005, doi:10.1126/science.1106888; data: M. Purucker, NASA GSFC, " *
                              "update with the MF7 magnetic field model, " *
                              "core2.gsfc.nasa.gov/research/purucker/heatflux_updates.html " *
                              "(heatflux_mf7_foxmaule05.txt, heatflux_mf7_foxmaule05_npolar.txt, " *
                              "mct_mf7_foxmaule05_npolar.txt)"
    ds.attrib["doi"] = "10.1126/science.1106888"
    ds.attrib["license"] = "No licence stated (NASA GSFC web page); users are asked to cite Fox Maule et al. (2005)"
    ds.attrib["comment"] = "Equal-area points (rings 1.5° apart in latitude, about 170 km) on a regular " *
                           "lon-lat grid: each cell has the value of the nearest point of its latitude ring. " *
                           "Land only; Antarctica south of 87.75°S (the polar cap) has no data. " *
                           "h_mag only north of 55°N"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
