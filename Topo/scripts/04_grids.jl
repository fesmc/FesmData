#
# Remap each product of a domain from its base grid (output of step 3) onto all
# other grids of the domain, including the crops, and write
# <GRID>_TOPO-<product>.nc to $ICE_DATA/v2/<folder>/<GRID>/.
#
# Fields and area fractions are conservative cell means. The bed standard deviation
# combines the sub-cell variance of the base grid with the variance of the base-grid
# means. `mask` is the dominant surface type (ice if the ice fraction is at least
# one half), and `src_id` the source covering most of the cell.
#
# Usage:
#     julia --project=Topo -t N Topo/scripts/04_grids.jl DOMAIN [PRODUCT]
#
include(joinpath(@__DIR__, "..", "common.jl"))
include(joinpath(TOPO_DIR, "sources.jl"))

const MEANS = ("z_bed", "z_srf", "H_ice", "f_ocn", "f_land", "f_grnd", "f_flt")
const MASK_ATTRIB = Pair{String,Any}["flag_values" => collect(MASK_CLASSES),
                                     "flag_meanings" => "ocean ice_free_land grounded_ice floating_ice"]

1 <= length(ARGS) <= 2 || error("usage: 04_grids.jl DOMAIN [PRODUCT]")
dom = Domain(ARGS[1])
sources_of = product_sources(dom)
products = length(ARGS) == 2 ? [ARGS[2]] : sort(collect(keys(sources_of)))
base = dom.base

function dominant_mask(f)
    mask = Matrix{Int8}(undef, size(f["z_bed"]))
    Threads.@threads for j in axes(mask, 2)
        @inbounds for i in axes(mask, 1)
            grnd, flt = f["f_grnd"][i, j], f["f_flt"][i, j]
            mask[i, j] = grnd + flt >= 0.5 ? (grnd >= flt ? GRND : FLT) :
                         f["f_ocn"][i, j] >= f["f_land"][i, j] ? OCEAN : LAND
        end
    end
    return mask
end

for product in products
    _, fb = read_fields(product_file(dom.grids[1], product))
    # Second moment of the bed on the base grid (cell variance + mean^2)
    z2 = Float64.(fb["z_bed_sd"]) .^ 2 .+ Float64.(fb["z_bed"]) .^ 2
    src_classes = Int8.(0:length(sources_of[product])-1)
    src_attrib = Pair{String,Any}["flag_values" => collect(src_classes),
                                  "flag_meanings" => join(reverse(sources_of[product]), " ")]

    for og in dom.grids[2:end]
        t0 = time()
        g = og.grid
        m = AlignedMap(g, base)
        f = Dict{String,Matrix}()
        for name in MEANS
            f[name] = remap(m, fb[name])[1]
        end
        f["z_bed_sd"] = Float32.(sqrt.(max.(remap(m, z2)[1] .- Float64.(f["z_bed"]) .^ 2, 0.0)))
        f["mask"] = dominant_mask(f)
        fr, _ = remap_fractions(g, base, fb["src_id"], src_classes)
        f["src_id"] = Int8.(map(I -> argmax([fr[c][I] for c in src_classes]), CartesianIndices(f["mask"])) .- 1)

        write_fields(product_file(og, product), g, f; dataset=DATASET,
            attrib=["product" => product, "sources" => join(sources_of[product], " > "),
                    "base_grid" => base.name],
            varattrib=Dict("mask" => MASK_ATTRIB, "src_id" => src_attrib))
        println(rpad(g.name, 16), rpad("$(join(size(g), " x "))", 14), "$(round(time() - t0; digits=1)) s  ",
                product_file(og, product))
    end
end
