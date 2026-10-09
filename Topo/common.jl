# Shared definitions for the topography v2 scripts: products, sources and paths.
# Domains, grids, NetCDF output and the original datasets are shared with the other
# pipelines (../shared); the output file names are in files.jl.

using TOML

include(joinpath(@__DIR__, "..", "shared", "io.jl"))
include(joinpath(@__DIR__, "..", "shared", "domains.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "files.jl"))

const TOPO_DIR = @__DIR__

"Dataset name of the topography files (provenance attributes, release tags topo-v*)."
const DATASET = "topo"

read_products() = TOML.parsefile(joinpath(TOPO_DIR, "products.toml"))

function _products(dom::Domain)
    all = read_products()
    haskey(all, dom.key) || error("no products for domain $(dom.key) in products.toml")
    return all[dom.key]
end

"Names reserved for selecting sets of products (see `select_products`)."
const PRODUCT_SETS = ("default", "variants", "all")

"""
    product_sources(dom) -> Dict{String,Vector{String}}

Sources of each product of a domain, default products and variants, highest priority
first (see products.toml).
"""
function product_sources(dom::Domain)
    p = _products(dom)
    defaults, variants = p["products"], get(p, "variants", Dict{String,Any}())
    common = intersect(keys(defaults), keys(variants))
    isempty(common) || error("$(dom.key): products listed as default and variant: $(join(common, ", "))")
    products = Dict{String,Vector{String}}(k => Vector{String}(v) for (k, v) in merge(defaults, variants))
    reserved = intersect(keys(products), PRODUCT_SETS)
    isempty(reserved) || error("$(dom.key): reserved product names: $(join(reserved, ", "))")
    return products
end

"""
    select_products(dom, sel="default") -> Vector{String}

Products of `dom` selected by `sel`: "default" (the default products), "variants",
"all", or the name of one product.
"""
function select_products(dom::Domain, sel::AbstractString="default")
    p = _products(dom)
    defaults = sort(collect(keys(p["products"])))
    variants = sort(collect(keys(get(p, "variants", Dict{String,Any}()))))
    sel == "default" && return defaults
    sel == "variants" && return variants
    sel == "all" && return vcat(defaults, variants)
    products = product_sources(dom)
    haskey(products, sel) && return [String(sel)]
    error("$(dom.key): unknown product $sel, available: $(join(PRODUCT_SETS, ", ")), $(join(sort(collect(keys(products))), ", "))")
end

"Ice and sea-water densities (kg m-3) used for flotation on a domain."
densities(dom::Domain) = (Float64(_products(dom)["rho_ice"]), Float64(_products(dom)["rho_sw"]))

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

"Folder for intermediate files: \$FESMDATA_WORK/topo."
workdir() = joinpath(_env("FESMDATA_WORK"), "topo")

"Intermediate file of a source remapped onto the base grid of a domain."
source_file(dom::Domain, source::AbstractString) =
    joinpath(workdir(), dom.base.name, "$(dom.base.name)_$(source).nc")
