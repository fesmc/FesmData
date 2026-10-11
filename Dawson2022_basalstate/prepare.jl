# Prepare the Antarctic basal thermal state of Dawson et al. (2022) for remapping: the
# basal temperature of the ISSM thermal steady state (Antarctica_Initialization.mat,
# Zenodo), interpolated linearly from the triangles of the model mesh (0.3-50 km)
# onto a regular 1 km polar stereographic grid, as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/Dawson2022_basalstate/Dawson2022_BASALSTATE.nc, with the
# basal temperature, the basal temperature relative to the pressure melting point and
# the basal thermal state (frozen, thawable, thawed) of the grounded ice.
#
# Usage:
#     julia --project=Dawson2022_basalstate Dawson2022_basalstate/prepare.jl

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "issm_mat.jl"))

const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
const DX = 1000.0                   # grid spacing (m), about the finest spacing of the mesh

# Thresholds of the basal thermal state on the pressure-adjusted basal temperature (K),
# as in the scripts of Dawson et al. (2022): frozen below FROZEN, thawed above THAWED,
# thawable between (within 2 K of the pressure melting point, 273.15 K)
const FROZEN = 271.14
const THAWED = 273.14

"""
    interp_to_grid(xv, yv, tri, fields, xg, yg)

Linear interpolation of fields at the vertices (xv, yv) of a triangle mesh (`tri`:
vertex indices, one row per triangle) at the points of the grid (xg, yg); NaN outside
the mesh.
"""
function interp_to_grid(xv, yv, tri, fields, xg, yg)
    out = [fill(NaN, length(xg), length(yg)) for _ in fields]
    x0, y0 = first(xg), first(yg)
    for t in axes(tri, 1)
        a, b, c = tri[t, 1], tri[t, 2], tri[t, 3]
        xa, ya, xb, yb, xc, yc = xv[a], yv[a], xv[b], yv[b], xv[c], yv[c]
        det = (yb - yc) * (xa - xc) + (xc - xb) * (ya - yc)
        det == 0 && continue
        i1 = max(1, ceil(Int, (min(xa, xb, xc) - x0) / DX) + 1)
        i2 = min(length(xg), floor(Int, (max(xa, xb, xc) - x0) / DX) + 1)
        j1 = max(1, ceil(Int, (min(ya, yb, yc) - y0) / DX) + 1)
        j2 = min(length(yg), floor(Int, (max(ya, yb, yc) - y0) / DX) + 1)
        for j in j1:j2, i in i1:i2
            x, y = xg[i], yg[j]
            wa = ((yb - yc) * (x - xc) + (xc - xb) * (y - yc)) / det
            wb = ((yc - ya) * (x - xc) + (xa - xc) * (y - yc)) / det
            wc = 1 - wa - wb
            min(wa, wb, wc) >= -1e-9 || continue
            for (k, F) in enumerate(fields)
                out[k][i, j] = wa * F[a] + wb * F[b] + wc * F[c]
            end
        end
    end
    return out
end

input = download_dataset(manifest(), "dawson2022_init")

HDF5.h5open(input) do file
    m = MCOSFile(file)
    md = model_id(m)
    mesh = property(m, md, "mesh")
    String(Char.(vec(property(m, mesh, "epsg")))) == "3031" || error("mesh of $input not in EPSG:3031")
    xv = vec(property(m, mesh, "x2d"))
    yv = vec(property(m, mesh, "y2d"))
    tri = Int.(property(m, mesh, "elements2d"))
    nv = length(xv)                                   # the base is the first layer of vertices
    T = vec(property(m, md, "results")["ThermalSolution"]["Temperature"])[1:nv]
    p = vec(property(m, md, "initialization", "pressure"))[1:nv]
    beta = only(property(m, md, "materials", "beta"))
    tmelt = only(property(m, md, "materials", "meltingpoint"))
    gl = vec(property(m, md, "mask", "groundedice_levelset"))[1:nv]   # > 0 grounded
    il = vec(property(m, md, "mask", "ice_levelset"))[1:nv]           # < 0 ice
    T_pa = T .+ beta .* p                             # pressure-adjusted temperature

    xg = collect(floor(minimum(xv) / DX) * DX + DX / 2 : DX : maximum(xv))
    yg = collect(floor(minimum(yv) / DX) * DX + DX / 2 : DX : maximum(yv))
    Tg, Tpag, glg, ilg = interp_to_grid(xv, yv, tri, (T, T_pa, gl, il), xg, yg)
    grounded = (glg .> 0) .& (ilg .< 0)
    Tg[.!grounded] .= NaN
    Tpag[.!grounded] .= NaN
    state = Int8[!g ? Int8(-1) : t < FROZEN ? Int8(1) : t > THAWED ? Int8(3) : Int8(2)
                 for (g, t) in zip(grounded, Tpag)]

    path = joinpath(prepared_dir("Dawson2022_basalstate"), "Dawson2022_BASALSTATE.nc")
    mkpath(dirname(path))
    NCDataset(path, "c") do ds
        defVar(ds, "x", xg, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
        defVar(ds, "y", yg, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
        defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic",
                                                 "proj_params" => PROJ, "epsg_code" => "EPSG:3031"])
        defVar(ds, "T_b", Float32.(Tg), ("x", "y"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "K", "long_name" => "basal temperature of the grounded ice",
                       "grid_mapping" => "crs"])
        defVar(ds, "T_b_pmp", Float32.(Tpag .- tmelt), ("x", "y"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "K", "grid_mapping" => "crs",
                       "long_name" => "basal temperature of the grounded ice relative to the pressure melting point"])
        defVar(ds, "basal_state", state, ("x", "y"); fillvalue=Int8(-1), deflatelevel=1,
               attrib=["units" => "1", "long_name" => "basal thermal state of the grounded ice",
                       "flag_values" => Int8[1, 2, 3], "flag_meanings" => "frozen thawable thawed",
                       "comment" => "From T_b_pmp: frozen below $(round(FROZEN - tmelt; digits=2)) K, thawed above " *
                                    "$(round(THAWED - tmelt; digits=2)) K, thawable between",
                       "grid_mapping" => "crs"])
        ds.attrib["title"] = "Basal thermal state of the Antarctic ice sheet (Dawson et al., 2022)"
        ds.attrib["references"] = "Dawson, E. J., Schroeder, D. M., Chu, W., Mantelli, E., and Seroussi, H.: " *
                                  "Ice mass loss sensitivity to the Antarctic ice sheet basal thermal state, " *
                                  "Nat. Commun., 13, 4957, 2022, doi:10.1038/s41467-022-32632-2; " *
                                  "data: Zenodo, doi:10.5281/zenodo.6870567"
        ds.attrib["doi"] = "10.5281/zenodo.6870567"
        ds.attrib["license"] = "CC BY 4.0"
        ds.attrib["comment"] = "ISSM thermal steady state of Antarctica_Initialization.mat (md.results." *
                               "ThermalSolution.Temperature at the base, pressure-adjusted with " *
                               "md.materials.beta and md.initialization.pressure), interpolated " *
                               "linearly from the triangles of the mesh onto a $(Int(DX / 1000)) km grid; " *
                               "grounded ice from the interpolated level sets of md.mask"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("basalstate"))
    end
    println("Wrote $path")
end
