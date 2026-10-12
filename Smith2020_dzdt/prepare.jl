# Prepare the ICESat to ICESat-2 height and thickness change rates 2003-2019 of Smith et
# al. (2020) for remapping (GeoTIFFs at 5 km, datamanifest key smith2020_dhdt), on their
# own grids, to $FESMDATA_WORK/prepared/Smith2020_dzdt/:
#
#   Smith2020_GRL.nc           dzdt of the grounded ice of Greenland (EPSG:3413)
#   Smith2020_ANT.nc           dzdt and dHdt of the grounded ice of Antarctica (EPSG:3031)
#   Smith2020_ANT_floating.nc  dHdt of the floating ice of Antarctica (its own grid)
#
# dzdt is the surface height change rate (the unfiltered `dhdt` grids, grounded ice only:
# over floating ice the grids give thickness changes), dHdt the ice thickness change rate
# in ice equivalent (the unfiltered `dmdt` grids, corrected for firn air content; over
# floating ice converted from height change by hydrostatic equilibrium). Greenland has no
# dHdt (its `dmdt` grid is the `dhdt` grid, without firn correction).
#
# Usage:
#     julia --project=Smith2020_dzdt Smith2020_dzdt/prepare.jl
#     julia fesmdata.jl remap IceChange Smith2020-ANT Smith2020-GRL
#
# The two files of Antarctica (same title) make one product, Smith2020-ANT (see
# ../IceChange/remap.toml): remapping combines dHdt of the grounded and floating ice.

using NCDatasets
import ArchGDAL as AG

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "smith2020_dhdt"
const ARCHIVE = "ICESat1_ICESat2_mass_change_updated_2_2021"

const PROJ = Dict("EPSG:3031" => "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs",
                  "EPSG:3413" => "+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs")

const FIELDS = Dict(
    "dzdt" => ["units" => "m yr-1", "long_name" => "surface elevation change rate, 2003-2019"],
    "dHdt" => ["units" => "m yr-1", "long_name" => "ice thickness change rate (ice equivalent), 2003-2019",
               "standard_name" => "tendency_of_land_ice_thickness"])

"""
    read_tif(path) -> (x, y, proj, A)

Cell centres (m, ascending), PROJ string (m) and band 1 (Float32, NaN for no data) of a
north-up GeoTIFF.
"""
function read_tif(path)
    AG.read(path) do ds
        x0, dx, rx, y0, ry, dy = AG.getgeotransform(ds)
        (rx == 0 && ry == 0 && dy < 0) || error("$path: not a north-up grid")
        nx, ny = AG.width(ds), AG.height(ds)
        x = x0 .+ dx .* ((1:nx) .- 0.5)
        y = reverse(y0 .+ dy .* ((1:ny) .- 0.5))
        proj = strip(AG.toPROJ4(AG.importWKT(AG.getproj(ds))))
        b = AG.getband(ds, 1)
        nd = AG.getnodatavalue(b)
        A = reverse(AG.read(b); dims=2)
        return collect(x), collect(y), proj, map(v -> v == nd || !isfinite(v) ? NaN32 : Float32(v), A)
    end
end

"Read the GeoTIFFs `files` (by field name), checking that they share their grid and projection `epsg`."
function read_fields(dir, files, epsg)
    grid = nothing
    fields = Pair{String,Matrix{Float32}}[]
    for (name, file) in files
        x, y, proj, A = read_tif(joinpath(dir, file))
        proj == PROJ[epsg] || error("$file: projection $proj, expected $epsg ($(PROJ[epsg]))")
        grid === nothing && (grid = (x, y))
        grid == (x, y) || error("$file: not on the grid of $(first(files)[2])")
        push!(fields, name => A)
    end
    return grid..., fields
end

function write_prepared(path, x, y, epsg, fields, title, comment)
    isfile(path) && rm(path)
    NCDataset(path, "c") do ds
        defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
        defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
        defVar(ds, "crs", Int32(0), (); attrib=["proj_params" => PROJ[epsg], "epsg_code" => epsg])
        for (name, A) in fields
            defVar(ds, name, A, ("x", "y"); fillvalue=NaN32, deflatelevel=1,
                   attrib=[FIELDS[name]; "grid_mapping" => "crs"])
        end
        ds.attrib["title"] = title
        ds.attrib["references"] = "Smith, B., Fricker, H. A., Gardner, A. S., Medley, B., Nilsson, J., Paolo, F. S., " *
                                  "Holschuh, N., Adusumilli, S., Brunt, K., Csatho, B., Harbeck, K., Markus, T., " *
                                  "Neumann, T., Siegfried, M. R. and Zwally, H. J.: Pervasive ice sheet mass loss " *
                                  "reflects competing ocean and atmosphere processes, Science, 368(6496), 1239-1242, " *
                                  "doi:10.1126/science.aaz5845, 2020. Data: Ice-sheet height and thickness changes " *
                                  "from ICESat to ICESat-2, University of Washington ResearchWorks, " *
                                  "http://hdl.handle.net/1773/45388 (archive $ARCHIVE)"
        ds.attrib["doi"] = "10.1126/science.aaz5845"
        ds.attrib["license"] = "CC BY 3.0 US"
        ds.attrib["comment"] = comment
        ds.attrib["time_coverage_start"] = "2003"
        ds.attrib["time_coverage_end"] = "2019"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icechange"))
    end
    println("Wrote $path")
end

db = manifest()
root = get_dataset_path(db, KEY)
isdir(root) || (root = download_dataset(db, KEY))
dir = joinpath(root, ARCHIVE)
isdir(dir) || error("$dir not found: unexpected content of the archive")
out = prepared_dir("Smith2020_dzdt")
mkpath(out)

const TITLE_ANT = "Antarctic surface elevation and ice thickness change rates 2003-2019, ICESat to ICESat-2 (Smith et al., 2020)"
const SOURCE = "Unfiltered grids of the archive (not the _filt grids, smoothed for display)"

x, y, fields = read_fields(dir, ["dzdt" => "dhdt/gris_dhdt.tif"], "EPSG:3413")
write_prepared(joinpath(out, "Smith2020_GRL.nc"), x, y, "EPSG:3413", fields,
               "Greenland surface elevation change rate 2003-2019, ICESat to ICESat-2 (Smith et al., 2020)",
               "$SOURCE: dzdt from dhdt/gris_dhdt.tif, grounded ice. No firn air correction exists for " *
               "Greenland (dmdt/gris_dmdt.tif is identical to dhdt/gris_dhdt.tif), so there is no dHdt")

x, y, fields = read_fields(dir, ["dzdt" => "dhdt/ais_dhdt_grounded.tif", "dHdt" => "dmdt/ais_dmdt_grounded.tif"], "EPSG:3031")
write_prepared(joinpath(out, "Smith2020_ANT.nc"), x, y, "EPSG:3031", fields,
               TITLE_ANT,
               "$SOURCE: dzdt from dhdt/ais_dhdt_grounded.tif (surface height change rate), dHdt from " *
               "dmdt/ais_dmdt_grounded.tif (corrected for changes in firn air content), grounded ice only")

x, y, fields = read_fields(dir, ["dHdt" => "dmdt/ais_dmdt_floating.tif"], "EPSG:3031")
write_prepared(joinpath(out, "Smith2020_ANT_floating.nc"), x, y, "EPSG:3031", fields,
               TITLE_ANT,
               "dHdt from dmdt/ais_dmdt_floating.tif (unfiltered), floating ice only: surface height change rates " *
               "corrected for changes in firn air content and converted to thickness change rates by hydrostatic " *
               "equilibrium. Its grid (5000.01 m x 5001.19 m as given in the GeoTIFF) is not the grid of the grounded ice")
