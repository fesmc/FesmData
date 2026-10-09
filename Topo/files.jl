# Output files of the topography products, also read by the other pipelines (e.g.
# ../Regions).

"Output file of a topography product on a grid."
product_file(og::OutGrid, product::AbstractString) =
    joinpath(outdir(og), "$(og.grid.name)_TOPO-$(product).nc")
