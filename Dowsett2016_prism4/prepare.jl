# Prepare the PRISM4 / PlioMIP2 boundary conditions (Dowsett et al., 2016) for remapping:
# the Pliocene topography and ice mask of the enhanced and standard experiments and the
# modern topography (for anomalies), on their 1° grid, as one prepared NetCDF file,
# $FESMDATA_WORK/prepared/Dowsett2016_prism4/Dowsett2016_PRISM4.nc.
#
# Usage:
#     julia --project=Dowsett2016_prism4 Dowsett2016_prism4/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Dowsett2016_prism4/Dowsett2016_PRISM4.nc all

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

function original_dir(key)
    db = manifest()
    path = get_dataset_path(db, key)
    ispath(path) && return path
    return download_dataset(db, key)
end

# name => (manifest key, file in the archive, field)
const SOURCES = [
    "z_topo_enh" => ("prism4_plio_enh", "Plio_enh/Plio_enh_topo_v1.0.nc", "p4_topo"),
    "z_topo_std" => ("prism4_plio_std", "Plio_std/Plio_std_topo_v1.0.nc", "P4topo_ModLsm"),
    "z_topo_mod" => ("prism4_modern_std", "Modern_std/Modern_std_topo_v1.0.nc", "etopo1_topo"),
    "mask_enh" => ("prism4_plio_enh", "Plio_enh/Plio_enh_icemask_v1.0.nc", "P4_icemask"),
    "mask_std" => ("prism4_plio_std", "Plio_std/Plio_std_icemask_v1.0.nc", "P4_icemask"),
]

const LONG_NAMES = Dict(
    "z_topo_enh" => "topography (surface elevation, sea floor in the ocean), Pliocene, enhanced (Plio_enh)",
    "z_topo_std" => "topography (surface elevation, sea floor in the ocean), Pliocene with the " *
                    "modern land-sea mask, standard (Plio_std)",
    "z_topo_mod" => "topography (surface elevation, sea floor in the ocean), modern (ETOPO1, Modern_std)",
    "mask_enh" => "surface type, Pliocene, enhanced (Plio_enh)",
    "mask_std" => "surface type, Pliocene with the modern land-sea mask, standard (Plio_std)",
)

# All files are on the same grid: lon -179.5:179.5, lat -89.5:89.5 (cell centres)
function read_source(key, file, field)
    path = joinpath(original_dir(key), file)
    return NCDataset(path) do ds
        Float64.(ds["lon"].var[:]), Float64.(ds["lat"].var[:]), ds[field].var[:, :]
    end
end

lon, lat = read_source(SOURCES[1][2]...)[1:2]
fields = Dict{String,Array}()
for (name, src) in SOURCES
    x, y, A = read_source(src...)
    (x == lon && y == lat) || error("$(src[2]) is not on the grid of $(SOURCES[1][2][2])")
    if startswith(name, "mask")
        # Ocean 0, land 1, ice 2. The files flag 0 as missing_value: read raw values.
        all(in((0, 1, 2)), A) || error("$(src[2]): unexpected mask values")
        fields[name] = Int32.(A)
    else
        # missing_value -9999 (topo) or NaN (Plio_std topo)
        B = Float32.(A)
        B[B .== -9999] .= NaN32
        fields[name] = B
    end
end

path = joinpath(prepared_dir("Dowsett2016_prism4"), "Dowsett2016_PRISM4.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, _) in SOURCES
        if startswith(name, "mask")
            defVar(ds, name, fields[name], ("lon", "lat"); deflatelevel=1,
                   attrib=["units" => "1", "long_name" => LONG_NAMES[name],
                           "flag_values" => Int32[0, 1, 2], "flag_meanings" => "ocean land ice"])
        else
            defVar(ds, name, fields[name], ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => "m", "long_name" => LONG_NAMES[name]])
        end
    end
    ds.attrib["title"] = "PRISM4 mid-Piacenzian (Pliocene) topography and ice sheets, PlioMIP2 " *
                         "boundary conditions (Dowsett et al., 2016)"
    ds.attrib["references"] = "Dowsett, H., Dolan, A., Rowley, D., Moucha, R., Forte, A. M., " *
                              "Mitrovica, J. X., Pound, M., Salzmann, U., Robinson, M., Chandler, M., " *
                              "Foley, K., and Haywood, A.: The PRISM4 (mid-Piacenzian) " *
                              "paleoenvironmental reconstruction, Clim. Past, 12, 1519-1538, 2016; " *
                              "Haywood, A. M., et al.: The Pliocene Model Intercomparison Project " *
                              "(PlioMIP) Phase 2: scientific objectives and experimental design, " *
                              "Clim. Past, 12, 663-675, 2016, doi:10.5194/cp-12-663-2016"
    ds.attrib["doi"] = "10.5194/cp-12-1519-2016"
    ds.attrib["license"] = "Public domain (U.S. Geological Survey, " *
                           "https://geology.er.usgs.gov/egpsc/prism/); no licence stated in the files"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
end
println("Wrote $path")
