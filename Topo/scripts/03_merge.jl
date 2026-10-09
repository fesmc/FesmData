#
# Merge the sources of each product of a domain on its base grid (output of step 2),
# and write <BASE>_TOPO-<product>.nc to $ICE_DATA/v2/<folder>/<BASE>/.
#
# Sources are blended in order of increasing priority. A source replaces the fields
# below it where it fully covers a cell, with a weight that increases linearly from 0
# at the edge of its coverage to 1 at TAPER_KM inside it. A thickness source
# (glaciers) instead adds grounded ice onto the ice-free land below it, lowering the
# bed by the ice thickness. Then the grounded and floating fractions are split by
# flotation of the cell-mean ice thickness and bed: the ice fraction of a cell is
# grounded or floating as a whole, and grounded where it includes glacier ice from a
# thickness source. Surface elevation is kept as given by the sources.
#
# Usage:
#     julia --project=Topo -t N Topo/scripts/03_merge.jl DOMAIN [PRODUCTS]
#
# PRODUCTS is "default" (the default products, if omitted), "variants", "all",
# or the name of one product (see domains.toml).
#
include(joinpath(@__DIR__, "..", "common.jl"))
include(joinpath(TOPO_DIR, "sources.jl"))

const TAPER_KM = 20.0
const BLEND = ("z_bed", "z_srf", "H_ice", "z_bed_sd", "f_ocn", "f_land", "f_grnd", "f_flt")

1 <= length(ARGS) <= 2 || error("usage: 03_merge.jl DOMAIN [PRODUCTS]")
dom = Domain(ARGS[1])
products = select_products(dom, get(ARGS, 2, "default"))
base = dom.base
dx, dy = spacing(base)

"""
Blending weight of a source: 0 outside its full coverage, rising linearly to 1 at
TAPER_KM inside it.
"""
function taper_weight(f_valid)
    covered = f_valid .>= 0.999
    d = distance_to(.!covered, dx, dy)
    return Float32.(clamp.(d ./ TAPER_KM, 0, 1))
end

"""
Replace the merged fields `out` by those of a topography source `f` with weight `w`
(1 where only the source has data).
"""
function blend!(out, f, w)
    for name in BLEND
        o, s = out[name], f[name]
        Threads.@threads for j in axes(o, 2)
            @inbounds for i in axes(o, 1)
                wij = isnan(o[i, j]) && !isnan(s[i, j]) ? 1f0 : w[i, j]
                wij > 0 && (o[i, j] = wij * s[i, j] + (1 - wij) * o[i, j])
            end
        end
    end
    return out
end

"""
Add the glaciers of a thickness source (fields `f`) onto the ice-free land of the
merged fields `out`: the glacier fraction, at most the ice-free land fraction,
becomes grounded ice with the thickness of that part, and the bed is lowered by its
cell-mean thickness (the surface is unchanged). Returns the added glacier fraction.
"""
function add_glaciers!(out, f)
    added = zeros(Float32, size(out["H_ice"]))
    Threads.@threads for j in axes(added, 2)
        @inbounds for i in axes(added, 1)
            fi, land = f["f_ice"][i, j], out["f_land"][i, j]
            (fi > 0 && land > 0) || continue
            a = min(fi, land)
            dH = f["H_ice"][i, j] * a / fi
            out["f_land"][i, j] -= a
            out["f_grnd"][i, j] += a
            out["H_ice"][i, j] += dH
            out["z_bed"][i, j] -= dH
            added[i, j] = a
        end
    end
    return added
end

"""
Split the ice fraction of each cell into grounded or floating by flotation (always
grounded where `grounded` is true), and derive the dominant surface type.
"""
function apply_flotation!(f, rho_ice, rho_sw, grounded)
    nx, ny = size(f["z_bed"])
    mask = Matrix{Int8}(undef, nx, ny)
    r = Float32(rho_ice / rho_sw)
    Threads.@threads for j in 1:ny
        @inbounds for i in 1:nx
            H = max(f["H_ice"][i, j], 0f0)
            f["H_ice"][i, j] = H
            f_ice = f["f_grnd"][i, j] + f["f_flt"][i, j]
            floating = !grounded[i, j] && f["z_bed"][i, j] + r * H < 0
            f["f_grnd"][i, j] = floating ? 0f0 : f_ice
            f["f_flt"][i, j] = floating ? f_ice : 0f0
            mask[i, j] = f_ice >= 0.5 ? (floating ? FLT : GRND) :
                         f["f_ocn"][i, j] >= f["f_land"][i, j] ? OCEAN : LAND
        end
    end
    return mask
end

const MASK_ATTRIB = Pair{String,Any}["flag_values" => collect(MASK_CLASSES),
                                     "flag_meanings" => "ocean ice_free_land grounded_ice floating_ice"]

for product in products
    t0 = time()
    sources = dom.products[product]       # highest priority first
    println("Product $product: ", join(sources, " > "))

    out = nothing
    weights = Matrix{Float32}[]           # final weight of each source, lowest priority first
    for (k, source) in enumerate(reverse(sources))
        _, f = read_fields(source_file(dom, source))
        if out === nothing
            is_thickness_source(source) && error("lowest-priority source $source must be a topography source")
            out = Dict(name => copy(f[name]) for name in BLEND)
            push!(weights, Float32.(f["f_valid"] .> 0))
            continue
        end
        if is_thickness_source(source)
            w = add_glaciers!(out, f)
        else
            w = taper_weight(f["f_valid"])
            blend!(out, f, w)
        end
        for wl in weights
            wl .*= 1 .- w
        end
        push!(weights, w)
    end

    # Glacier ice from thickness sources that remains after the sources above them
    grounded = falses(size(out["H_ice"]))
    for (wl, source) in zip(weights, reverse(sources))
        is_thickness_source(source) && (grounded .|= wl .> 0)
    end
    mask = apply_flotation!(out, dom.rho_ice, dom.rho_sw, grounded)
    src_id = Int8.(map(I -> argmax([wl[I] for wl in weights]), CartesianIndices(mask)) .- 1)
    out_fields = Dict{String,Matrix}(out)
    out_fields["mask"] = mask
    out_fields["src_id"] = src_id

    src_attrib = Pair{String,Any}["flag_values" => Int8.(0:length(sources)-1),
                                  "flag_meanings" => join(reverse(sources), " ")]
    path = write_fields(product_file(dom.grids[1], product), base, out_fields;
        attrib=["product" => product, "sources" => join(sources, " > "),
                "taper_km" => string(TAPER_KM), "rho_ice" => string(dom.rho_ice), "rho_sw" => string(dom.rho_sw),
                "history" => "Topo/scripts/03_merge.jl"],
        varattrib=Dict("mask" => MASK_ATTRIB, "src_id" => src_attrib))
    println("Wrote $path ($(round(time() - t0; digits=1)) s)")
end
