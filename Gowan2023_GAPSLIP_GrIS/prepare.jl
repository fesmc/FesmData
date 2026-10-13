# Prepare the relative sea level indicators of Greenland in GAPSLIP (Gowan, 2023) as a
# record (see Records/README.md): the calibrated data of all Greenland locations of
# version 2.1 (datamanifest key gapslip_v2_1), one observation per dated sample
# (featureType point), $FESMDATA_PREPARED/Gowan2023_GAPSLIP_GrIS/GAPSLIP_Greenland.nc.
#
# Usage:
#     julia --project=Gowan2023_GAPSLIP_GrIS Gowan2023_GAPSLIP_GrIS/prepare.jl
#     julia fesmdata.jl record RSL GAPSLIP

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

dir = download_dataset(manifest(), "gapslip_v2_1")
repo = only(filter(d -> startswith(d, "evangowan-paleo_sea_level"), readdir(dir)))
greenland = joinpath(dir, repo, "sea_level_data", "Greenland")

# Locations and their sector (location_list.txt: location, sector, name, ...)
sector = Dict{String,String}()
for l in eachline(joinpath(greenland, "location_list.txt"))
    f = split(l, '\t')
    isempty(strip(f[1])) || (sector[f[1]] = f[2])
end
folders = filter(d -> isfile(joinpath(greenland, d, "calibrated.txt")), readdir(greenland))
Set(folders) == keys(sector) || error("$greenland: the locations with data differ from location_list.txt")

# <location>/calibrated.txt, written by the calibration script of GAPSLIP (one line per
# sample, tab separated): LAB_ID, latitude, longitude, age (cal yr BP, before 1950 CE:
# middle of the 2-sigma range), age uncertainty (half the 2-sigma range, years),
# indicator type (-1 marine limiting, 0 index point, 1 terrestrial limiting), RSL (m),
# upper and lower 2-sigma uncertainty of RSL (m), references.
obs = NamedTuple[]
for loc in sort(collect(keys(sector)))
    file = joinpath(greenland, loc, "calibrated.txt")
    isfile(file) || error("no $file")
    for l in eachline(file)
        isempty(strip(l)) && continue
        f = split(l, '\t')
        length(f) == 10 || error("$file: $(length(f)) columns instead of 10: $l")
        push!(obs, (lab_id=String(f[1]), lat=parse(Float64, f[2]), lon=parse(Float64, f[3]),
                    age=parse(Float64, f[4]), age_err=parse(Float64, f[5]), type=Int8(parse(Float64, f[6])),
                    rsl=parse(Float64, f[7]), rsl_upper=parse(Float64, f[8]), rsl_lower=parse(Float64, f[9]),
                    reference=String(f[10]), location=loc, sector=sector[loc]))
    end
end
all(o -> o.type in (-1, 0, 1), obs) || error("indicator types other than -1, 0, 1")
sort!(obs; by=o -> (o.location, o.age))
n = length(obs)
println("$n samples at $(length(sector)) locations")

col(name) = [o[name] for o in obs]

path = joinpath(prepared_dir("Gowan2023_GAPSLIP_GrIS"), "GAPSLIP_Greenland.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defDim(ds, "obs", n)
    attrib_obs(units, long_name) = ["units" => units, "long_name" => long_name, "coordinates" => "time lat lon"]
    defVar(ds, "lat", col(:lat), ("obs",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "lon", col(:lon), ("obs",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "time", col(:age), ("obs",); attrib=[
        "units" => "years ago", "long_name" => "time (years before 1950 CE)",
        "comment" => "calibrated age, middle of the 2-sigma range (radiocarbon ages calibrated with OxCal 4.4.4, " *
                     "IntCal20, SHCal20 and Marine20)"])
    defVar(ds, "time_min", col(:age) .- col(:age_err), ("obs",);
           attrib=["units" => "years ago", "long_name" => "lower end of the 2-sigma range of the age"])
    defVar(ds, "time_max", col(:age) .+ col(:age_err), ("obs",);
           attrib=["units" => "years ago", "long_name" => "upper end of the 2-sigma range of the age"])
    defVar(ds, "rsl", col(:rsl), ("obs",); attrib=attrib_obs("m", "relative sea level (indicator elevation " *
                                                                  "corrected for its indicative meaning)"))
    defVar(ds, "rsl_min", col(:rsl) .- col(:rsl_lower), ("obs",);
           attrib=attrib_obs("m", "lower end of the 2-sigma range of relative sea level"))
    defVar(ds, "rsl_max", col(:rsl) .+ col(:rsl_upper), ("obs",);
           attrib=attrib_obs("m", "upper end of the 2-sigma range of relative sea level"))
    defVar(ds, "type", col(:type), ("obs",); attrib=[
        "long_name" => "type of indicator", "flag_values" => Int8[-1, 0, 1],
        "flag_meanings" => "marine_limiting index_point terrestrial_limiting",
        "comment" => "marine limiting: sea level was above rsl_min; terrestrial limiting: sea level was below " *
                     "rsl_max; index point: sea level was in [rsl_min, rsl_max]"])
    defVar(ds, "lab_id", col(:lab_id), ("obs",); attrib=["long_name" => "laboratory identifier of the sample"])
    defVar(ds, "site_name", col(:location), ("obs",); attrib=["long_name" => "location (folder of GAPSLIP)"])
    defVar(ds, "sector", col(:sector), ("obs",); attrib=["long_name" => "sector of Greenland (GAPSLIP region)"])
    defVar(ds, "reference", col(:reference), ("obs",); attrib=["long_name" => "references (bibtex keys of GAPSLIP)"])
    ds.attrib["title"] = "Relative sea level indicators of Greenland, GAPSLIP 2.1 (Gowan, 2023)"
    ds.attrib["references"] = "Gowan, E. J.: Paleo sea-level indicators and proxies from Greenland in the GAPSLIP " *
                              "database and comparison with modelled sea level from the PaleoMIST ice-sheet " *
                              "reconstruction, GEUS Bulletin, 53, 2023, doi:10.34194/geusb.v53.8355. Data: Gowan, E. J.: " *
                              "evangowan/paleo_sea_level: Version 2.1, Zenodo, 2023, doi:10.5281/zenodo.10121689"
    ds.attrib["doi"] = "10.5281/zenodo.10121689"
    ds.attrib["license"] = "CC BY-SA 4.0 (LICENSE.txt of the repository; the Zenodo record states CC BY 4.0)"
    ds.attrib["featureType"] = "point"
    ds.attrib["Conventions"] = "CF-1.11"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("rsl"))
end
println("Wrote $path")
