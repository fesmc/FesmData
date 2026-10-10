# Prepare the ISMIP7 Antarctic ocean climatology for remapping: potential temperature,
# practical salinity and thermal forcing of the observational climatology of Zhou et al.
# (OCEAN ICE, "zhou_annual_06_nov", 1972-2024), extrapolated everywhere by ISMIP7, and
# the IMBIE2 basins extended into the ocean, on the ISMIP7 8 km grid (EPSG:3031) with
# 30 layers of 60 m, as $FESMDATA_WORK/prepared/Zhou2026_ismip7ocean/ISMIP7_OCEAN_1972-2024.nc.
#
# Usage:
#     julia --project=Zhou2026_ismip7ocean Zhou2026_ismip7ocean/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Zhou2026_ismip7ocean/ISMIP7_OCEAN_1972-2024.nc Antarctica

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

# Fields: name, datamanifest key, source name, units, long name
const FIELDS = [
    ("to", "ismip7_ais_ocean_thetao", "thetao", "degC", "sea water potential temperature"),
    ("so", "ismip7_ais_ocean_so", "so", "PSU", "sea water practical salinity"),
    ("tf", "ismip7_ais_ocean_tf", "tf", "degC",
     "thermal forcing: conservative temperature minus its freezing point (TEOS-10, no dissolved air)"),
]

# The 16 basins of ISMIP7 (IMBIE2 basins, E-Ep with Ep-F and J-Jpp with Jpp-K merged),
# numbered 0-15 in this order (i7aof.imbie.masks.BASIN_DEFINITIONS)
const BASINS = ["A-Ap", "Ap-B", "B-C", "C-Cp", "Cp-D", "D-Dp", "Dp-E", "E-F",
                "F-G", "G-H", "H-Hp", "Hp-I", "I-Ipp", "Ipp-J", "J-K", "K-A"]

const DB = manifest()

# Axes of a source file; all files must be on the same grid
axes_of(ds) = (x=Float64.(ds["x"][:]), y=Float64.(ds["y"][:]))

function main()
    ref = NCDataset(download_dataset(DB, "ismip7_ais_ocean_tf")) do ds
        (; axes_of(ds)..., z=Float64.(ds["z"][:]), z_bnds=Float64.(ds["z_bnds"][:, :]))
    end
    issorted(ref.x) && issorted(ref.y) || error("x and y of the source are not ascending")

    # 3D fields, Julia order (x, y, z)
    fields = map(FIELDS) do (name, key, src, units, long_name)
        NCDataset(download_dataset(DB, key)) do ds
            axes_of(ds) == (x=ref.x, y=ref.y) && ds["z"][:] == ref.z || error("$key: grid differs from tf")
            A = ds[src][:, :, :]
            (name=name, data=Float32.(coalesce.(A, NaN32)), units=units, long_name=long_name)
        end
    end

    basin = NCDataset(download_dataset(DB, "ismip7_ais_imbie_basins")) do ds
        axes_of(ds) == (x=ref.x, y=ref.y) || error("IMBIE basins: grid differs from tf")
        B = ds["basinNumber"][:, :]
        all(b -> 0 <= b < length(BASINS), B) || error("IMBIE basins: unexpected basin numbers $(unique(B))")
        Int32.(B)
    end

    path = joinpath(prepared_dir("Zhou2026_ismip7ocean"), "ISMIP7_OCEAN_1972-2024.nc")
    mkpath(dirname(path))
    NCDataset(path, "c") do ds
        defVar(ds, "x", ref.x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
        defVar(ds, "y", ref.y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
        defVar(ds, "z", ref.z, ("z",); attrib=["units" => "m", "standard_name" => "height", "positive" => "up",
               "long_name" => "height of the layer centre relative to sea level", "bounds" => "z_bnds"])
        defVar(ds, "z_bnds", ref.z_bnds, ("bnds", "z"); attrib=["units" => "m"])
        defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic",
                                                 "proj_params" => PROJ, "epsg_code" => "EPSG:3031"])
        for f in fields
            defVar(ds, f.name, f.data, ("x", "y", "z"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => f.units, "long_name" => f.long_name, "grid_mapping" => "crs"])
        end
        defVar(ds, "basin", basin, ("x", "y"); deflatelevel=1,
               attrib=["units" => "1", "long_name" => "IMBIE2 basin extended into the ocean (ISMIP7)",
                       "flag_values" => Int32.(0:length(BASINS)-1), "flag_meanings" => join(BASINS, " "),
                       "grid_mapping" => "crs"])
        ds.attrib["title"] = "ISMIP7 Antarctic ocean climatology 1972-2024 (Zhou et al., extrapolated by ISMIP7)"
        ds.attrib["references"] =
            "Zhou, S., Dutrieux, P., Giulivi, C., Meijers, A., Lee, W. S., Kim, T.-W., Hattermann, T. and " *
            "Janout, M.: The OCEAN ICE hydrography profiles compilation and climatology, Earth Syst. Sci. " *
            "Data Discuss., 2026, doi:10.5194/essd-2025-727; Reese, R., Jourdain, N. C., Asay-Davis, X. S. " *
            "et al.: A protocol for calibrating basal melt rates in the ISMIP7 Antarctic ice sheet " *
            "projections, EGUsphere, 2026, doi:10.5194/egusphere-2026-5337"
        ds.attrib["doi"] = "10.5194/essd-2025-727"
        ds.attrib["license"] = "No licence stated for the ISMIP7 forcing files; the OCEAN ICE climatology " *
                               "they are made from is CC BY 4.0 (SEANOE, doi:10.17882/103946)"
        ds.attrib["comment"] =
            "ISMIP7 files zhou_annual_06_nov thetao and so v4, tf v3, IMBIE-basins v3 (public HTTPS of the " *
            "ISMIP7 Globus endpoint), made with i7aof (github.com/ismip/ismip7-antarctic-ocean-forcing): the " *
            "climatology of conservative temperature and absolute salinity is extrapolated horizontally and " *
            "vertically into all cells (also under ice shelves and grounded ice and below the sea floor) and " *
            "averaged to 60 m layers; to and so are converted back with TEOS-10 (gsw.pt_from_CT, " *
            "gsw.SP_from_SA). No cell is missing. basin numbers 0-15 as in flag_meanings."
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ocean"))
    end
    println("Wrote $path")
end

main()
