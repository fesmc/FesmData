# Prepare the BIFROST2015 GNSS velocities of Fennoscandia (Kierulf et al., 2021) as a
# record (see Records/README.md): the observed vertical velocity of the 164 stations
# (ITRF2008, 2000.0-2015.0) and the modelled elastic part over the observation period of
# each (supplement of the article, datamanifest key kierulf2021_bifrost), one value per
# station (featureType point), $FESMDATA_PREPARED/Kierulf2021_bifrost/Kierulf2021_BIFROST2015.nc.
#
# Usage:
#     julia --project=Kierulf2021_bifrost Kierulf2021_bifrost/prepare.jl
#     julia fesmdata.jl record GPS BIFROST2015

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

const KEY = "kierulf2021_bifrost"
const T_END = 2015.0              # the series end at 2015.0, `yrs` is their length

db = manifest()
dir = get_dataset_path(db, KEY)
isdir(dir) || (dir = download_dataset(db, KEY))
txt = joinpath(dir, "BIFROST2015_velocities_final.txt")

# A line of description, a line of column names, then one line per station, columns
# separated by spaces (Appendix E of the article; all rates in mm/yr)
lines = filter(!isempty ∘ strip, readlines(txt))
header = split(lines[2])
header[1:4] == ["Code", "lat", "lon", "yrs"] || error("$txt: unexpected columns $(join(header, " "))")
rows = split.(lines[3:end])
bad = findall(r -> length(r) != length(header), rows)
isempty(bad) || error("$txt: $(length(bad)) lines without $(length(header)) columns")
function col(name)
    j = findfirst(==(name), header)
    j === nothing && error("$txt: no column $name in $(join(header, " "))")
    return [parse(Float64, r[j]) for r in rows]
end
code = String[r[1] for r in rows]
allunique(code) || error("$txt: station codes repeat")
yrs = col("yrs")

write_points(joinpath(prepared_dir("Kierulf2021_bifrost"), "Kierulf2021_BIFROST2015.nc");
    sites=Site.(code, col("lat"), mod.(col("lon") .+ 180, 360) .- 180), site_long_name="GNSS station",
    vars=[Var("uplift_rate", col("U"), "mm yr-1", "vertical velocity of the land surface (observed: elastic part not removed)";
              attrib=["elastic_correction" => "not removed",
                      "comment" => "Observed vertical velocity (U) in ITRF2008; the GIA estimate is " *
                                   "uplift_rate - uplift_rate_elastic"]),
          Var("uplift_rate_sd", col("U_RMS"), "mm yr-1", "uncertainty (1 sigma) of the vertical velocity"),
          Var("uplift_rate_elastic", col("sum_t"), "mm yr-1",
              "modelled elastic vertical velocity over the observation period of the station";
              attrib=["comment" => "Total elastic correction of Kierulf et al. (2021) (sum_t): elastic response to " *
                                   "the ice mass changes of Antarctica, the Greenland ice sheet and glaciers and the " *
                                   "global glaciers, to hydrology (sum_h), and atmospheric and non-tidal ocean " *
                                   "loading; error at most about 10%"]),
          Var("time_start", T_END .- yrs, "year", "first epoch of the series (decimal year CE)"; T=Float64),
          Var("time_end", fill(T_END, length(yrs)), "year", "last epoch of the series (decimal year CE)"; T=Float64)],
    title="BIFROST2015 GNSS vertical velocities of Fennoscandia and their elastic part, ITRF2008 (Kierulf et al., 2021)",
    references="Kierulf, H. P., Steffen, H., Barletta, V. R., Lidberg, M., Johansson, J., Kristiansen, O., and " *
               "Tarasov, L.: A GNSS velocity field for geophysical applications in Fennoscandia, J. Geodyn., " *
               "146, 101845, 2021, doi:10.1016/j.jog.2021.101845 (supplementary data)",
    doi="10.1016/j.jog.2021.101845", license="CC BY 4.0 (open access article and its supplement)", tag="gps",
    attrib=["reference_frame" => "ITRF2008 (IGb08)",
            "elastic_correction" => "not removed (uplift_rate observed; elastic part in uplift_rate_elastic)"])
