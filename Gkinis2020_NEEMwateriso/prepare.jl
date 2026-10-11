# Prepare the NEEM high-resolution water isotopes of Gkinis et al. (2020) as a record (see
# Records/README.md): d18O and dD of 0.05 m samples (PANGAEA, datamanifest key
# gkinis2020_neem) as a time series at NEEM (featureType timeSeries),
# $FESMDATA_WORK/prepared/Gkinis2020_NEEMwateriso/Gkinis2020_NEEM.nc.
#
# Usage:
#     julia --project=Gkinis2020_NEEMwateriso Gkinis2020_NEEMwateriso/prepare.jl
#     julia fesmdata.jl record IceCores Gkinis2020
#
# Time scale: the table has three partial age columns (ka b2k): GICC05 (layer counted,
# 1210.50-1955.90 m, 8-60 ka), and below it GICC05_modelext and AICC2012. `time` is
# GICC05 above and GICC05_modelext below (the GICC05 family); `time_aicc2012` is GICC05
# above and AICC2012 below. Samples without an age (the folded ice at the bottom) are
# left out, and the samples are sorted by `time`, as the ages are not monotonic in depth
# in the disturbed ice between 2206 and 2365 m. The dimension is `sample`, not `time`,
# as a few samples have the same age.

using CSV
using DataFrames
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const B2K_TO_BP = 50.0          # years before 2000 CE -> years before 1950 CE

# NEEM, from the event of the PANGAEA dataset
const SITE = (name="NEEM", lat=77.45, lon=-51.06, z_srf=2545.0)

# Columns of the table, in order
const COLUMNS = [:depth, :age_gicc05, :age_gicc05_modelext, :age_aicc2012, :mce,
                 :d18O, :dD, :d18O_sd, :dD_sd, :d18O_offset, :dD_offset]

tab = download_dataset(manifest(), "gkinis2020_neem")

# PANGAEA text: a /* ... */ metadata header, a line of column names, then the data
lines = readlines(tab)
h = findfirst(l -> startswith(l, "*/"), lines)
h === nothing && error("$tab: no end of the metadata header (*/)")
startswith(lines[h+1], "Depth ice/snow [m]") || error("$tab: unexpected columns: $(lines[h+1])")
df = CSV.read(tab, DataFrame; delim='\t', header=COLUMNS, skipto=h + 2, missingstring="")
ncol(df) == length(COLUMNS) || error("$tab: $(ncol(df)) columns, expected $(length(COLUMNS))")

# Ages (ka b2k) of the two time scales, GICC05 where it is counted
age = coalesce.(df.age_gicc05, df.age_gicc05_modelext)
age_aicc = coalesce.(df.age_gicc05, df.age_aicc2012)
keep = findall(!ismissing, age)
println("$(nrow(df)) samples, $(nrow(df) - length(keep)) without a GICC05 age left out, ",
        "$(count(<(0), diff(Float64.(age[keep])))) age reversals with depth")
idx = keep[sortperm(Float64.(age[keep]))]
nt = length(idx)

years_ago(a) = ismissing(a) ? NaN : 1000.0 * a - B2K_TO_BP
f32(v) = Float32[ismissing(x) ? NaN32 : Float32(x) for x in v]
series(v) = reshape(f32(v[idx]), nt, 1)

path = joinpath(prepared_dir("Gkinis2020_NEEMwateriso"), "Gkinis2020_NEEM.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defDim(ds, "station", 1)
    defDim(ds, "sample", nt)
    defVar(ds, "site_name", [SITE.name], ("station",); attrib=["long_name" => "ice core site", "cf_role" => "timeseries_id"])
    defVar(ds, "lat", [SITE.lat], ("station",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "lon", [SITE.lon], ("station",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "z_srf", [SITE.z_srf], ("station",); attrib=["units" => "m", "long_name" => "surface elevation of the site"])
    defVar(ds, "time", years_ago.(age[idx]), ("sample",); attrib=[
        "units" => "years ago", "long_name" => "time (years before 1950 CE)",
        "comment" => "ice age at the bottom of the sample, GICC05 (counted) above 1955.90 m and GICC05_modelext " *
                     "below, converted from years b2k (before 2000 CE) by subtracting 50"])
    defVar(ds, "time_aicc2012", years_ago.(age_aicc[idx]), ("sample",); fillvalue=NaN, attrib=[
        "units" => "years ago", "long_name" => "time on GICC05 (above 1955.90 m) and AICC2012 (below), years before 1950 CE"])
    defVar(ds, "mce", f32(df.mce[idx]), ("sample",); fillvalue=NaN32, attrib=[
        "units" => "yr", "long_name" => "maximum counting error of GICC05 (counted part only)"])
    attrib_series(units, long_name) = ["units" => units, "long_name" => long_name, "coordinates" => "time lat lon"]
    defVar(ds, "depth", series(df.depth), ("sample", "station"); deflatelevel=1,
           attrib=["units" => "m", "positive" => "down", "long_name" => "depth in the core of the bottom of the 0.05 m sample"])
    for (name, long_name) in (("d18O", "delta-18O of the ice (18O/16O), per mil VSMOW"),
                              ("dD", "delta-D of the ice (2H/1H), per mil VSMOW"),
                              ("d18O_sd", "precision (1 sigma) of d18O, per mil"),
                              ("dD_sd", "precision (1 sigma) of dD, per mil"),
                              ("d18O_offset", "offset of the d18O accuracy check, per mil VSMOW"),
                              ("dD_offset", "offset of the dD accuracy check, per mil VSMOW"))
        defVar(ds, name, series(df[!, Symbol(name)]), ("sample", "station"); fillvalue=NaN32, deflatelevel=1,
               attrib=attrib_series("1e-3", long_name))
    end
    ds.attrib["title"] = "NEEM ice core high-resolution (0.05 m) water isotopes, 8-129 ka b2k (Gkinis et al., 2020)"
    ds.attrib["references"] = "Gkinis, V. et al.: NEEM ice core High Resolution (0.05m) Water Isotope Ratios " *
                              "(18O/16O, 2H/1H) covering 8-129 ky b2k, PANGAEA, 2020, doi:10.1594/PANGAEA.925552; " *
                              "Gkinis, V. et al.: A 120,000-year long climate record from a NW-Greenland deep ice " *
                              "core at ultra-high resolution, Sci. Data, 8, 141, 2021, doi:10.1038/s41597-021-00916-9"
    ds.attrib["doi"] = "10.1594/PANGAEA.925552"
    ds.attrib["license"] = "CC BY 4.0 (PANGAEA)"
    ds.attrib["featureType"] = "timeSeries"
    ds.attrib["Conventions"] = "CF-1.11"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icecores"))
end
println("Wrote $path")
