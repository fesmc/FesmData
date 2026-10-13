# Records by cropping (see README.md, Download): the files of a dataset on a nest or a
# crop without a record of its own (`CropRecord`, catalog.jl), cut from the files of the
# record of its parent domain, so that thematic datasets are released once. Run by
# `fesmdata.jl fetch` after it downloaded the parent files, in the Publish environment,
# with catalog.jl included.

using NCDatasets

include(joinpath(REPO_DIR, "shared", "domains.jl"))
include(joinpath(REPO_DIR, "shared", "io.jl"))

"Indices of the cells of axis `sub` in axis `parent` (cell centres), or `nothing` if they are not cells of it."
function axis_indices(sub::AbstractVector, parent::AbstractVector)
    r = parent[2] - parent[1]
    i = round(Int, (sub[1] - parent[1]) / r) + 1
    idx = i:i+length(sub)-1
    1 <= first(idx) && last(idx) <= length(parent) && isapprox(parent[idx], sub; atol=1e-6r) || return nothing
    return idx
end

"Indices of the cells of axis `c` (cell centres) that overlap the interval `edges`."
function overlapping(c::AbstractVector, edges)
    h = (c[2] - c[1]) / 2
    idx = findall(x -> x + h > edges[1] + 1e-6h && x - h < edges[2] - 1e-6h, c)
    return isempty(idx) ? (1:0) : first(idx):last(idx)
end

"""
    crop_grid(c, pg) -> Union{Tuple{ProjGrid,UnitRange{Int},UnitRange{Int}},Nothing}

Grid of record by cropping `c` for the grid `pg` of its parent record, with its cells
in `pg` (x and y index ranges): the grid of the nest or crop at the resolution of `pg`,
if it has one, so that the files are next to its other datasets (e.g. Topo); it must
lie on `pg`, as the grids of a nest do at the resolutions it shares with its parent.
Else the cells of `pg` that overlap the extent of the base grid of the nest or crop
(cell edges), named after it (e.g. THW-4KM), or `nothing` if these are fewer than 2
along x or y (not a grid).
"""
function crop_grid(c::CropRecord, pg::ProjGrid)
    r = spacing(pg)[1]
    _, own = folder_grids(c.folder)
    k = findfirst(og -> isapprox(spacing(og.grid)[1], r; rtol=1e-6), own)
    if k !== nothing
        g = own[k].grid
        ix, iy = axis_indices(g.xc, pg.xc), axis_indices(g.yc, pg.yc)
        (ix === nothing || iy === nothing) &&
            error("grid $(g.name) of $(c.folder) is not on grid $(pg.name) of $(c.parent) (cell centres): " *
                  "its files cannot be cut from those of $(c.parent)")
        return g, ix, iy
    end
    base = folder_base(c.folder)
    h = spacing(base)[1] / 2
    ix = overlapping(pg.xc, (base.xc[1] - h, base.xc[end] + h))
    iy = overlapping(pg.yc, (base.yc[1] - h, base.yc[end] + h))
    (length(ix) < 2 || length(iy) < 2) && return nothing
    return ProjGrid(crop_grid_name(c, pg.name), pg.xc[ix], pg.yc[iy], pg.proj), ix, iy
end

"Grid `name` of a file written by `write_fields` or `write_grid_nc` (its axes and projection)."
file_grid(path::AbstractString, name::AbstractString) =
    NCDataset(ds -> ProjGrid(name, ds["xc"][:], ds["yc"][:], ds["crs"].attrib["proj_params"]), path)

"Whether grid `a` has the cell centres of grid `b`."
on_grid(a::ProjGrid, b::ProjGrid) = size(a) == size(b) && isapprox(a.xc, b.xc) && isapprox(a.yc, b.yc)

"Whether `path` is the crop of the parent file with `checksum` on the cells `ix`, `iy` (by its attributes)."
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
if none are named) under `root`, from the files of their parent records there
(downloaded by `fetch_files`). On each grid (`crop_grid`): the grid files, if missing
(those of the grids of the nest or crop come with its own records), and the crop of
each data file of the parent grid, with global attributes recording the parent file
(`cropped_from`, its checksum and release) and its cells (`cropped_index_xc`,
`cropped_index_yc`, 1-based ranges). A crop already there is kept if it is of the same
parent file (checksum) and cells, and made again otherwise (e.g. after a new release).
Returns the local paths.
"""
function crop_files(cropped, root::AbstractString; sandbox::Bool=false)
    paths = String[]
    for (c, grids) in cropped
        tables, files = read_record(c.parent, c.dataset; sandbox=sandbox)
        release = tables["_RELEASE"]
        println("\n$(c.folder)/$(c.dataset), cropped from $(c.parent)/$(c.dataset) $(release["version"])")
        tag = dataset_tag(c.dataset)
        for (pgrid, entries) in record_grids(files)
            isempty(grids) || crop_grid_name(c, pgrid) in grids || continue
            targets = crop_data_files(c, last.(entries), root)
            isempty(targets) && continue
            pg = file_grid(local_path(first(first(targets)), root), pgrid)
            cut = crop_grid(c, pg)
            if cut === nothing
                println(rpad("skipped", 12), "$pgrid: $(c.folder) is within less than 2 cells along x or y")
                continue
            end
            g, ix, iy = cut
            dir = joinpath(root, c.folder, g.name)
            gridfiles = [joinpath(dir, "grid_$(g.name).txt"), joinpath(dir, "$(g.name)_grid.nc")]
            status = all(isfile, gridfiles) ? :present : (write_grid_files(dir, g; dataset=tag); :written)
            # The files there (e.g. of an earlier release) must be on the same grid as the crops
            on_grid(file_grid(gridfiles[2], g.name), g) ||
                error("$(gridfiles[2]) is not grid $(g.name) of ../shared/domains.toml (of a release made before " *
                      "the grid changed?): cannot add crops on this grid until its records are released again")
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
