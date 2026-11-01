# Prepare the equivalent sea level of the ice sheets of PaleoMIST 1.0 (Gowan et al., 2021)
# as records (see Records/README.md): the change of the ice volume from the present of each
# ice sheet, from the gridded ice thickness of the reconstruction (the global 0.25° grids of
# the PANGAEA archive, datamanifest key gowan2021_paleomist, the ice thickness of
# IceHistory-PaleoMIST), every 2.5 kyr from 80 ka to present, for the two scenarios, as
# global series (featureType timeSeries):
# $FESMDATA_PREPARED/Gowan2021_PaleoMIST_esl/Gowan2021_PaleoMIST_esl.nc and
# Gowan2021_PaleoMIST_max_esl.nc.
#
# The volume series of the archive (ice_reconstruction_files/<region>/volume_sorted.txt,
# the same as Supplementary Table 1 of the paper) are not used: they are lower than the
# ice thickness grids of the archive, regional (5 km) and global, by 3.7e6 km3 at 22.5 ka
# (Antarctica: 4.0 against 6.5e6 km3), while Gowan's calculated eustatic sea level (calc_sl,
# run_eus.sh, the ESL column of Supplementary Table 1) agrees with the grids (see README.md).
#
# Usage:
#     julia --project=Gowan2021_PaleoMIST_esl Gowan2021_PaleoMIST_esl/prepare.jl
#     julia fesmdata.jl record SeaLevel PaleoMIST PaleoMIST_max

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

# Scenarios: prepared file, suffix of the files of the archive ("" or "_a1"), description
const SCENARIOS = [
    ("Gowan2021_PaleoMIST_esl.nc", "", "minimal MIS 3 scenario for North America (ice-free Hudson Bay at times)"),
    ("Gowan2021_PaleoMIST_max_esl.nc", "_a1", "maximal MIS 3 scenario for North America (ice over Hudson Bay throughout MIS 3)"),
]

# Equivalent sea level as in Gowan et al. (2021): ice volume x ice density / water density,
# spread over the present ocean area (SELEN's RHOI, RHOW of the archive's calc_sl/data.inc)
const RHO_ICE = 910.0           # kg m-3
const RHO_WATER = 1000.0        # kg m-3
const OCEAN_AREA = 361e12       # m2
const RADIUS = 6371.0e3         # m, sphere of the cell areas (about the authalic radius of WGS84)

# Ice sheets: the regional reconstructions of the archive (ice_reconstruction_files/<region>),
# name of the contribution, description, and the cells of the global grid given to it (after
# the domains of the regional grids, projection_info.sh; see `sheet`)
const SHEETS = [("North_America", "sl_nam", "North America (with Greenland and Iceland)",
                 "north of 35N, from 180 to 14W (10W north of 62N)"),
                ("Eurasia", "sl_eis", "Eurasia", "north of 35N, from 14W (10W north of 62N) to 180"),
                ("Antarctica", "sl_ais", "Antarctica", "south of 45S, outside Patagonia"),
                ("Patagonia", "sl_pat", "Patagonia", "80W to 60W, 57S to 25S")]

"Ice sheet (index into SHEETS, 0 for none) of the cell at (lon, lat): no ice sheet between 25S (45S outside Patagonia) and 35N."
function sheet(lon, lat)
    lon = mod(lon + 180, 360) - 180
    (-80 < lon < -60 && -57 < lat < -25) && return 4
    lat < -45 && return 3
    lat < 35 && return 0
    return lon < (lat < 62 ? -14.0 : -10.0) ? 1 : 2
end

"Area (m2) of a cell of the gridline-registered grid of spacing `d` (degrees) centred at `lat`."
cellarea(lat, d) = RADIUS^2 * deg2rad(d) * (sind(min(lat + d / 2, 90)) - sind(max(lat - d / 2, -90)))

"""
    sheet_volumes(path) -> (ages, V)

Ice volume (m3) of each ice sheet of SHEETS (columns) at each age (years before 1950,
ascending) of the global grids of the archive, and of the ice outside them (last column).
As in IceHistory-PaleoMIST: the column at 180° (repeating -180°) is left out and the
negative ice thickness left by the smoothing of the author set to 0.
"""
function sheet_volumes(path)
    NCDataset(path) do ds
        lon, lat, t = Float64.(ds["lon"].var[:]), Float64.(ds["lat"].var[:]), Float64.(ds["time"].var[:])
        (lon[1] == -180 && lon[end] == 180) || error("$path: unexpected longitudes $(lon[1]):$(lon[end])")
        d = lon[2] - lon[1]
        nx = length(lon) - 1
        v = ds["ice_thickness"]
        dimnames(v) == ("lon", "lat", "time") || error("$path: unexpected dimensions of ice_thickness")
        H = max.(Float64.(v.var[1:nx, :, :]), 0.0)
        any(isnan, H) && error("$path: missing values in ice_thickness")
        A = [cellarea(lat[j], d) for i in 1:nx, j in eachindex(lat)]
        s = [sheet(lon[i], lat[j]) for i in 1:nx, j in eachindex(lat)]
        n = length(SHEETS)
        V = zeros(length(t), n + 1)
        for k in eachindex(t), j in eachindex(lat), i in 1:nx
            c = s[i, j] == 0 ? n + 1 : s[i, j]
            V[k, c] += A[i, j] * H[i, j, k]
        end
        ages = 0.0 .- t                                     # years before 1950 (no -0.0)
        p = sortperm(ages)
        return ages[p], V[p, :]
    end
end

"Sea level relative to the present (m) of the ice volumes V (m3): minus the change of their equivalent sea level."
sealevel(V, k0) = (V[k0:k0, :] .- V) .* (RHO_ICE / RHO_WATER) ./ OCEAN_AREA

root = joinpath(download_dataset(manifest(), "gowan2021_paleomist"), "ice_reconstruction")

for (file, suffix, scenario) in SCENARIOS
    src = joinpath(root, "global_grid", "reconstruction$(suffix)_0.25_degree.nc")
    ages, V = sheet_volumes(src)
    k0 = findfirst(==(0.0), ages)
    k0 === nothing && error("$src: no present (0 ka)")
    sl = sealevel(V, k0)
    # The ice sheets hold all the ice: the change outside them must be negligible
    outside = maximum(abs, sl[:, end])
    outside < 0.01 || error("$src: the ice outside the ice sheets changes sea level by $(outside) m")
    method = "equivalent sea level of the change of the ice volume from the present: total ice volume (not above " *
             "flotation) from the gridded ice thickness (global_grid/$(basename(src)), as IceHistory-PaleoMIST; cell areas " *
             "on a sphere of radius 6371 km), x 910/1000 (ice and water densities) / 361e6 km2 (present ocean area), as " *
             "Gowan et al. (2021); not from volume_sorted.txt or Supplementary Table 1 of the paper (volume), which are " *
             "lower than the gridded ice (Antarctica)"
    write_series(joinpath(prepared_dir("Gowan2021_PaleoMIST_esl"), file); tag="sealevel",
        sites=[Region("global")], instance="region", time=ages,
        time_comment="every 2.5 kyr, years before present (1950 CE)",
        vars=[Var("sl", vec(sum(sl[:, 1:end-1]; dims=2)), "m",
                  "sea level relative to the present from the ice sheets (sum of the contributions), $scenario";
                  attrib=["comment" => method]);
              [Var(name, sl[:, k], "m", "contribution of $desc to sea level relative to the present (minus the change " *
                                        "of its equivalent sea level)"; attrib=["comment" => "$method; grid cells $cells"])
               for (k, (_, name, desc, cells)) in enumerate(SHEETS)]],
        title="Sea level from the ice sheets of PaleoMIST 1.0, $scenario (Gowan et al., 2021)",
        references="Gowan, E. J., Zhang, X., Khosravi, S., Rovere, A., Stocchi, P., Hughes, A. L. C., Gyllencreutz, R., " *
                   "Mangerud, J., Svendsen, J.-I., and Lohmann, G.: A new global ice sheet reconstruction for the past " *
                   "80 000 years, Nat. Commun., 12, 1199, 2021, doi:10.1038/s41467-021-21469-w. Data: PANGAEA, " *
                   "doi:10.1594/PANGAEA.905800 (global_grid/$(basename(src)), ice_thickness)",
        doi="10.1594/PANGAEA.905800", license="CC BY 4.0 (PANGAEA)")
end
