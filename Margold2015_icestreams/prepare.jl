# Prepare the ice streams of the Laurentide Ice Sheet (Margold et al., 2015) with the timing
# of their activity (Stokes et al., 2016) for remapping: the stream outlines rasterized on a
# 1 km polar stereographic grid (the projection and extent of the North domain), in one
# prepared NetCDF file, $FESMDATA_PREPARED/Margold2015_icestreams/Margold2015_ICESTREAMS.nc,
# with f_stream, f_stream_lgm, age_stream_start and age_stream_end.
#
# Usage:
#     julia -t 8 --project=Margold2015_icestreams Margold2015_icestreams/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_PREPARED/Margold2015_icestreams/Margold2015_ICESTREAMS.nc Laurentide

using FesmUtils
using NCDatasets
using XLSX
import ArchGDAL as AG
import GeoInterface as GI
import Proj

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "margold2015_icestreams"
const STOKES = joinpath(@__DIR__, "..", "Stokes2016_icestreams", "41586_2016_BFnature16947_MOESM67_ESM.xlsx")

# Grid: the projection of the North domain (shared/domains.toml), 1 km cells whose edges
# are on the edges of the North grids, covering all grids of the North domain (whose
# first coarse cells reach up to 15 km beyond the base grid).
const PROJ = "+proj=stere +lat_0=90 +lat_ts=70 +lon_0=-45 +x_0=0 +y_0=0 +a=6378137 +rf=298.25722356 +units=km"
const XEDGES = (-4917.0, 3901.0)
const YEDGES = (-5417.0, 3401.0)
const DX = 1.0
const NSUB = 4                          # samples per cell side (250 m)

# Stokes et al. (2016): the LGM is the start of their chronology, 21.8 cal ka BP
const AGE_LGM = 21_800.0

"""
    stream_ages(path) -> Dict(id => (start, end))

Best-estimate start and end of the activity of each ice stream (years before 1950), from
the source data of Fig. 1 and 2 of Stokes et al. (2016) (columns B-I: ID, name, earliest,
best and latest start, earliest, best and latest end, in cal kyr BP). Streams dated only
as pre-LGM have no ages. A stream with two phases of activity (two rows) gets the start
of the first and the end of the last.
"""
function stream_ages(path)
    ages = Dict{Int,Tuple{Float64,Float64}}()
    sheet = XLSX.readxlsx(path)["Fig. 1 & 2"]
    for row in 3:sheet.dimension.stop.row_number
        id = sheet[row, 2]
        id isa Real || continue
        id = Int(id)
        s, e = sheet[row, 5], sheet[row, 8]
        (s isa Real && e isa Real) || continue
        s, e = 1000.0 * s, 1000.0 * e
        if haskey(ages, id)
            s0, e0 = ages[id]
            s, e = max(s, s0), min(e, e0)
        end
        ages[id] = (s, e)
    end
    return ages
end

"Outlines (rings in the coordinates of the grid, km) and IDs of the ice-stream polygons."
function read_streams(path)
    streams = Tuple{Int,Vector{Vector{NTuple{2,Float64}}}}[]
    AG.read(path) do ds
        layer = AG.getlayer(ds, 0)
        to_grid = Proj.Transformation(AG.toWKT(AG.getspatialref(layer)), PROJ; always_xy=true)
        for f in layer
            id = parse(Int, AG.getfield(f, "Stable_ID"))
            g = AG.getgeom(f)
            parts = GI.geomtrait(g) isa GI.MultiPolygonTrait ? collect(GI.getgeom(g)) : [g]
            rings = [[NTuple{2,Float64}(to_grid((GI.x(q), GI.y(q)))) for q in GI.getpoint(r)]
                     for p in parts for r in GI.getgeom(p)]
            push!(streams, (id, rings))
        end
    end
    return streams
end

g = ProjGrid("Margold2015", (XEDGES[1] + DX / 2, XEDGES[2] - DX / 2), (YEDGES[1] + DX / 2, YEDGES[2] - DX / 2), DX, PROJ)
nx, ny = size(g)
d = DX / NSUB

streams = read_streams(joinpath(download_dataset(manifest(), KEY), "IS_polygons.shp"))
ages = stream_ages(STOKES)

# Samples inside any stream and any stream active at the LGM, and the ages of each cell
# covered by a stream (oldest start and youngest end of the streams covering it)
inside = falses(nx * NSUB, ny * NSUB)
inside_lgm = falses(nx * NSUB, ny * NSUB)
age_start = fill(NaN32, nx, ny)
age_end = fill(NaN32, nx, ny)
nlgm = 0
for (id, rings) in streams
    pts = reduce(vcat, rings)
    all(p -> XEDGES[1] <= p[1] <= XEDGES[2] && YEDGES[1] <= p[2] <= YEDGES[2], pts) ||
        error("ice stream $id outside the grid")
    # Cells of the bounding box of the stream, and their samples
    i0, i1 = floor(Int, (minimum(first, pts) - XEDGES[1]) / DX) + 1, ceil(Int, (maximum(first, pts) - XEDGES[1]) / DX)
    j0, j1 = floor(Int, (minimum(last, pts) - YEDGES[1]) / DX) + 1, ceil(Int, (maximum(last, pts) - YEDGES[1]) / DX)
    i0, j0, i1, j1 = max(i0, 1), max(j0, 1), min(i1, nx), min(j1, ny)
    sg = ProjGrid("stream", XEDGES[1] + (i0 - 1) * DX + d / 2 .+ d .* (0:(i1-i0+1)*NSUB-1),
                  YEDGES[1] + (j0 - 1) * DX + d / 2 .+ d .* (0:(j1-j0+1)*NSUB-1), PROJ)
    mask = rasterize!(zeros(Bool, size(sg)), sg, rings)
    is = (i0-1)*NSUB+1:i1*NSUB
    js = (j0-1)*NSUB+1:j1*NSUB
    inside[is, js] .|= mask
    a = get(ages, id, nothing)
    if a !== nothing && a[1] >= AGE_LGM
        inside_lgm[is, js] .|= mask
        global nlgm += 1
    end
    a === nothing && continue
    for j in j0:j1, i in i0:i1
        any(view(mask, (i-i0)*NSUB+1:(i-i0+1)*NSUB, (j-j0)*NSUB+1:(j-j0+1)*NSUB)) || continue
        age_start[i, j] = isnan(age_start[i, j]) ? a[1] : max(age_start[i, j], a[1])
        age_end[i, j] = isnan(age_end[i, j]) ? a[2] : min(age_end[i, j], a[2])
    end
end
dated = count(s -> haskey(ages, s[1]), streams)
println("$(length(streams)) ice-stream polygons, $dated with ages in Stokes et al. (2016), $nlgm active at the LGM")

"Fraction of the samples of each cell that are set."
function fraction(B::BitMatrix)
    F = zeros(Float32, nx, ny)
    for j in 1:ny, i in 1:nx
        F[i, j] = count(view(B, (i-1)*NSUB+1:i*NSUB, (j-1)*NSUB+1:j*NSUB)) / NSUB^2
    end
    return F
end

path = joinpath(prepared_dir("Margold2015_icestreams"), "Margold2015_ICESTREAMS.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "x", g.xc, ("x",); attrib=["units" => "km", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", g.yc, ("y",); attrib=["units" => "km", "standard_name" => "projection_y_coordinate"])
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic", "proj_params" => PROJ])
    fields = [("f_stream", fraction(inside), "1", "area fraction of mapped ice streams (all ages)"),
              ("f_stream_lgm", fraction(inside_lgm), "1", "area fraction of ice streams active at the LGM (21.8 ka)"),
              ("age_stream_start", age_start, "years ago", "start of ice-stream activity (best estimate, years before 1950 CE)"),
              ("age_stream_end", age_end, "years ago", "end of ice-stream activity (best estimate, years before 1950 CE)")]
    for (name, F, units, long_name) in fields
        attrib = ["units" => units, "long_name" => long_name, "grid_mapping" => "crs"]
        startswith(name, "age") &&
            push!(attrib, "comment" => "in cells covered by dated ice streams; where streams overlap, the oldest start " *
                                       "and the youngest end")
        defVar(ds, name, F, ("x", "y"); fillvalue=NaN32, deflatelevel=1, shuffle=true, attrib)
    end
    ds.attrib["title"] = "Ice streams of the Laurentide Ice Sheet (Margold et al., 2015) and their activity " *
                         "(Stokes et al., 2016)"
    ds.attrib["references"] = "Margold, M., Stokes, C. R., Clark, C. D. and Kleman, J.: Ice streams in the Laurentide " *
                              "Ice Sheet: a new mapping inventory, J. Maps, 11, 380-395, 2015, " *
                              "doi:10.1080/17445647.2014.912036; data: figshare, doi:10.6084/m9.figshare.1033955.v3. " *
                              "Stokes, C. R., Margold, M., Clark, C. D. and Tarasov, L.: Ice stream activity scaled to " *
                              "ice sheet volume during Laurentide Ice Sheet deglaciation, Nature, 530, 322-326, 2016, " *
                              "doi:10.1038/nature16947 (source data of Fig. 1 and 2)"
    ds.attrib["doi"] = "10.6084/m9.figshare.1033955.v3"
    ds.attrib["license"] = "Outlines: CC BY 4.0 (figshare, supplement of Margold et al., 2015); ages: source data of " *
                           "Stokes et al. (2016), Nature (Springer Nature terms)"
    ds.attrib["comment"] = "Outlines (IS_polygons.shp) rasterized as the fraction of $(NSUB)x$(NSUB) samples per cell " *
                           "inside them; f_stream_lgm: streams whose best-estimate start is at the LGM (21.8 ka, the " *
                           "start of the chronology of Stokes et al., 2016); 0 outside the mapped streams (the inventory " *
                           "covers the Laurentide Ice Sheet only)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
end
println("Wrote $path")
