# Prepare the Badgeley et al. (2020) Greenland reconstructions for remapping: the
# posterior mean of the main temperature reconstruction and of the main, low and high
# precipitation reconstructions (Arctic Data Center, datamanifest keys badgeley2020_*),
# as one prepared file, $FESMDATA_WORK/prepared/Badgeley2020_recon/Badgeley2020.nc,
# with tas_anom, pr_frac, pr_frac_low and pr_frac_high on the native T31 grid of
# TraCE-21ka, 20 ka to 0 BP.
#
# Usage:
#     julia --project=Badgeley2020_recon Badgeley2020_recon/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Badgeley2020_recon/Badgeley2020.nc Greenland

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const REF = "the reference period 1850-2000 CE"

# Field name => (datamanifest key, units, long_name)
const FIELDS = [
    "tas_anom" => ("badgeley2020_tas_main", "K", "surface air temperature anomaly relative to $REF"),
    "pr_frac" => ("badgeley2020_pr_main", "1", "precipitation relative to $REF (fraction), moderate accumulation scenario"),
    "pr_frac_low" => ("badgeley2020_pr_low", "1", "precipitation relative to $REF (fraction), low accumulation scenario"),
    "pr_frac_high" => ("badgeley2020_pr_high", "1", "precipitation relative to $REF (fraction), high accumulation scenario"),
]

db = manifest()

# Grid and time axis, the same in all files. Longitudes 0:360 -> -180:180; latitudes
# are Gaussian (T31), ascending. time is in years before 1950 CE (labelled "ka" in the
# files, but in years), 20000 to 0 in steps of 50 years.
lon, lat, time = NCDataset(download_dataset(db, FIELDS[1][2][1])) do ds
    Float64.(ds["lon"].var[:]), Float64.(ds["lat"].var[:]), Float64.(ds["time"].var[:])
end
lon = mod.(lon .+ 180, 360) .- 180
issorted(lon) && issorted(lat) || error("unexpected axis order in the Badgeley et al. (2020) files")

# posterior_mean is (time, lat, lon) in the file, (lon, lat, time) in Julia; missing
# values are NaN (the _FillValue), read as they are
function read_field(key)
    NCDataset(download_dataset(db, key)) do ds
        ds["lon"].var[:] ≈ mod.(lon, 360) && ds["lat"].var[:] ≈ lat && ds["time"].var[:] ≈ time ||
            error("$key: grid or time axis differs from that of $(FIELDS[1][2][1])")
        dimnames(ds["posterior_mean"]) == ("lon", "lat", "time") || error("$key: unexpected dimensions")
        return Float32.(ds["posterior_mean"].var[:, :, :])
    end
end

path = joinpath(prepared_dir("Badgeley2020_recon"), "Badgeley2020.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude",
                                             "comment" => "Gaussian latitudes of the T31 grid of TraCE-21ka"])
    defVar(ds, "time", time, ("time",); attrib=["units" => "years BP", "long_name" => "age (years before present, 1950 CE)",
                                                "comment" => "means over 50 years centred on the given time"])
    for (name, (key, units, long_name)) in FIELDS
        defVar(ds, name, read_field(key), ("lon", "lat", "time"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => units, "long_name" => long_name,
                       "comment" => "posterior mean, annual mean, from $(basename(get_dataset_path(db, key)))"])
    end
    ds.attrib["title"] = "Greenland annual mean temperature and precipitation over the last 20,000 years " *
                         "from data assimilation (Badgeley et al., 2020)"
    ds.attrib["references"] = "Badgeley, J. A., Steig, E. J., Hakim, G. J., and Fudge, T. J.: Greenland temperature " *
                              "and precipitation over the last 20 000 years using data assimilation, Clim. Past, 16, " *
                              "1325-1346, 2020, doi:10.5194/cp-16-1325-2020. Data: Badgeley, J. A. et al., Arctic " *
                              "Data Center, doi:10.18739/A2599Z26M"
    ds.attrib["doi"] = "10.18739/A2599Z26M"
    ds.attrib["license"] = "CC0 1.0 (public domain dedication, Arctic Data Center)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("paleoclimate"))
end
println("Wrote $path")
