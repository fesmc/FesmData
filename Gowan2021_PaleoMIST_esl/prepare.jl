# Prepare the equivalent sea level of the ice sheets of PaleoMIST 1.0 (Gowan et al., 2021)
# as records (see Records/README.md): the ice volume series of the regional
# reconstructions in the PANGAEA archive (datamanifest key gowan2021_paleomist, the same
# archive as IceHistory-PaleoMIST), every 2.5 kyr from 80 ka to present, for the two
# scenarios, as global series (featureType timeSeries):
# $FESMDATA_PREPARED/Gowan2021_PaleoMIST_esl/Gowan2021_PaleoMIST_esl.nc and
# Gowan2021_PaleoMIST_max_esl.nc.
#
# Usage:
#     julia --project=Gowan2021_PaleoMIST_esl Gowan2021_PaleoMIST_esl/prepare.jl
#     julia fesmdata.jl record SeaLevel PaleoMIST PaleoMIST_max

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

# Scenarios: prepared file, suffix of the regional folders ("" or "_a1"), description
const SCENARIOS = [
    ("Gowan2021_PaleoMIST_esl.nc", "", "minimal MIS 3 scenario for North America (ice-free Hudson Bay at times)"),
    ("Gowan2021_PaleoMIST_max_esl.nc", "_a1", "maximal MIS 3 scenario for North America (ice over Hudson Bay throughout MIS 3)"),
]
# Regions (folders of ice_reconstruction_files) => name of the contribution
const REGIONS = ["North_America" => "sl_nam", "Eurasia" => "sl_eis", "Antarctica" => "sl_ais", "Patagonia" => "sl_pat"]

root = joinpath(download_dataset(manifest(), "gowan2021_paleomist"), "ice_reconstruction", "ice_reconstruction_files")

for (file, suffix, scenario) in SCENARIOS
    # volume_sorted.txt: age (years BP), ice volume (km3), (1e6 km3), equivalent sea level
    # (m, ocean area 361e6 km2, ice density 910 kg m-3), each relative to the present
    tables = [read_columns(joinpath(root, region * suffix, "volume_sorted.txt"), ["age", "V", "V6", "esl"]; skipto=1)
              for (region, _) in REGIONS]
    age = nan64(column(tables[1], "age"))
    all(t -> nan64(column(t, "age")) == age, tables) || error("$root: the regions have different ages")
    sl = [.-nan64(column(t, "esl")) for t in tables]
    write_series(joinpath(prepared_dir("Gowan2021_PaleoMIST_esl"), file); tag="sealevel",
        sites=[Region("global")], instance="region", time=age,
        time_comment="every 2.5 kyr, years before present (1950 CE)",
        vars=[Var("sl", sum(sl), "m",
                  "sea level relative to the present from the ice sheets (sum of the contributions; ocean area 361e6 km2, " *
                  "ice density 910 kg m-3), $scenario");
              [Var(name, sl[k], "m", "contribution of $(replace(region, "_" => " ")) to sea level relative to the present " *
                                     "(minus its equivalent sea level)" * (region == "North_America" ? ", with Greenland" : ""))
               for (k, (region, name)) in enumerate(REGIONS)]],
        title="Sea level from the ice sheets of PaleoMIST 1.0, $scenario (Gowan et al., 2021)",
        references="Gowan, E. J., Zhang, X., Khosravi, S., Rovere, A., Stocchi, P., Hughes, A. L. C., Gyllencreutz, R., " *
                   "Mangerud, J., Svendsen, J.-I., and Lohmann, G.: A new global ice sheet reconstruction for the past " *
                   "80 000 years, Nat. Commun., 12, 1199, 2021, doi:10.1038/s41467-021-21469-w. Data: PANGAEA, " *
                   "doi:10.1594/PANGAEA.905800 (ice_reconstruction_files/<region>/volume_sorted.txt)",
        doi="10.1594/PANGAEA.905800", license="CC BY 4.0 (PANGAEA)")
end
