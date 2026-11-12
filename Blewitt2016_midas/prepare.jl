# Prepare the MIDAS vertical velocities of the GPS stations of the Nevada Geodetic
# Laboratory (Blewitt et al., 2016) as a record (see Records/README.md): all stations of
# a dated snapshot of midas.IGS.txt (IGS20, updated weekly by NGL; datamanifest key
# blewitt2016_midas, the date in its folder), one value per station (featureType point),
# $FESMDATA_PREPARED/Blewitt2016_midas/Blewitt2016_MIDAS.nc.
#
# Usage:
#     julia --project=Blewitt2016_midas Blewitt2016_midas/prepare.jl
#     julia fesmdata.jl record GPS MIDAS

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

txt = download_dataset(manifest(), "blewitt2016_midas")
snapshot = basename(dirname(txt))
occursin(r"^\d{4}-\d{2}-\d{2}$", snapshot) || error("$txt: the folder is not the date of the snapshot (yyyy-mm-dd)")

# 27 columns separated by spaces (midas.readme.txt of NGL): 1 station, 2 MIDAS version,
# 3-4 first and last epoch (decimal year), 5 duration (yr), 6-8 numbers of epochs, good
# epochs and velocity pairs, 9-11 east, north, up velocity (m/yr), 12-14 their
# uncertainties (m/yr), 15-17 offsets at the first epoch (m), 18-20 fractions of outliers,
# 21-23 standard deviations of the velocity pairs (m/yr), 24 number of steps, 25-27
# latitude, longitude (degrees, may be < -180) and height (m)
rows = [split(l) for l in eachline(txt) if !isempty(strip(l))]
bad = findall(r -> length(r) != 27, rows)
isempty(bad) || error("$txt: $(length(bad)) lines without 27 columns, e.g. line $(first(bad))")
col(j) = [parse(Float64, r[j]) for r in rows]
versions = unique(r[2] for r in rows)
station = String[r[1] for r in rows]
allunique(station) || error("$txt: station names repeat")
lat, lon = col(25), mod.(col(26) .+ 180, 360) .- 180
t0, t1 = col(3), col(4)

write_points(joinpath(prepared_dir("Blewitt2016_midas"), "Blewitt2016_MIDAS.nc");
    sites=Site.(station, lat, lon), site_long_name="GPS station (4-character ID of NGL)",
    vars=[Var("uplift_rate", 1e3 .* col(11), "mm yr-1", "vertical velocity of the land surface (observed: elastic part not removed)";
              attrib=["elastic_correction" => "not removed",
                      "comment" => "Observed total vertical velocity in IGS20: GIA, the elastic response to present " *
                                   "ice, water and atmosphere loads, tectonics and local motion; no correction"]),
          Var("uplift_rate_sd", 1e3 .* col(14), "mm yr-1", "uncertainty (1 sigma) of the vertical velocity (MIDAS)"),
          Var("time_start", t0, "year", "first epoch of the series (decimal year CE)"; T=Float64),
          Var("time_end", t1, "year", "last epoch of the series (decimal year CE)"; T=Float64),
          Var("n_steps", col(24), "1", "number of steps (equipment changes, earthquakes) in the series"; T=Int32)],
    title="MIDAS vertical velocities of the GPS stations of the Nevada Geodetic Laboratory, IGS20, snapshot $snapshot",
    references="Blewitt, G., Kreemer, C., Hammond, W. C., and Gazeaux, J.: MIDAS robust trend estimator for " *
               "accurate GPS station velocities without step detection, J. Geophys. Res. Solid Earth, 121, " *
               "2054-2068, 2016, doi:10.1002/2015JB012552. Blewitt, G., Hammond, W. C., and Kreemer, C.: " *
               "Harnessing the GPS data explosion for interdisciplinary science, Eos, 99, 2018, " *
               "doi:10.1029/2018EO104623. Data: Nevada Geodetic Laboratory, " *
               "https://geodesy.unr.edu/gps_timeseries/IGS20/midas/midas.IGS.txt",
    doi="10.1002/2015JB012552",
    license="CC BY 4.0 (data products policy of the Nevada Bureau of Mines and Geology, University of Nevada, Reno)",
    tag="gps",
    attrib=["reference_frame" => "IGS20", "elastic_correction" => "not removed",
            "snapshot" => "$snapshot: midas.IGS.txt of NGL as downloaded on this date (MIDAS version " *
                          "$(join(versions, ", ")), last epoch $(maximum(t1)))"])
