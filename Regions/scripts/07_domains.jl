#
# Masks of the nests and crops of a domain family (a root domain with all its nests and
# crops) on all grids of a domain or nest of the family (and its crops). A cell is 1 in
# domain_<KEY> if its centre lies within the extent of nest or crop KEY, the cell edges
# of its base grid (centres on an edge are inside). Needs no other step.
#
# Usage:
#     julia --project=Regions Regions/scripts/07_domains.jl DOMAIN [--folder=FOLDER]
#
# Writes $FESMDATA/<folder>/<GRID>/<GRID>_DOMAINS.nc, with one variable
# domain_<KEY> (int8, 0/1) per active nest and crop of the family; nothing if it has
# none. With --folder, only on the grids in output folder FOLDER (e.g. the grids added to
# a crop).
#
include(joinpath(@__DIR__, "..", "common.jl"))

args, folder = folder_option(ARGS)
length(args) == 1 || error("usage: 07_domains.jl DOMAIN [--folder=FOLDER]")
dom = Domain(args[1])
subs = family_subdomains(dom.key)
if isempty(subs)
    @info "the family of $(dom.key) has no active nests or crops: no DOMAINS files"
    exit()
end

"Extent of a nest or crop: the cell edges (x0, x1, y0, y1, km) of its base grid, and that grid."
function extent(sub)
    base = folder_base(sub.folder)
    h = spacing(base)[1] / 2
    return (base.xc[1] - h, base.xc[end] + h, base.yc[1] - h, base.yc[end] + h), base
end

ext = Dict(s.key => extent(s) for s in subs)
for s in subs
    e, base = ext[s.key]
    @info "domain_$(s.key): $(s.kind) of $(s.parent), extent $(round.(e; digits=3)) km ($(base.name))"
end

for og in filter(og -> !og.on_request, in_folder(dom.grids, folder, dom))
    g = og.grid
    tol = 1e-6 * spacing(g)[1]
    fields = Dict{String,Any}()
    attrib = Dict{String,Vector{Pair{String,Any}}}()
    for s in subs
        (x0, x1, y0, y1), base = ext[s.key]
        inx = x0 - tol .<= g.xc .<= x1 + tol
        iny = y0 - tol .<= g.yc .<= y1 + tol
        name = "domain_$(s.key)"
        fields[name] = Int8.(inx .& permutedims(iny))
        attrib[name] = ["units" => "1", "long_name" => s.folder, "kind" => s.kind, "parent" => s.parent,
                        "extent" => [x0, x1, y0, y1],
                        "comment" => "1 where the cell centre lies within the extent of $(s.folder), " *
                                     "the cell edges x0, x1, y0, y1 (km) of its base grid $(base.name)"]
    end
    write_fields(domains_file(og), g, fields; dataset=DATASET, varattrib=attrib,
                 attrib=["title" => "Nests and crops of $(root_key(dom.key)) (FesmData/Regions)"])
    @info "wrote $(g.name): " * join(["$k $(count(==(1), fields[k]))" for k in sort(collect(keys(fields)))], ", ")
end
