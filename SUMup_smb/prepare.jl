# Prepare the surface mass balance measurements of SUMup 2025 (Vandecrux et al., 2025) as
# a record (see Records/README.md): all SMB measurements of Greenland and Antarctica
# (Arctic Data Center, datamanifest keys sumup2025_smb_greenland and
# sumup2025_smb_antarctica), one observation per measurement (featureType point), as
# the mean SMB rate over the measurement interval and the SMB of the interval,
# $FESMDATA_WORK/prepared/SUMup_smb/SUMup2025_SMB.nc.
#
# Usage:
#     julia --project=SUMup_smb SUMup_smb/prepare.jl
#     julia fesmdata.jl record SMBObs SUMup2025
#
# SUMup gives the SMB accumulated over an interval (m w.e.): from start_date to
# end_date where these are given, otherwise over the years start_year to end_year. The
# interval is written as time_bnds (from 1 January of start_year to 1 January after
# end_year when there are no dates), the SMB of the interval as smb_total = 1000 SMB
# (kg m-2), and the mean rate over the interval as smb = smb_total / duration
# (kg m-2 yr-1, duration in years of 365.25 days); the errors likewise (smb_total_sd,
# smb_sd). Measurements over an interval of length zero (12 stake readings of 0 in
# Greenland) are left out.

using Dates
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEYS = ["sumup2025_smb_greenland", "sumup2025_smb_antarctica"]
const EPOCH = DateTime(1900, 1, 1)
const DAYS_PER_YEAR = 365.25
const RHO_W = 1000.0            # kg m-3, m w.e. -> kg m-2

days(t::DateTime) = Dates.value(t - EPOCH) / 86_400_000

# Strings of the METADATA group, stored as UTF-8 bytes in char arrays (string length x n)
function strings(v)
    c = v.var[:, :]
    return [strip(String(UInt8[UInt8(x) for x in c[:, j] if x != '\0'])) for j in axes(c, 2)]
end

# Lookup table key => string of the METADATA group, merged over the files (the keys are
# the same in both files). The entry without a key (method "NA" of the measurements
# without method_key) is left out.
function merge_table!(table, m, key, name)
    for (k, s) in zip(m[key][:], strings(m[name]))
        ismissing(k) && continue
        haskey(table, k) && table[k] != s && error("SUMup: $name of $key $k differs between the files")
        table[k] = s
    end
end

# Columns of the measurements, concatenated over the files
cols = Dict{Symbol,Vector}(c => [] for c in (:lat, :lon, :z, :t0, :t1, :smb, :err, :name_key, :method_key, :reference_key))
site_names, method_names, references, references_short = (Dict{Int32,String}() for _ in 1:4)
db = manifest()
for key in KEYS
    NCDataset(download_dataset(db, key)) do ds
        d, m = ds.group["DATA"], ds.group["METADATA"]
        sd, ed, sy, ey = d["start_date"][:], d["end_date"][:], d["start_year"][:], d["end_year"][:]
        any(ismissing.(sd) .!= ismissing.(ed)) && error("$key: start_date and end_date are not given together")
        (any(ismissing, sy) || any(ismissing, ey)) && error("$key: missing start_year or end_year")
        t0 = [ismissing(sd[i]) ? DateTime(sy[i], 1, 1) : sd[i] for i in eachindex(sd)]
        t1 = [ismissing(ed[i]) ? DateTime(ey[i] + 1, 1, 1) : ed[i] for i in eachindex(ed)]
        z = d["elevation"][:]
        append!(cols[:lat], d["latitude"][:])
        append!(cols[:lon], d["longitude"][:])
        append!(cols[:z], [ismissing(x) || x < -1000 ? NaN32 : Float32(x) for x in z])    # fill -9999 and Int32 minimum
        append!(cols[:t0], days.(t0))
        append!(cols[:t1], days.(t1))
        append!(cols[:smb], d["smb"][:])
        append!(cols[:err], [ismissing(x) ? NaN32 : Float32(x) for x in d["error"][:]])
        for k in (:name_key, :method_key, :reference_key)
            append!(cols[k], [ismissing(x) ? Int32(-9999) : Int32(x) for x in d[String(k)][:]])
        end
        merge_table!(site_names, m, "name_key", "name")
        merge_table!(method_names, m, "method_key", "method")
        merge_table!(references, m, "reference_key", "reference")
        merge_table!(references_short, m, "reference_key", "reference_short")
        println("$key: $(length(sd)) measurements")
    end
end

t0, t1 = Float64.(cols[:t0]), Float64.(cols[:t1])
keep = findall(t1 .> t0)
println("$(length(t0) - length(keep)) measurements over an interval of length zero left out")
any(t1 .< t0) && error("SUMup: measurements ending before they start")
duration = (t1[keep] .- t0[keep]) ./ DAYS_PER_YEAR
n = length(keep)
sel(c) = cols[c][keep]

path = joinpath(prepared_dir("SUMup_smb"), "SUMup2025_SMB.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defDim(ds, "obs", n)
    defDim(ds, "nv", 2)
    attrib_obs(units, long_name) = ["units" => units, "long_name" => long_name, "coordinates" => "time lat lon"]
    defVar(ds, "lat", Float32.(sel(:lat)), ("obs",); deflatelevel=1,
           attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "lon", Float32.(sel(:lon)), ("obs",); deflatelevel=1,
           attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "z_srf", Float32.(sel(:z)), ("obs",); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "m", "long_name" => "elevation of the measurement (datum may vary)"])
    defVar(ds, "time", (t0[keep] .+ t1[keep]) ./ 2, ("obs",); deflatelevel=1, attrib=[
        "units" => "days since 1900-01-01 00:00:00", "calendar" => "proleptic_gregorian", "bounds" => "time_bnds",
        "long_name" => "time, middle of the measurement interval"])
    defVar(ds, "time_bnds", permutedims(hcat(t0[keep], t1[keep])), ("nv", "obs"); deflatelevel=1)
    defVar(ds, "smb", Float32.(RHO_W .* sel(:smb) ./ duration), ("obs",); deflatelevel=1,
           attrib=attrib_obs("kg m-2 yr-1", "surface mass balance, mean rate over the measurement interval " *
                                            "(time_bnds): smb_total / duration"))
    defVar(ds, "smb_sd", Float32.(RHO_W .* abs.(sel(:err)) ./ duration), ("obs",); fillvalue=NaN32, deflatelevel=1,
           attrib=attrib_obs("kg m-2 yr-1", "error of the surface mass balance rate (absolute value of the error " *
                                            "given by SUMup)"))
    defVar(ds, "smb_total", Float32.(RHO_W .* sel(:smb)), ("obs",); deflatelevel=1,
           attrib=attrib_obs("kg m-2", "surface mass balance accumulated over the measurement interval " *
                                       "(time_bnds), as given by SUMup (m w.e. x 1000)"))
    defVar(ds, "smb_total_sd", Float32.(RHO_W .* abs.(sel(:err))), ("obs",); fillvalue=NaN32, deflatelevel=1,
           attrib=attrib_obs("kg m-2", "error of the surface mass balance of the interval (absolute value of " *
                                       "the error given by SUMup)"))
    for (k, long_name) in (("name_key", "core or location name (key into name_table)"),
                           ("method_key", "measurement method (key into method_table)"),
                           ("reference_key", "reference of the data (key into reference_table)"))
        defVar(ds, k, Int32.(sel(Symbol(k))), ("obs",); fillvalue=Int32(-9999), deflatelevel=1,
               attrib=["units" => "1", "long_name" => long_name])
    end
    # Lookup tables of the keys: <table>_key and the strings, along the dimension <table>
    for (table, dict, vars) in (("name_table", site_names, [("name", "core or location name")]),
                                ("method_table", method_names, [("method", "measurement method")]),
                                ("reference_table", references, [("reference", "full reference (please cite)")]))
        ks = sort(collect(keys(dict)))
        defDim(ds, table, length(ks))
        defVar(ds, table * "_key", ks, (table,); attrib=["units" => "1", "long_name" => "SUMup key"])
        for (var, long_name) in vars
            defVar(ds, var, [dict[k] for k in ks], (table,); deflatelevel=1, attrib=["long_name" => long_name])
        end
    end
    keys(references_short) == keys(references) || error("SUMup: reference_short and reference have different keys")
    defVar(ds, "reference_short", [references_short[k] for k in sort(collect(keys(references)))], ("reference_table",);
           attrib=["long_name" => "short reference"])
    ds.attrib["title"] = "Surface mass balance measurements of Greenland and Antarctica, SUMup 2025 (Vandecrux et al., 2025)"
    ds.attrib["references"] = "Vandecrux, B., Amory, C., Ahlstrøm, A. P., et al.: The SUMup collaborative database: " *
                              "Surface mass balance, subsurface temperature and density measurements from the " *
                              "Greenland and Antarctic ice sheets (2025 release), Arctic Data Center, 2025, " *
                              "doi:10.18739/A2M61BR5M. Please cite also the original data sources (reference)."
    ds.attrib["doi"] = "10.18739/A2M61BR5M"
    ds.attrib["license"] = "CC0 1.0 (Arctic Data Center)"
    ds.attrib["featureType"] = "point"
    ds.attrib["Conventions"] = "CF-1.11"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("smbobs"))
end
println("Wrote $path")
