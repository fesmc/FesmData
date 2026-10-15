# Records by cropping (see README.md, Download): the products of a thematic dataset on a
# nest or crop without a record of its own (`CropRecord`, catalog.jl), cut from the files
# of the record of its parent domain or of a crop that contains it, so that thematic
# products are released once. Run by `fesmdata.jl fetch` after it downloaded these
# files, in the Publish environment, with catalog.jl included.

using NCDatasets

include(joinpath(REPO_DIR, "shared", "domains.jl"))
include(joinpath(REPO_DIR, "shared", "io.jl"))

"Indices on the lattice of axis `axis` (cell centres, also beyond it) of the cells of axis `sub`, or `nothing` if not on it."
function lattice_indices(sub::AbstractVector, axis::AbstractVector)
    r = axis[2] - axis[1]
    i = round(Int, (sub[1] - axis[1]) / r) + 1
    idx = i:i+length(sub)-1
    return isapprox(axis[1] .+ r .* (idx .- 1), sub; atol=1e-6r) ? idx : nothing
end

"""
    crop_grid(c, sg) -> Union{Tuple{ProjGrid,UnitRange{Int},UnitRange{Int}},String}

Grid of record by cropping `c` for the grid `sg` of its source record, with its cells in
`sg` (x and y index ranges): the grid of the nest or crop at the resolution of `sg`, if
it has one, so that the files are next to its other datasets (e.g. Topo); it must lie
on the lattice of `sg`, as the grids of nests and crops lie on those of their domain.
Else the cells of the lattice of `sg` that overlap the extent of the base grid of the
nest or crop (cell edges), named after it (e.g. THW-4KM): the same cells for all its
sources, which lie on the grids of its domain. The reason to skip the grid instead if
these cells are not all in `sg` (a crop of the domain that does not cover the nest or
crop on this grid), or fewer than 2 along x or y (not a grid).
"""
function crop_grid(c::CropRecord, sg::ProjGrid)
    r = spacing(sg)[1]
    inside(ix, iy) = issubset(ix, eachindex(sg.xc)) && issubset(iy, eachindex(sg.yc))
    outside = "$(c.folder) is not inside $(sg.name)"
    _, own = folder_grids(c.folder)
    k = findfirst(og -> isapprox(spacing(og.grid)[1], r; rtol=1e-6), own)
    if k === nothing
        ix, iy = overlap_cells(sg, folder_base(c.folder))
        (length(ix) < 2 || length(iy) < 2) && return "$(c.folder) is within less than 2 cells along x or y"
        inside(ix, iy) || return outside
        return ProjGrid(crop_grid_name(c, sg.name), sg.xc[ix], sg.yc[iy], sg.proj), ix, iy
    end
    g = own[k].grid
    ix, iy = lattice_indices(g.xc, sg.xc), lattice_indices(g.yc, sg.yc)
    (ix === nothing || iy === nothing) &&
        error("grid $(g.name) of $(c.folder) is not on grid $(sg.name) of $(c.source) (cell centres): " *
              "its files cannot be cut from those of $(c.source)")
    inside(ix, iy) || return outside
    return g, ix, iy
end

"Grid `name` of a file written by `write_fields` or `write_grid_nc` (its axes and projection)."
file_grid(path::AbstractString, name::AbstractString) =
    NCDataset(ds -> ProjGrid(name, ds["xc"][:], ds["yc"][:], ds["crs"].attrib["proj_params"]), path)

"Whether grid `a` has the cell centres of grid `b`."
on_grid(a::ProjGrid, b::ProjGrid) = size(a) == size(b) && isapprox(a.xc, b.xc) && isapprox(a.yc, b.yc)

"""
    regrid_crops(dir, g, gridfiles)

Prepare the folder `dir` of a grid whose grid files (`gridfiles`) are not those of grid
`g` (the grid of a nest or crop changed in ../shared/domains.toml since they were
written): if it holds only crops (files with `cropped_from`), they and the grid files
were written by cropping, so the crops not on `g` are removed, to be cropped again on
the new grid (of their dataset now, of the others when they are fetched). Files of
records of the nest or crop itself are on the grid of their release, which cannot be
changed here: an error until they are released again.
"""
function regrid_crops(dir::AbstractString, g::ProjGrid, gridfiles)
    files = filter(f -> endswith(f, ".nc") && f != gridfiles[2], readdir(dir; join=true))
    own = filter(f -> !NCDataset(ds -> haskey(ds.attrib, "cropped_from"), f), files)
    isempty(own) ||
        error("$(gridfiles[2]) is not grid $(g.name) of ../shared/domains.toml (of a release made before the grid " *
              "changed?): cannot add crops on this grid until its records ($(join(basename.(own), ", "))) are " *
              "released again")
    for f in files
        on_grid(file_grid(f, g.name), g) && continue
        rm(f)
        println(rpad("removed", 12), f, " (old grid)")
    end
    return nothing
end

"Whether `path` is the crop of the source file with `checksum` on the cells `ix`, `iy` (by its attributes)."
is_crop_of(path::AbstractString, checksum::AbstractString, ix, iy) =
    isfile(path) && NCDataset(path) do ds
        get(ds.attrib, "cropped_from_checksum", "") == checksum &&
            get(ds.attrib, "cropped_index_xc", "") == string(ix) && get(ds.attrib, "cropped_index_yc", "") == string(iy)
    end

"""
    crop_nc(src, dst, g, ix, iy; history, attrib)

Write `dst`, a copy of the NetCDF file `src` cut to the cells `ix`, `iy` of its grid
dimensions xc and yc, which give grid `g`: the variables with these dimensions are cut,
all others copied, as stored (raw values, attributes, compression); the global
attributes are those of `src`, with the grid name of `g`, the entry `history` added to
its history, and `attrib`. Written as `<dst>.part` and renamed when complete.
"""
function crop_nc(src::AbstractString, dst::AbstractString, g::ProjGrid, ix::UnitRange, iy::UnitRange;
                 history::AbstractString, attrib)
    mkpath(dirname(dst))
    part = dst * ".part"
    cut = Dict("xc" => ix, "yc" => iy)
    NCDataset(src) do s
        isapprox(s["xc"][ix], g.xc) && isapprox(s["yc"][iy], g.yc) || error("$src is not on the grid of its record")
        NCDataset(part, "c") do d
            foreach(((k, v),) -> d.attrib[k] = v, s.attrib)
            d.attrib["grid_name"] = g.name
            d.attrib["history"] = history * "\n" * get(s.attrib, "history", "")
            foreach(((k, v),) -> d.attrib[k] = v, attrib)
            unlimited = NCDatasets.unlimited(s)
            for (name, n) in s.dim
                defDim(d, name, name in unlimited ? Inf : haskey(cut, name) ? length(cut[name]) : n)
            end
            for name in keys(s)
                v = s[name].var
                dims = dimnames(v)
                shuffle, deflate, level = NCDatasets.deflate(v)
                w = defVar(d, name, eltype(v), dims; attrib=collect(v.attrib), shuffle=shuffle,
                           deflatelevel=deflate ? level : 0)
                if isempty(dims)
                    w.var[] = v[]
                else
                    data = v[(get(cut, dn, Colon()) for dn in dims)...]
                    w.var[(1:n for n in size(data))...] = data   # ranges, which also extend unlimited dimensions
                end
            end
        end
    end
    mv(part, dst; force=true)
    return dst
end

"""
    crop_files(cropped, root; sandbox=false) -> Vector{String}

Make the records by cropping `cropped` ((record, grids) of `select_records`, all grids
if none are named) under `root`, from the files of their source records there
(downloaded by `fetch_files`). On each grid (`crop_grid`, which may skip it): the grid
files, if missing (those of the grids of the nest or crop come with its own records),
and the crop of the file of each product on the source grid, with global attributes
recording the source file (`cropped_from`, its checksum and release) and its cells
(`cropped_index_xc`, `cropped_index_yc`, 1-based ranges). A crop already there is kept
if it is of the same source file (checksum) and cells, and made again otherwise (e.g.
after a new release). Returns the local paths.
"""
function crop_files(cropped, root::AbstractString; sandbox::Bool=false)
    paths = String[]
    for (c, grids) in cropped
        tables, files = read_record(c.source, c.dataset; sandbox=sandbox)
        release = tables["_RELEASE"]
        println("\n$(c.folder)/$(c.dataset), cropped from $(c.source)/$(c.dataset) $(release["version"])")
        tag = dataset_tag(c.dataset)
        for (sgrid, entries) in record_grids(files)
            isempty(grids) || crop_grid_name(c, sgrid) in grids || continue
            targets = crop_data_files(c, last.(entries), root)
            isempty(targets) && continue
            cut = crop_grid(c, file_grid(local_path(first(first(targets)), root), sgrid))
            if cut isa AbstractString
                println(rpad("skipped", 12), "$sgrid: $cut")
                continue
            end
            g, ix, iy = cut
            dir = joinpath(root, c.folder, g.name)
            gridfiles = [joinpath(dir, "grid_$(g.name).txt"), joinpath(dir, "$(g.name)_grid.nc")]
            status = all(isfile, gridfiles) ? :present : (write_grid_files(dir, g; dataset=tag); :written)
            if !on_grid(file_grid(gridfiles[2], g.name), g)
                regrid_crops(dir, g, gridfiles)
                write_grid_files(dir, g; dataset=tag)
                status = :rewritten
            end
            foreach(p -> println(rpad(string(status), 12), p), gridfiles)
            append!(paths, gridfiles)
            for (e, dst) in targets
                src = local_path(e, root)
                status = is_crop_of(dst, e["checksum"], ix, iy) ? :present : isfile(dst) ? :updated : :cropped
                if status != :present
                    from = relpath(src, root)
                    crop_nc(src, dst, g, ix, iy; history="$(history_entry()): cropped from $from", attrib=[
                        "cropped_from" => from,
                        "cropped_from_checksum" => e["checksum"],
                        "cropped_from_release" => "$(c.dataset) $(release["version"]) ($(release["git_tag"]))",
                        "cropped_index_xc" => string(ix),
                        "cropped_index_yc" => string(iy)])
                end
                println(rpad(string(status), 12), dst)
                push!(paths, dst)
            end
        end
    end
    return paths
end
