# Shared definitions for the topography v2 scripts: products, sources and paths.
# Domains, grids and NetCDF output are shared with the other pipelines (../shared).

using DataManifest
using TOML

include(joinpath(@__DIR__, "..", "shared", "io.jl"))
include(joinpath(@__DIR__, "..", "shared", "domains.jl"))

const TOPO_DIR = @__DIR__

"Dataset name of the topography files (provenance attributes, release tags topo-v*)."
const DATASET = "topo"

read_products() = TOML.parsefile(joinpath(TOPO_DIR, "products.toml"))

function _products(dom::Domain)
    all = read_products()
    haskey(all, dom.key) || error("no products for domain $(dom.key) in products.toml")
    return all[dom.key]
end

"Sources of each product of a domain, highest priority first (see products.toml)."
product_sources(dom::Domain) =
    Dict{String,Vector{String}}(k => Vector{String}(v) for (k, v) in _products(dom)["products"])

"Ice and sea-water densities (kg m-3) used for flotation on a domain."
densities(dom::Domain) = (Float64(_products(dom)["rho_ice"]), Float64(_products(dom)["rho_sw"]))

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

"Folder for intermediate files: \$FESMDATA_WORK/topo."
workdir() = joinpath(_env("FESMDATA_WORK"), "topo")

"DataManifest database of the original datasets."
manifest() = read_dataset(joinpath(REPO_DIR, "datamanifest.toml"); persist=false)

# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------

"Intermediate file of a source remapped onto the base grid of a domain."
source_file(dom::Domain, source::AbstractString) =
    joinpath(workdir(), dom.base.name, "$(dom.base.name)_$(source).nc")

"Output file of a product on a grid."
product_file(og::OutGrid, product::AbstractString) =
    joinpath(outdir(og), "$(og.grid.name)_TOPO-$(product).nc")
