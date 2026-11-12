# Prepare the GNET vertical velocities of Greenland (Berg et al., 2024) as a record (see
# Records/README.md): the observed vertical velocity of 55 GNET stations and the
# modelled elastic response to the present ice loss of the ice sheet and the peripheral
# glaciers of Greenland and Arctic Canada, as distributed with Lewright et al. (2025)
# (datamanifest key lewright2025_vlm), with the station names, coordinates and the time
# span of the series from the GNET time series of Berg et al. (2024) (berg2024_gnet), one
# value per station (featureType point), $FESMDATA_PREPARED/Berg2024_gnet/Berg2024_GNET.nc.
#
# Usage:
#     julia --project=Berg2024_gnet Berg2024_gnet/prepare.jl
#     julia fesmdata.jl record GPS GNET

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

db = manifest()
extracted(key) = (d = get_dataset_path(db, key); isdir(d) ? d : download_dataset(db, key))
"The only file named `name` under `dir`."
function find_file(dir, name)
    hits = [joinpath(r, f) for (r, _, fs) in walkdir(dir) for f in fs if f == name]
    length(hits) == 1 || error("$dir: $(length(hits)) files $name")
    return only(hits)
end

# Lewright et al. (2025), Bayesian_Inversion: station locations (degrees), observed and
# elastic vertical velocities and their standard deviations (mm/yr) at 55 stations, on
# the dimension "station location", without station names
vlm = extracted("lewright2025_vlm")
function readnc(file, vars...)
    NCDataset(find_file(vlm, file)) do ds
        [Float64.(ds[v][:]) for v in vars]
    end
end
lon_l, lat_l = readnc("VLM_station_locations.nc", "station_lon", "station_lat")
obs, obs_sd = readnc("VLM_OBS_stations.nc", "VLM_OBS", "VLM_OBS_STD")
ela, ela_sd = readnc("VLM_ELA_stations.nc", "VLM_ELA", "VLM_ELA_STD")
n = length(lon_l)
all(==(n), length.((lat_l, obs, obs_sd, ela, ela_sd))) || error("$vlm: the station files differ in length")

# Berg et al. (2024): COORDINATES.txt (% header, then name, latitude, longitude) and one
# series per station, <NAME>_NEU.txt (% header, then decimal year, N, E, U and errors)
neu = find_file(extracted("berg2024_gnet"), "COORDINATES.txt") |> dirname
coords = Dict{String,Tuple{Float64,Float64}}()
for l in eachline(joinpath(neu, "COORDINATES.txt"))
    (startswith(l, "%") || isempty(strip(l))) && continue
    f = split(l)
    get!(coords, f[1], (parse(Float64, f[2]), parse(Float64, f[3])))   # ISOR is listed twice
end

# The stations of Lewright et al. are those of Berg et al. with the longitude rounded to
# 0.0001°; their latitudes are 0.02-0.07° north of those of Berg et al. (and of the NGL
# station coordinates), which are kept
stations = map(1:n) do i
    hits = [k for (k, (la, lo)) in coords if abs(lo - lon_l[i]) < 6e-5 && abs(la - lat_l[i]) < 0.1]
    length(hits) == 1 || error("station $i ($(lat_l[i]), $(lon_l[i])): $(length(hits)) GNET stations at this location")
    only(hits)
end
allunique(stations) || error("stations of Lewright et al. matched twice: $(join(stations, ", "))")

function series_span(name)
    t = [parse(Float64, split(l)[1]) for l in eachline(joinpath(neu, "$(name)_NEU.txt"))
         if !startswith(l, "%") && !isempty(strip(l))]
    return extrema(t)
end
span = series_span.(stations)

write_points(joinpath(prepared_dir("Berg2024_gnet"), "Berg2024_GNET.nc");
    sites=[Site(k, coords[k]...) for k in stations], site_long_name="GNET station",
    vars=[Var("uplift_rate", obs, "mm yr-1", "vertical velocity of the land surface (observed: elastic part not removed)";
              attrib=["elastic_correction" => "not removed",
                      "comment" => "Observed vertical velocity of Berg et al. (2024) over the series of the station " *
                                   "(IGS14); the GIA estimate is uplift_rate - uplift_rate_elastic"]),
          Var("uplift_rate_sd", obs_sd, "mm yr-1", "uncertainty (1 sigma) of the vertical velocity"),
          Var("uplift_rate_elastic", ela, "mm yr-1", "modelled elastic vertical velocity due to present ice loss";
              attrib=["comment" => "Elastic response to the mass loss of the Greenland ice sheet, the peripheral " *
                                   "glaciers of Greenland and the glaciers of Arctic Canada over the last two " *
                                   "decades (Berg et al., 2024)"]),
          Var("uplift_rate_elastic_sd", ela_sd, "mm yr-1", "uncertainty (1 sigma) of the elastic vertical velocity"),
          Var("time_start", first.(span), "year", "first epoch of the GNET series (decimal year CE)"; T=Float64),
          Var("time_end", last.(span), "year", "last epoch of the GNET series (decimal year CE)"; T=Float64)],
    title="GNET vertical velocities of Greenland and their elastic part, IGS14 (Berg et al., 2024)",
    references="Berg, D. L., Barletta, V. R., Hassan, J., Lippert, E. Y. H., Colgan, W., Bevis, M., Steffen, R., " *
               "and Khan, S. A.: Vertical land motion due to present-day ice loss from Greenland's and Canada's " *
               "peripheral glaciers, Geophys. Res. Lett., 51, e2023GL104851, 2024, doi:10.1029/2023GL104851. " *
               "Data: doi:10.5061/dryad.9zw3r22n0 (CC0). Velocities as distributed by Lewright, L. et al.: " *
               "Projections of 21st-century sea-level fall along coastal Greenland, Nat. Commun., 2025, " *
               "doi:10.1038/s41467-025-68182-6. Data: doi:10.5281/zenodo.16878392 (CC BY 4.0)",
    doi="10.5281/zenodo.16878392",
    license="CC BY 4.0 (velocities, Lewright et al., 2025, Zenodo); CC0 (station coordinates and series, " *
            "Berg et al., 2024, Dryad/Zenodo)",
    tag="gps",
    attrib=["reference_frame" => "IGS14",
            "elastic_correction" => "not removed (uplift_rate observed; elastic part in uplift_rate_elastic)"])
