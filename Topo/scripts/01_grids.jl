#
# Write the grid description file (grid_<GRID>.txt) and grid file (<GRID>_grid.nc)
# of every grid of a domain to its output folder, and report differences with the
# v1 grid definitions in maps/.
#
# Usage:
#     julia --project=Topo -t N Topo/scripts/01_grids.jl DOMAIN [--folder=FOLDER]
#
# --folder: only the grids in output folder FOLDER (e.g. the grids added to a crop).
#
include(joinpath(@__DIR__, "..", "common.jl"))

args, folder = folder_option(ARGS)
length(args) == 1 || error("usage: 01_grids.jl DOMAIN [--folder=FOLDER]  (one of $(join(domain_keys(), ", ")))")
dom = Domain(args[1])

for og in in_folder(dom.grids, folder, dom)
    g = og.grid
    dir = write_grid_files(outdir(og), g; dataset=DATASET)

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
