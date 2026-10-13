# Thematic datasets made by remapping (e.g. GHF): their products, defined in
# <Dataset>/remap.toml, and the output files, also read by ../Publish. Needs only
# ../shared/provenance.jl (remap_spec_file), ../shared/domains.jl and
# ../shared/precision.jl.

using TOML

"Methods of filling the gaps (see `GapFill`)."
const FILL_METHODS = ("harmonic", "elevation_regression", "elevation")

"""
    GapFill

The gaps filled after remapping (a table of `fill` of a product): the cells of the
fields `variables` without source data, with ice (H_ice > 0) in the Topo product `mask`
on the same grid (e.g. "TOPO-BedMachine-v4", the file `<GRID>_TOPO-BedMachine-v4.nc`), or
all of them for `mask = "all"`, filled by `method`: "harmonic" (Laplace) interpolation,
"elevation_regression", the linear regression of the field on the surface elevation
(`z_srf` of the Topo product `elevation`, 0 over the ocean) of the cells with data within `radius` km
(grown until there are `min_points`), at the elevation of the cell, or "elevation", that
surface elevation itself (e.g. for the orography of a field filled by the regression);
`cap` gives upper bounds of the filled values by field (in its units). `gaps_of`
("elevation" only, "" for none) names the field whose gaps (no source data in any of its
slices, in `mask`) are filled instead of those of each variable, e.g. the orography
where the surface mass balance is filled.
"""
struct GapFill
    method::String
    variables::Vector{String}
    mask::String
    elevation::String
    radius::Float64
    min_points::Int
    cap::Dict{String,Float64}
    gaps_of::String
end

"Keys of a table of `fill` by method (`variables` and `mask` are required)."
const FILL_KEYS = Dict("harmonic" => ("method", "variables", "mask"),
                       "elevation_regression" => ("method", "variables", "mask", "elevation", "radius",
                                                  "min_points", "cap"),
                       "elevation" => ("method", "variables", "mask", "elevation", "gaps_of"))

"""
`fill` of a product in remap.toml, checked (see `GapFill`): a table or a list of tables,
each variable in one table at most.
"""
function gap_fill_spec(value, what, variables)
    tables = value isa AbstractDict ? [value] : value isa AbstractVector ? value : nothing
    tables !== nothing && !isempty(tables) && all(t -> t isa AbstractDict, tables) ||
        error("$what: fill must be a table { variables = [...], mask = \"TOPO-<name>\" or \"all\" }, or a list of them")
    fills = GapFill[]
    for t in tables
        method = get(t, "method", "harmonic")
        method in FILL_METHODS || error("$what: fill.method must be one of $(join(FILL_METHODS, ", "))")
        unknown = setdiff(keys(t), FILL_KEYS[method])
        isempty(unknown) || error("$what: unknown keys of fill ($method): $(join(unknown, ", "))")
        haskey(t, "variables") && haskey(t, "mask") || error("$what: fill needs variables and mask")
        vars = Vector{String}(t["variables"])
        variables === nothing || isempty(setdiff(vars, variables)) ||
            error("$what: fill.variables $(join(setdiff(vars, variables), ", ")) are not among the variables")
        t["mask"] == "all" || startswith(t["mask"], "TOPO-") ||
            error("$what: fill.mask must be a Topo product, e.g. TOPO-BedMachine-v4, or \"all\"")
        elevation = String(get(t, "elevation", "TOPO-BedMachine-v4"))
        startswith(elevation, "TOPO-") || error("$what: fill.elevation must be a Topo product, e.g. TOPO-BedMachine-v4")
        radius, min_points = Float64(get(t, "radius", 150.0)), Int(get(t, "min_points", 20))
        radius > 0 && min_points >= 2 || error("$what: fill.radius must be > 0 and fill.min_points >= 2")
        cap = Dict{String,Float64}(k => Float64(v) for (k, v) in get(t, "cap", Dict{String,Any}()))
        isempty(setdiff(keys(cap), vars)) || error("$what: fill.cap of fields not filled by it")
        gaps_of = String(get(t, "gaps_of", ""))
        variables === nothing || isempty(gaps_of) || gaps_of in variables ||
            error("$what: fill.gaps_of $gaps_of is not among the variables")
        push!(fills, GapFill(method, vars, t["mask"], elevation, radius, min_points, cap, gaps_of))
    end
    allunique(f for g in fills for f in g.variables) || error("$what: a variable in several tables of fill")
    return fills
end

"""
    ThematicProduct

A product of a thematic dataset (a table of <Dataset>/remap.toml), written as
`<GRID>_<Dataset>-<name>.nc` on grids of some domains: a `RemapProduct` or an
`EnsembleProduct`. `grids` gives them by domain (output folder): a minimum spacing in
km (the standard grids of the domain not finer than this; 0: all), or the names of
the grids (any grid of the domain, also those made on request, e.g. Gaussian grids).
A product is not made on the domains not in `grids`. `precision` gives the precision of
some of its float fields instead of their default (see `parse_precision`).
"""
abstract type ThematicProduct end

"""
    RemapProduct

A product of the fields of a prepared file of a source (or of several, combined),
remapped onto its grids (see `ThematicProduct`). `fill` gives the gaps filled after
remapping (see `GapFill`), by one or more methods.
"""
struct RemapProduct <: ThematicProduct
    dataset::String
    name::String
    source::String                  # folder of the source, with prepare.jl
    files::Vector{String}           # prepared files, in $FESMDATA_PREPARED/<source>/
    variables::Union{Nothing,Vector{String}}
    grids::Dict{String,Union{Float64,Vector{String}}}   # by domain: minimum spacing (km) or grid names
    method::String
    smooth::Union{String,Float64}
    release::Bool                   # part of the releases of the dataset
    figure::Union{Nothing,Dict{String,Any}}   # options of its figure on the website, nothing: none
    precision::Dict{String,Precision}         # by field, instead of the default
    fill::Vector{GapFill}           # gaps filled (none: empty)
end

"Statistics of an ensemble product over its members."
const ENSEMBLE_STATS = ("mean", "stdev")

"""
    EnsembleProduct

A product of the ensemble of other products of the dataset (`members`, remap products
made on all its grids): on each grid, the mean or the (population) standard deviation
(`stat`) of their fields over the members with a value in each cell (see `ThematicProduct`).
"""
struct EnsembleProduct <: ThematicProduct
    dataset::String
    name::String
    members::Vector{String}         # names of the member products
    stat::String                    # one of ENSEMBLE_STATS
    grids::Dict{String,Union{Float64,Vector{String}}}
    release::Bool
    figure::Union{Nothing,Dict{String,Any}}
    precision::Dict{String,Precision}
end

"Domains (output folders) of a product."
product_domains(p::ThematicProduct) = sort(collect(keys(p.grids)))

"Spacing of a grid in km (of a lon-lat grid: its mean latitude spacing)."
spacing_km(g::ProjGrid) = maximum(spacing(g))
spacing_km(g::LonLatGrid) = 111.195 * g.dlat

"""
    on_grid(p, og) -> Bool

Whether a product is made on grid `og`: by the entry of its domain in `p.grids`, a
standard grid not finer than the minimum spacing, or a grid named in the list.
"""
function on_grid(p::ThematicProduct, og::OutGrid)
    spec = get(p.grids, og.folder, nothing)
    spec === nothing && return false
    spec isa Vector && return og.grid.name in spec
    return !og.on_request && spacing_km(og.grid) >= spec - 1e-9
end

"""
    product_grid_spec(grids, what) -> Dict{String,Union{Float64,Vector{String}}}

The `grids` table of a product in remap.toml, checked: domains (output folders) with a
minimum spacing in km or a list of grid names of that domain.
"""
function product_grid_spec(grids, what)
    grids isa AbstractDict && !isempty(grids) ||
        error("$what: grids must be a table by domain, e.g. { Antarctica = 4, Global = 4 }")
    spec = Dict{String,Union{Float64,Vector{String}}}()
    for (folder, v) in grids
        names = [og.grid.name for og in folder_grids(folder)[2]]
        if v isa Real
            spec[folder] = Float64(v)
        elseif v isa AbstractVector
            unknown = setdiff(v, names)
            isempty(unknown) || error("$what: grids $(join(unknown, ", ")) are not grids of $folder, " *
                                      "available: $(join(names, ", "))")
            spec[folder] = Vector{String}(v)
        else
            error("$what: grids.$folder must be a minimum spacing in km or a list of grid names")
        end
    end
    return spec
end

"Grids of a product (see `on_grid`)."
product_grids(p::ThematicProduct) = [og for key in domain_keys() for og in Domain(key).grids if on_grid(p, og)]

"`file` of a product in remap.toml: a prepared file, or a list of them (combined)."
function product_files(file, what)
    file isa AbstractString && return [String(file)]
    file isa AbstractVector && !isempty(file) && all(f -> f isa AbstractString, file) && allunique(file) &&
        return Vector{String}(file)
    error("$what: file must be a prepared file or a list of them")
end

"Keys of a product in remap.toml common to remap and ensemble products."
const PRODUCT_KEYS = ("grids", "release", "figure", "precision")

"`precision` of a product in remap.toml: a table by field (see `parse_precision`)."
function product_precision(value, what)
    value isa AbstractDict || error("$what: precision must be a table by field, e.g. { ghf = 0.1, smb = \"1%\" }")
    return Dict{String,Precision}(k => parse_precision(v, "$what: precision.$k") for (k, v) in value)
end

"""
    remap_products(dataset) -> Vector{ThematicProduct}

Products of a thematic dataset (<Dataset>/remap.toml), by name: a table with
`ensemble` is an `EnsembleProduct`, any other a `RemapProduct`.
"""
function remap_products(dataset::AbstractString)
    is_remap_dataset(dataset) || error("no thematic dataset $dataset (no $(remap_spec_file(dataset)))")
    spec = TOML.parsefile(remap_spec_file(dataset))
    folders = domain_folders()
    products = ThematicProduct[]
    for (name, p) in spec["products"]
        what = "$dataset/$name"
        haskey(p, "grids") || error("$what: no grids (a table by domain)")
        unknown = setdiff(keys(p["grids"]), folders)
        isempty(unknown) || error("$what: unknown domains $(join(unknown, ", ")), available: $(join(folders, ", "))")
        grids = product_grid_spec(p["grids"], what)
        release, figure = get(p, "release", true), figure_spec(get(p, "figure", Dict()), what)
        precision = product_precision(get(p, "precision", Dict()), what)
        push!(products, haskey(p, "ensemble") ? ensemble_product(dataset, name, p, grids, release, figure, precision) :
                                                remap_product(dataset, name, p, grids, release, figure, precision))
    end
    check_ensembles(products)
    return sort(products; by=p -> p.name)
end

"A remap product from its table `p` in remap.toml (`grids`, `release`, `figure` and `precision` parsed)."
function remap_product(dataset, name, p, grids, release, figure, precision)
    what = "$dataset/$name"
    unknown = setdiff(keys(p), (PRODUCT_KEYS..., "source", "file", "variables", "method", "smooth", "fill"))
    isempty(unknown) || error("$what: unknown keys $(join(unknown, ", "))")
    smooth = get(p, "smooth", "auto")
    variables = haskey(p, "variables") ? Vector{String}(p["variables"]) : nothing
    fill = haskey(p, "fill") ? gap_fill_spec(p["fill"], what, variables) : GapFill[]
    files = product_files(get(p, "file", nothing), what)
    return RemapProduct(dataset, name, p["source"], files, variables, grids, get(p, "method", "con"),
                        smooth isa Real ? Float64(smooth) : String(smooth), release, figure, precision, fill)
end

"An ensemble product from its table `p` in remap.toml (`grids`, `release`, `figure` and `precision` parsed)."
function ensemble_product(dataset, name, p, grids, release, figure, precision)
    what = "$dataset/$name"
    given = intersect(keys(p), ("source", "file"))
    isempty(given) || error("$what: ensemble and $(join(given, ", ")) exclude each other " *
                            "(an ensemble product is made from its member products)")
    unknown = setdiff(keys(p), (PRODUCT_KEYS..., "ensemble", "stat"))
    isempty(unknown) || error("$what: unknown keys $(join(unknown, ", "))")
    members = p["ensemble"]
    members isa AbstractVector && length(members) in 2:typemax(Int8) && all(m -> m isa AbstractString, members) &&
        allunique(members) || error("$what: ensemble must be a list of 2 to $(typemax(Int8)) products of $dataset")
    stat = get(p, "stat", nothing)
    stat in ENSEMBLE_STATS || error("$what: stat must be one of $(join(ENSEMBLE_STATS, ", "))")
    return EnsembleProduct(dataset, name, Vector{String}(members), stat, grids, release, figure, precision)
end

"""
Check the members of the ensemble products: remap products of the dataset (made as
intermediate files on the grids of the ensemble that are not theirs, see `make_product`).
"""
function check_ensembles(products::AbstractVector{ThematicProduct})
    byname = Dict(p.name => p for p in products)
    for e in filter(p -> p isa EnsembleProduct, products)
        for m in e.members
            what = "$(e.dataset)/$(e.name): member $m"
            haskey(byname, m) || error("$what is not a product of $(e.dataset)")
            byname[m] isa RemapProduct || error("$what is an ensemble product (members must be remap products)")
        end
    end
end

"Member products of an ensemble product."
function ensemble_members(e::EnsembleProduct)
    byname = Dict(p.name => p for p in remap_products(e.dataset))
    return RemapProduct[byname[m] for m in e.members]
end

"Name of the output files of a product: <GRID>_<name>.nc."
product_name(p::ThematicProduct) = "$(p.dataset)-$(p.name)"

"Prepared files of a product."
prepared_files(p::RemapProduct) = [joinpath(prepared_dir(p.source), f) for f in p.files]

"Domains (output folders) on which a thematic dataset is released."
remap_domains(dataset::AbstractString) =
    sort(unique(d for p in remap_products(dataset) if p.release for d in product_domains(p)))

"""
    remap_release_files(dataset, og) -> Vector{String}

Files of a release of a thematic dataset on grid `og`: the products on its domain,
except those with `release = false` (see ../Publish).
"""
remap_release_files(dataset::AbstractString, og::OutGrid) =
    sort(["$(og.grid.name)_$(product_name(p)).nc" for p in remap_products(dataset) if p.release && on_grid(p, og)])
