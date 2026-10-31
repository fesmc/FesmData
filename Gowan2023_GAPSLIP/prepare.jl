# Prepare the relative sea level indicators of GAPSLIP (Gowan, 2023), the database used
# to evaluate PaleoMIST 1.0 (Gowan et al., 2021), as records (see Records/README.md): the
# calibrated data of every location listed in the regions of version 2.1 (datamanifest
# key gapslip_v2_1), one observation per dated sample (featureType point), in
# $FESMDATA_PREPARED/Gowan2023_GAPSLIP/:
#   GAPSLIP_global.nc    all regions (product RSL-GAPSLIP_global)
#   GAPSLIP_Greenland.nc the region Greenland, without the fields alternative, site and
#                        region (product RSL-GAPSLIP)
#
# Usage:
#     julia --project=Gowan2023_GAPSLIP Gowan2023_GAPSLIP/prepare.jl
#     julia fesmdata.jl record RSL

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const DATA_REF = "Gowan, E. J.: evangowan/paleo_sea_level: Version 2.1, Zenodo, 2023, doi:10.5281/zenodo.10121689"
const GEUS_REF = "Gowan, E. J.: Paleo sea-level indicators and proxies from Greenland in the GAPSLIP database and " *
                 "comparison with modelled sea level from the PaleoMIST ice-sheet reconstruction, GEUS Bulletin, 53, " *
                 "2023, doi:10.34194/geusb.v53.8355"
const PALEOMIST_REF = "Gowan, E. J. et al.: A new global ice sheet reconstruction for the past 80000 years, " *
                      "Nat. Commun., 12, 1199, 2021, doi:10.1038/s41467-021-21469-w"

dir = download_dataset(manifest(), "gapslip_v2_1")
repo = only(filter(d -> startswith(d, "evangowan-paleo_sea_level"), readdir(dir)))
data = joinpath(dir, repo, "sea_level_data")

# The regions (region_list.txt), without Proxy_Based_Sea_Level: sea level from d18O
# proxies, which GAPSLIP keeps apart from the indicators.
regions = filter(r -> !isempty(r) && r != "Proxy_Based_Sea_Level", strip.(readlines(joinpath(data, "region_list.txt"))))

# <region>/location_list.txt (tab separated): location (folder), sector, site, and the
# names of the plots (LaTeX, GMT). A location whose site differs from its own name is an
# alternative of the data of that site: another interpretation (Bonaparte Gulf, Sahul
# Shelf, Huon Peninsula) or another uplift correction (Kikaijima).
# <location>/calibrated.txt, written by the calibration script of GAPSLIP (one line per
# sample, tab separated): LAB_ID, latitude, longitude, age (cal yr BP, before 1950 CE:
# middle of the 2-sigma range), age uncertainty (half the 2-sigma range, years),
# indicator type (-1 marine limiting, 0 index point, 1 terrestrial limiting), RSL (m),
# upper and lower 2-sigma uncertainty of RSL (m), references.
obs = NamedTuple[]
nloc = 0
for region in regions
    rdir = joinpath(data, region)
    listed = String[]
    for l in eachline(joinpath(rdir, "location_list.txt"))
        f = split(l, '\t')
        isempty(strip(f[1])) && continue
        loc, sector, site = String.(strip.(f[1:3]))
        push!(listed, loc)
        file = joinpath(rdir, loc, "calibrated.txt")
        isfile(file) || error("$region/$loc is listed but has no calibrated.txt")
        global nloc += 1
        for s in eachline(file)
            isempty(strip(s)) && continue
            c = split(s, '\t')
            length(c) == 10 || error("$file: $(length(c)) columns instead of 10: $s")
            push!(obs, (lab_id=String(c[1]), lat=parse(Float64, c[2]), lon=parse(Float64, c[3]),
                        age=parse(Float64, c[4]), age_err=parse(Float64, c[5]), type=Int8(parse(Float64, c[6])),
                        rsl=parse(Float64, c[7]), rsl_upper=parse(Float64, c[8]), rsl_lower=parse(Float64, c[9]),
                        reference=String(c[10]), location=loc, site=site, alternative=Int8(loc != site),
                        sector=sector, region=String(region)))
        end
    end
    unlisted = setdiff(filter(d -> isfile(joinpath(rdir, d, "calibrated.txt")), readdir(rdir)), listed)
    isempty(unlisted) || println("$region: not in location_list.txt, left out: $(join(unlisted, ", "))")
end
all(o -> o.type in (-1, 0, 1), obs) || error("indicator types other than -1, 0, 1")
sort!(obs; by=o -> (o.region, o.location, o.age))
println("$(length(obs)) samples at $nloc locations in $(length(regions)) regions")

# A record file of the samples obs; with_region: also the fields alternative, site, region.
function write_gapslip(path, obs; with_region::Bool, title, references, sector_long_name)
    n = length(obs)
    col(name) = [o[name] for o in obs]
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
        with_region && defVar(ds, "alternative", col(:alternative), ("obs",); attrib=[
            "long_name" => "alternative of the data of another location of the same site", "flag_values" => Int8[0, 1],
            "flag_meanings" => "primary alternative",
            "comment" => "1: the location is another interpretation or uplift correction of the samples of `site` " *
                         "(location_list.txt of GAPSLIP); use the primary data (0) to count each sample once"])
        defVar(ds, "lab_id", col(:lab_id), ("obs",); attrib=["long_name" => "laboratory identifier of the sample"])
        defVar(ds, "site_name", col(:location), ("obs",); attrib=["long_name" => "location (folder of GAPSLIP)"])
        with_region && defVar(ds, "site", col(:site), ("obs",);
                              attrib=["long_name" => "site of the location (GAPSLIP location_list.txt)"])
        defVar(ds, "sector", col(:sector), ("obs",); attrib=["long_name" => sector_long_name])
        with_region && defVar(ds, "region", col(:region), ("obs",);
                              attrib=["long_name" => "region (GAPSLIP sea_level_data folder)"])
        defVar(ds, "reference", col(:reference), ("obs",); attrib=["long_name" => "references (bibtex keys of GAPSLIP)"])
        ds.attrib["title"] = title
        ds.attrib["references"] = references
        ds.attrib["doi"] = "10.5281/zenodo.10121689"
        ds.attrib["license"] = "CC BY-SA 4.0 (LICENSE.txt of the repository; the Zenodo record states CC BY 4.0)"
        ds.attrib["featureType"] = "point"
        ds.attrib["Conventions"] = "CF-1.11"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("rsl"))
    end
    println("Wrote $path: $n samples")
end

out = prepared_dir("Gowan2023_GAPSLIP")
write_gapslip(joinpath(out, "GAPSLIP_global.nc"), obs; with_region=true,
              title="Relative sea level indicators, all regions of GAPSLIP 2.1 (Gowan, 2023)",
              references="$GEUS_REF; $PALEOMIST_REF. Data: $DATA_REF",
              sector_long_name="sector of the region (GAPSLIP location_list.txt)")
write_gapslip(joinpath(out, "GAPSLIP_Greenland.nc"), filter(o -> o.region == "Greenland", obs); with_region=false,
              title="Relative sea level indicators of Greenland, GAPSLIP 2.1 (Gowan, 2023)",
              references="$GEUS_REF. Data: $DATA_REF",
              sector_long_name="sector of Greenland (GAPSLIP region)")
