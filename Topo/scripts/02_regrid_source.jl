#
# Remap one original dataset onto the base grid of a domain. Writes z_bed, z_srf,
# H_ice, z_bed_sd, the area fractions f_ocn, f_land, f_grnd, f_flt, and f_valid (the
# fraction of each cell covered by the source) to $FESMDATA_WORK/topo/<BASE>/.
#
# Usage:
#     julia --project=Topo -t N Topo/scripts/02_regrid_source.jl DOMAIN SOURCE
#
include(joinpath(@__DIR__, "..", "common.jl"))
include(joinpath(TOPO_DIR, "sources.jl"))

length(ARGS) == 2 || error("usage: 02_regrid_source.jl DOMAIN SOURCE")
dom = Domain(ARGS[1])
source = ARGS[2]
base = dom.base

# Remapping onto the base grid, by source grid type
remapper(src::ProjGrid) = (m = AlignedMap(base, src); F -> remap(m, F))
fractions(src::ProjGrid, M) = remap_fractions(base, src, M, MASK_CLASSES)

# Lon-lat sources: samples spaced at most half the source latitude spacing
nsub(src::LonLatGrid) = max(1, ceil(Int, 2 * spacing(base)[1] / (src.dlat * 111.195)))
remapper(src::LonLatGrid) = F -> remap(base, src, F; nsub=nsub(src))
fractions(src::LonLatGrid, M) = remap_fractions(base, src, M, MASK_CLASSES; nsub=nsub(src))

_sq(v) = ismissing(v) ? missing : Float64(v)^2

t0 = time()
src = read_source(source, dom)
println("Read $source: $(size(src.grid)) cells, $(round(time() - t0; digits=1)) s")

t0 = time()
rmp = remapper(src.grid)
fields = Dict{String,Matrix{Float32}}()
z_bed, f_valid = rmp(src.z_bed)
fields["z_bed"] = z_bed
fields["f_valid"] = f_valid
fields["z_srf"] = rmp(src.z_srf)[1]
fields["H_ice"] = rmp(src.H_ice)[1]

# Standard deviation from the cell means of z_bed and z_bed^2
z2 = rmp(map(_sq, src.z_bed))[1]
fields["z_bed_sd"] = Float32.(sqrt.(max.(z2 .- Float64.(z_bed) .^ 2, 0.0)))

fr, _ = fractions(src.grid, src.mask)
for (name, c) in (("f_ocn", OCEAN), ("f_land", LAND), ("f_grnd", GRND), ("f_flt", FLT))
    fields[name] = fr[c]
end
println("Remapped onto $(base.name): $(round(time() - t0; digits=1)) s, threads=$(Threads.nthreads())")

path = write_fields(source_file(dom, source), base, fields;
                    attrib=["source" => source, "history" => "Topo/scripts/02_regrid_source.jl"])
println("Wrote $path")
