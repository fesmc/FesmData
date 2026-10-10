# Basin sets of the Northeast Greenland Ice Stream (NEGIS) in three parts, centre, south
# and north (basin 1, 2, 3), for tuning basal friction by part in yelmox (see
# basins.toml and README.md):
#
#   negis_v1 - the v1 parts, drawn by hand on GRL-16KM (sources/negis_v1_GRL-16KM.csv)
#   negis    - centre and south from a rule on the present-day surface speed (Joughin
#              et al., 2018), north from the v1 part: it follows a palaeo ice stream
#              (Franke et al., 2022) that today's velocities do not show

import ArchGDAL as AG

const NEGIS_PARTS = ["centre", "south", "north"]
const NEGIS_V1_FILE = joinpath(@__DIR__, "sources", "negis_v1_GRL-16KM.csv")
const NEGIS_V1_DX = 16.0        # km, spacing of the v1 grid of the parts

"Basin sources of the NEGIS sets: rasters from a rule or a fixed source, not extended."
is_negis_source(source::AbstractString) = source in ("negis", "negis_v1")

"""
    negis_v1_parts(g) -> Matrix{Int32}

The v1 part (1-3, 0 outside) of the GRL-16KM cell containing the centre of each cell of
`g`, a grid on the polar stereographic projection of GRL. A centre on an edge between
two cells goes to the cell above (in x and y), so the cells of `g` that a coarser grid
nested in GRL-16KM takes as the majority of a cell all lie in that cell.
"""
function negis_v1_parts(g::ProjGrid)
    tab = readdlm(NEGIS_V1_FILE, ','; comments=true, comment_char='#', header=true)[1]
    parts = Dict((Float64(r[1]), Float64(r[2])) => Int32(r[3]) for r in eachrow(tab))
    centre(v) = NEGIS_V1_DX * floor((v + NEGIS_V1_DX / 2) / NEGIS_V1_DX + 1e-9)
    # v1 cell centres are at multiples of 16 km offset by -720 (x) and -3450 (y)
    cx(x) = centre(x + 720) - 720
    cy(y) = centre(y + 3450) - 3450
    return Int32[get(parts, (cx(x), cy(y)), Int32(0)) for x in g.xc, y in g.yc]
end

"""
    read_speed(g) -> Matrix{Float32}

Surface speed (m/yr) on grid `g` (same projection) from the MEaSUREs multi-year velocity
mosaic of Greenland (NSIDC-0670 v1, 250 m; Joughin et al., 2018): the magnitude of the
cell means of vx and vy, NaN without data.
"""
function read_speed(g::ProjGrid)
    dir = get_dataset_path(manifest(), "nsidc0670_v1_greenland_vel")
    function component(c)
        path = joinpath(dir, "greenland_vel_mosaic250_$(c)_v1.tif")
        xc, yc, A = _read_tif(path)
        proj = AG.read(ds -> _tif_axes(ds, path)[3], path)
        tg = ProjGrid("nsidc0670", xc, yc, proj)
        return remap(AlignedMap(g, tg), A)[1]
    end
    return Float32.(hypot.(component("vx"), component("vy")))
end

# Connected component (side neighbours) of `mask` containing its cell nearest to (x, y)
function _component_near(g::ProjGrid, mask::AbstractMatrix{Bool}, x, y)
    idx = findall(mask)
    isempty(idx) && error("NEGIS: no cell above the speed threshold")
    k = argmin([hypot(g.xc[I[1]] - x, g.yc[I[2]] - y) for I in idx])
    seed = falses(size(mask))
    seed[idx[k]] = true
    return flood_fill(mask, seed)
end

"""
    build_negis(g, params, grounded) -> Matrix{Int32}

NEGIS parts on grid `g` (polar stereographic of GRL), with the parameters of
[basins.negis] in basins.toml and the grounded ice of the topography (`grounded`):

- the stream: the cells of Zwally drainage system `zwally_system` with grounded ice
  and surface speed of at least `speed` (`speed_south` south of the cut), connected to
  the cell nearest to `seed` (km); this leaves out fast cells of other outlets
- south: the stream south of the cut line y = `cut_y0` + `cut_slope` x (km), centre:
  the rest
- north: the v1 north part (`negis_v1_parts`), over the others where they overlap
"""
function build_negis(g::ProjGrid, params::AbstractDict, grounded::AbstractMatrix{Bool})
    sys = params["zwally_system"]
    zw = filter(s -> s.attrs["basin"] ÷ 10 == sys, source_shapes("zwally2012_greenland"))
    U = read_speed(g)
    south = [y < params["cut_y0"] + params["cut_slope"] * x for x in g.xc, y in g.yc]
    umin = ifelse.(south, Float32(params["speed_south"]), Float32(params["speed"]))
    stream = rasterize(g, zw) .& grounded .& (U .>= umin)
    x0, y0 = params["seed"]
    stream = _component_near(g, stream, x0, y0)

    B = zeros(Int32, size(g))
    B[stream .& .!south] .= 1
    B[stream .& south] .= 2
    B[negis_v1_parts(g) .== 3] .= 3
    @info "NEGIS: $(count(stream)) cells in the stream, by part: $([count(==(k), B) for k in 1:3])"
    return B
end

"""
    negis_basins(g, set, grounded) -> Matrix{Int32}

Parts (1-3) of a NEGIS set on grid `g`: `negis_v1` or `negis` (see above).
"""
function negis_basins(g::ProjGrid, set::BasinSet, grounded)
    set.source == "negis_v1" && return negis_v1_parts(g)
    grounded === nothing && error("$(set.name): needs the grounded ice of the topography")
    return build_negis(g, set.params, grounded)
end

"Long name of `basin` in the files of the NEGIS sets."
const NEGIS_LONG_NAME = "part of NEGIS (not extended)"

"Comment attribute of the files of a NEGIS set (provenance of the parts)."
function negis_comment(set::BasinSet)
    v1 = "drawn by hand by Ilaria Tabone (2024) for yelmox v1 on GRL-16KM (basin_sub 9.1, 9.2, 9.3 of " *
         "GRL-16KM_BASINS-nasa-negis-three.nc), see Regions/sources/negis_v1_GRL-16KM.csv"
    set.source == "negis_v1" && return "NEGIS parts centre, south, north " * v1
    p = set.params
    return "NEGIS parts. Centre and south: Zwally2012 system $(p["zwally_system"]) with grounded ice and " *
           "surface speed (Joughin et al., 2018) >= $(p["speed"]) m/yr (>= $(p["speed_south"]) m/yr south of the cut), " *
           "connected to ($(p["seed"][1]), $(p["seed"][2])) km; south of the cut y = $(p["cut_y0"]) " *
           "$(p["cut_slope"] < 0 ? "-" : "+") $(abs(p["cut_slope"])) x km. " *
           "North: the v1 north part (palaeo ice stream, Franke et al., 2022), " * v1
end
