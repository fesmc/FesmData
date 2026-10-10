# Prepare the Colgan & Wansing (2021) geothermal heat flow of Greenland for remapping:
# the equal-area points of geothermal_heat_flow_from_machinelearning.xyz (GEUS
# Dataverse, datamanifest key colgan2021_ghf) on a regular lon-lat grid, written to
# $FESMDATA_WORK/prepared/Colgan2021_ghf/Colgan2021_GHF.nc with ghf, ghf_min, ghf_max.
#
# Usage:
#     julia --project=Colgan2021_ghf Colgan2021_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Colgan2021_ghf/Colgan2021_GHF.nc Greenland

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

"Longitude spacing (degrees) of the regular grid the equal-area cells are put on."
const DLON = 0.1

"""
    ring_grid(lon, lat, cols; dlon) -> (lons, lats, fields)

Points on rings of constant latitude (an equal-area grid: rings spaced 0.5° in latitude,
points spaced about 0.5°/cos(latitude) in longitude) on a regular lon-lat grid with the
ring latitudes and a longitude spacing `dlon`: each cell takes the values `cols` of the
nearest point of its ring, if within half the spacing of the ring (plus 1%), so that each point
fills its own equal-area cell. A point at a pole fills its ring.
"""
function ring_grid(lon, lat, cols; dlon)
    rings = sort(unique(lat))
    dlat = minimum(diff(rings))
    lats = rings[1]:dlat:rings[end]
    all(r -> any(l -> isapprox(l, r; atol=1e-6), lats), rings) || error("rings are not regularly spaced")
    lons = collect(-180 + dlon / 2:dlon:180 - dlon / 2)
    fields = [fill(NaN32, length(lons), length(lats)) for _ in cols]
    for (j, φ) in enumerate(lats)
        k = findall(l -> isapprox(l, φ; atol=1e-6), lat)
        isempty(k) && continue
        λ = mod.(lon[k] .+ 180, 360) .- 180            # 180 becomes -180 (same point)
        d = length(λ) > 1 ? minimum(filter(>(1e-6), diff(sort(unique(λ))))) : 0.5 / cosd(φ)
        for (i, l) in enumerate(lons)
            dist = abs.(mod.(λ .- l .+ 180, 360) .- 180)
            m = argmin(dist)
            (abs(φ) ≈ 90 || dist[m] <= 0.51d) || continue      # 1%: spacings rounded in the file
            for (F, c) in zip(fields, cols)
                F[i, j] = c[k[m]]
            end
        end
    end
    return lons, collect(lats), fields
end

# Columns: lon, lat, mean GHF (also offshore), minimum GHF, maximum GHF (onshore), in mW/m2
input = download_dataset(manifest(), "colgan2021_ghf")
data = readdlm(input; comments=true, comment_char='%')
lon, lat = Float64.(data[:, 1]), Float64.(data[:, 2])
lons, lats, (ghf, ghf_min, ghf_max) = ring_grid(lon, lat, (data[:, 3], data[:, 4], data[:, 5]); dlon=DLON)

path = joinpath(prepared_dir("Colgan2021_ghf"), "Colgan2021_GHF.nc")
mkpath(dirname(path))
isfile(path) && rm(path)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lons, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lats, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, F, long_name) in (("ghf", ghf, "geothermal heat flow"),
                                 ("ghf_min", ghf_min, "minimum geothermal heat flow of the model ensemble"),
                                 ("ghf_max", ghf_max, "maximum geothermal heat flow of the model ensemble"))
        defVar(ds, name, F, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "mW m-2", "long_name" => long_name])
    end
    ds.attrib["title"] = "Geothermal heat flow of Greenland (Colgan and Wansing, 2021)"
    ds.attrib["references"] = "Colgan, W. et al.: Greenland Geothermal Heat Flow Database and Map " *
                              "(Version 1), Earth Syst. Sci. Data, 14, 2209-2238, 2022, " *
                              "doi:10.5194/essd-14-2209-2022; data: Colgan, W. and Wansing, A.: Greenland " *
                              "Geothermal Heat Flow Database and Map, GEUS Dataverse, V2.1, 2021, " *
                              "doi:10.22008/FK2/F9P03L (geothermal_heat_flow_from_machinelearning.xyz)"
    ds.attrib["doi"] = "10.22008/FK2/F9P03L"
    ds.attrib["license"] = "CC0 1.0"
    ds.attrib["comment"] = "Equal-area points (0.5° in latitude, about 55 km) on a regular lon-lat grid: " *
                           "each cell has the value of the nearest point of its latitude ring. " *
                           "Model without the NGRIP basal heat flow (as in ISMIP7)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
