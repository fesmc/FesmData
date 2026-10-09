#
# Write the grid description file (grid_<GRID>.txt) and grid file (<GRID>_grid.nc)
# of every grid of a domain to its output folder, and report differences with the
# v1 grid definitions in maps/.
#
# Usage:
#     julia --project=Topo -t N Topo/scripts/01_grids.jl DOMAIN
#
include(joinpath(@__DIR__, "..", "common.jl"))

length(ARGS) == 1 || error("usage: 01_grids.jl DOMAIN  (one of $(join(domain_keys(), ", ")))")
dom = Domain(ARGS[1])

for og in dom.grids
    g = og.grid
    dir = mkpath(outdir(og))
    write_griddes(joinpath(dir, "grid_$(g.name).txt"), g)
    write_grid_nc(joinpath(dir, "$(g.name)_grid.nc"), g)

    nx, ny = size(g)
    msg = rpad(g.name, 16) * rpad("$nx x $ny", 14) * dir
    v1 = joinpath(REPO_DIR, "maps", "grid_$(g.name).txt")
    if isfile(v1)
        g1 = ProjGrid(v1)
        same = size(g1) == size(g) && g1.xc ≈ g.xc && g1.yc ≈ g.yc && same_projection(g1, g)
        msg *= same ? "  (= v1)" : "  (differs from v1: $(join(size(g1), " x ")))"
    end
    println(msg)
end
