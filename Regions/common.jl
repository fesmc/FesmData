# Shared definitions for the regions v2 scripts. Domains, grids and the output paths
# are those of the topography pipeline (../Topo).

include(joinpath(@__DIR__, "..", "Topo", "common.jl"))
include(joinpath(@__DIR__, "shapes.jl"))
include(joinpath(@__DIR__, "sources.jl"))
include(joinpath(@__DIR__, "tree.jl"))

merge!(VARINFO, Dict(
    "region_1" => ("1", "region code, level 1 (hemisphere)"),
    "region_2" => ("1", "region code, level 2"),
    "region_3" => ("1", "region code, level 3"),
))

"Folder for intermediate files: \$FESMDATA_WORK/regions."
regions_workdir() = joinpath(_env("FESMDATA_WORK"), "regions")

"Intermediate file of a field set (e.g. \"regions\", \"zone\") on the base grid of a domain."
regions_work_file(dom::Domain, what::AbstractString) =
    joinpath(regions_workdir(), dom.base.name, "$(dom.base.name)_$(what).nc")

