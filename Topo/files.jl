# Products of each domain (products.toml) and their output files, also read by the
# other pipelines (e.g. ../Regions) and by ../Publish. Needs only ../shared/domains.jl.

using TOML

read_products() = TOML.parsefile(joinpath(@__DIR__, "products.toml"))

function _products(dom::Domain)
    all = read_products()
    haskey(all, dom.key) || error("no products for domain $(dom.key) in products.toml")
    return all[dom.key]
end

"Keys of the domains with topography products (products.toml)."
topo_domains() = sort([k for (k, v) in read_products() if v isa AbstractDict])

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

"Output file of a topography product on a grid."
product_file(og::OutGrid, product::AbstractString) =
    joinpath(outdir(og), "$(og.grid.name)_TOPO-$(product).nc")

"""
    topo_release_files(dom, og) -> Vector{String}

Files of a release of the topography on grid `og` of `dom`: all its products, default
and variants (see ../Publish).
"""
function topo_release_files(dom::Domain, og::OutGrid)
    p = _products(dom)
    products = vcat(collect(keys(p["products"])), collect(keys(get(p, "variants", Dict{String,Any}()))))
    return sort([basename(product_file(og, product)) for product in products])
end
