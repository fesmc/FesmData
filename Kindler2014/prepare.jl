# Prepare the NGRIP temperature reconstruction of Kindler et al. (2014) as a record (see
# Records/README.md): the modelled data of the supplement (datamanifest key
# kindler2014_ngrip), surface temperature and accumulation rate every 20 years from 10 to
# 123 kyr b2k, as a time series at NGRIP (featureType timeSeries),
# $FESMDATA_PREPARED/Kindler2014/Kindler2014_NGRIP.nc.
#
# Usage:
#     julia --project=Kindler2014 Kindler2014/prepare.jl
#     julia fesmdata.jl record IceCores Kindler2014

using NCDatasets
using XLSX

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const B2K_TO_BP = 50.0          # years before 2000 CE -> years before 1950 CE
const RHO_ICE = 917.0           # kg m-3, accumulation in m ice yr-1 -> kg m-2 yr-1

# NGRIP, as in the readme sheet of the supplement (no elevation given)
const SITE = (name="NGRIP", lat=75.10, lon=-42.32)

xlsx = joinpath(download_dataset(manifest(), "kindler2014_ngrip"), "supplement.xlsx")

# Sheet "modelled data": a header (columns in row 11, units in row 12), then the data in
# columns 1-5: depth (m), age ss09sea06bm (yr), age GICC05modelext (yr), accumulation,
# tuned (m ice/yr), temperature (°C); ages in years b2k. Columns 8-12 hold the ice and
# gas ages, not used.
m = XLSX.readxlsx(xlsx)["modelled data"][:]
header = [strip(string(m[11, j])) for j in 1:5]
header == ["depth", "age ss09sea06bm", "age GICC05modelext", "accumulation, tuned", "temperature"] ||
    error("$xlsx: unexpected columns $header")
rows = [i for i in 13:size(m, 1) if m[i, 1] isa Number]
col(j) = Float64[m[i, j] for i in rows]
depth, age_ss09, age_gicc05, acc, temp = col(1), col(2), col(3), col(4), col(5)
issorted(age_gicc05; lt=<=) || error("$xlsx: the GICC05modelext ages do not increase")

nt = length(rows)
time = age_gicc05 .- B2K_TO_BP

path = joinpath(prepared_dir("Kindler2014"), "Kindler2014_NGRIP.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defDim(ds, "station", 1)
    defDim(ds, "time", nt)
    defVar(ds, "site_name", [SITE.name], ("station",); attrib=["long_name" => "ice core site", "cf_role" => "timeseries_id"])
    defVar(ds, "lat", [SITE.lat], ("station",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "lon", [SITE.lon], ("station",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "time", time, ("time",); attrib=[
        "units" => "years ago", "long_name" => "time (years before 1950 CE)",
        "comment" => "GICC05modelext ice age, converted from years b2k (before 2000 CE) by subtracting 50"])
    defVar(ds, "time_ss09sea06bm", age_ss09 .- B2K_TO_BP, ("time",); attrib=[
        "units" => "years ago", "long_name" => "time on the ss09sea06bm time scale of the model run (years before 1950 CE)"])
    attrib_series(units, long_name) = ["units" => units, "long_name" => long_name, "coordinates" => "time lat lon"]
    defVar(ds, "depth", reshape(depth, nt, 1), ("time", "station"); deflatelevel=1,
           attrib=["units" => "m", "positive" => "down", "long_name" => "depth in the core of the ice of this age"])
    defVar(ds, "tas", reshape(Float32.(temp .+ 273.15), nt, 1), ("time", "station"); deflatelevel=1,
           attrib=attrib_series("K", "surface temperature (annual mean), from d15N and a firn densification " *
                                     "and heat diffusion model; uncertainty about 3 K"))
    defVar(ds, "acc", reshape(Float32.(acc .* RHO_ICE), nt, 1), ("time", "station"); deflatelevel=1,
           attrib=attrib_series("kg m-2 yr-1", "accumulation rate, tuned (from m ice yr-1 with an ice density " *
                                               "of $(Int(RHO_ICE)) kg m-3)"))
    ds.attrib["title"] = "NGRIP surface temperature and accumulation rate, 10-120 kyr b2k (Kindler et al., 2014)"
    ds.attrib["references"] = "Kindler, P., Guillevic, M., Baumgartner, M., Schwander, J., Landais, A., and " *
                              "Leuenberger, M.: Temperature reconstruction from 10 to 120 kyr b2k from the NGRIP " *
                              "ice core, Clim. Past, 10, 887-902, 2014 (supplement, sheet modelled data)"
    ds.attrib["doi"] = "10.5194/cp-10-887-2014"
    ds.attrib["license"] = "CC BY 3.0 (supplement of a Clim. Past article)"
    ds.attrib["featureType"] = "timeSeries"
    ds.attrib["Conventions"] = "CF-1.11"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icecores"))
end
println("Wrote $path")
