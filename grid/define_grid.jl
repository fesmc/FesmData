if abspath(PROGRAM_FILE) == @__FILE__
    running_from_cmd = true
else
    running_from_cmd = false
end

cd(@__DIR__)
import Pkg; Pkg.activate(".")
using NCDatasets

# Several useful functions
include("grids.jl")

if running_from_cmd
    domain = ARGS[1]
    grid_name = ARGS[2]

    println("domain, grid_name = $domain, $grid_name")

    # Define the grid
    grid = generate_grid(domain,grid_name)

    # Write to output file in maps folder
    filename = joinpath("../maps","grid_$(grid_name).nc")
    grid_write_nc(grid,filename)

    # Also write it in output folder with correct naming convention
    filename = joinpath("../out","$(grid_name)_grid.nc")
    grid_write_nc(grid,filename)
end
