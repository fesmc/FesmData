# Figures of Regions: examples of the region codes, zones and basins. Each example is a
# snippet of Julia code, run in order in one module (as in a notebook) and shown on the
# page with its output and the maps of its results.

"""
    Example

An example of the gallery of Regions: a heading, a text before the code, the code (run
as shown), and the maps of its results, `maps(m)` from the variables of the module `m`
the code ran in (`nothing`: no figure).
"""
struct Example
    heading::String
    text::String
    code::String
    maps::Union{Nothing,Function}
    caption::String
end

"Grid of a name, e.g. NH-16KM."
function outgrid(name::AbstractString)
    for key in domain_keys(), og in Domain(key).grids
        og.grid.name == name && return og
    end
    error("no grid $name")
end

"""
    MapPanel

A map of the gallery of Regions: data on a grid, drawn as classes (with their labels
at the centre of their cells, if given), a mask (true cells) or a continuous field.
"""
struct MapPanel
    og::OutGrid
    data::Matrix{Float32}
    kind::Symbol                    # :classes, :mask or :field
    title::String
    labels::Dict{Int,String}        # labels of classes drawn on the map
    names::Dict{Int,String}         # names of classes in a colour bar (none if empty)
end

MapPanel(grid::AbstractString, data, kind::Symbol, title::AbstractString; labels=Dict{Int,String}(),
         names=Dict{Int,String}()) =
    MapPanel(outgrid(grid), Float32.(coalesce.(data, NaN)), kind, title, labels, names)

"Labels of the regions of a variable of a file on a map: the path and name of each code."
function region_labels(ds, var)
    names = flag_names(ds[var].attrib)
    return Dict(c => "$(region_path(c)) $(get(names, c, ""))" for c in unique(skipmissing(ds[var][:, :])) if c > 0)
end

"""
    plot_maps(path, panels)

The maps of an example, side by side, each with its colour bar (none for masks).
"""
function plot_maps(path::AbstractString, panels::Vector{MapPanel})
    fig = Figure(; fontsize=10, figure_padding=6)
    for (j, p) in enumerate(panels)
        ax = map_axis(fig[1, 2j-1], p.og; title=p.title)
        if p.kind == :mask
            heatmap!(ax, map_coords(p.og.grid)..., map(x -> x == 1 ? 1.0f0 : NaN32, p.data);
                     colormap=[RGBf(0.8, 0.2, 0.2), RGBf(0.8, 0.2, 0.2)], colorrange=(0, 2), nan_color=:transparent)
            coastline!(ax, p.og)
        else
            scale = p.kind == :classes ? class_scale(p.data, p.names) : continuous_scale(vec(p.data))
            hm = field!(ax, p.og, p.data, scale)
            (p.kind == :field || !isempty(p.names)) && scale_bar(fig[1, 2j], hm, scale)
        end
        x, y = map_coords(p.og.grid)
        for (c, label) in p.labels
            cells = findall(==(c), p.data)
            isempty(cells) && continue
            text!(ax, median(x[i[1]] for i in cells), median(y[i[2]] for i in cells); text=label, fontsize=7,
                  align=(:center, :center))
        end
        colsize!(fig.layout, 2j - 1, Fixed(round(Int, 1.3 * PANEL_HEIGHT * map_aspect(p.og.grid))))
    end
    rowsize!(fig.layout, 1, Fixed(round(Int, 1.3 * PANEL_HEIGHT)))
    resize_to_layout!(fig)
    save_figure(path, fig)
end

"The examples of the gallery of Regions."
regions_examples() = [
    Example("Reading the files", """
        The regions, zones and basins are read with NCDatasets.jl; FesmUtils.jl has the
        functions for the region codes. All examples below are run as shown, in order,
        to make their maps.""",
        """
        using NCDatasets, FesmUtils

        dir = joinpath(ENV["FESMDATA"], "products", "North", "NH-16KM")
        ds = NCDataset(joinpath(dir, "NH-16KM_REGIONS.nc"))""",
        nothing, ""),

    Example("The tree, level by level", """
        `region_1`, `region_2` and `region_3` hold the codes of the levels of the tree. A
        cell without a subregion keeps the code of its region: the cells of North
        America (1.1) outside its three subregions keep code 101 in `region_3`. The names
        of the codes are in the attributes of each variable.""",
        """
        region_1 = ds["region_1"][:, :]
        region_2 = ds["region_2"][:, :]
        region_3 = ds["region_3"][:, :]

        attrib = ds["region_3"].attrib
        region_names = Dict(zip(attrib["flag_values"], split(attrib["flag_meanings"])))
        println(region_names[region_code("1.1.2")])""",
        m -> [MapPanel("NH-16KM", getproperty(m, Symbol(v)), :classes, v; labels=region_labels(m.ds, v))
              for v in ("region_1", "region_2", "region_3")],
        "The three levels of the regions on NH-16KM, labelled by path and name."),

    Example("Codes and paths", """
        A code has two digits per level below the first, so the path, level and
        ancestors of a region follow from its code. Ocean regions are numbered from 51.""",
        """
        @show region_code("1.1.2")
        @show region_path(10102)
        @show region_level(10102)
        @show region_ancestor(10102, 2)
        @show region_code("1.52");""",
        nothing, ""),

    Example("A region with its subregions", """
        `in_region` selects a region together with all its subregions. Comparing the
        codes of a level with `==` selects only the cells of the region that are in none
        of its subregions.""",
        """
        north_america = in_region(region_3, region_code("1.1"))   # with 1.1.1, 1.1.2, 1.1.3
        rest = region_3 .== region_code("1.1")                    # only the cells in none of them""",
        m -> [MapPanel("NH-16KM", m.north_america, :mask, "in_region(region_3, 101)"),
              MapPanel("NH-16KM", m.rest, :mask, "region_3 .== 101")],
        "North America selected with in_region (left) and with == (right) on NH-16KM."),

    Example("Zones and the shelf break", """
        `zone` separates the open ocean (0), the open ocean within 50 km of the shelf
        break (1), the continental shelf (2) and land (3); `dist_shelfbreak` is the
        distance to the shelf break (km, positive in the open ocean), for other widths
        of the band along it. Combined with the regions, they give e.g. the shelf of a
        region.""",
        """
        zone = ds["zone"][:, :]
        dist = ds["dist_shelfbreak"][:, :]

        shelf = in_region(region_3, region_code("1.2")) .& (zone .== 2)   # shelf of Western Eurasia
        band = 0 .< dist .< 200                                           # open ocean within 200 km""",
        m -> [MapPanel("NH-16KM", m.zone, :classes, "zone"; names=flag_names(m.ds["zone"].attrib)),
              MapPanel("NH-16KM", m.dist, :field, "dist_shelfbreak (km)"),
              MapPanel("NH-16KM", m.shelf, :mask, "shelf of 1.2 Western Eurasia"),
              MapPanel("NH-16KM", m.band, :mask, "0 < dist_shelfbreak < 200")],
        "Zones, distance to the shelf break and their combinations on NH-16KM."),

    Example("Basins", """
        A basin set has the basins (`basin`), extended over the land and shelf of their
        region up to the shelf break, their groups (`basin_group`, if the set has them)
        and the original extent of the basins (`basin_mask`).""",
        """
        grl = joinpath(ENV["FESMDATA"], "products", "GreenlandPaleo", "GRL-PAL-16KM")
        bs = NCDataset(joinpath(grl, "GRL-PAL-16KM_BASINS-Zwally2012.nc"))

        basin = bs["basin"][:, :]
        group = bs["basin_group"][:, :]
        original = ifelse.(bs["basin_mask"][:, :] .== 1, basin, missing)   # before the extension""",
        m -> [MapPanel("GRL-PAL-16KM", m.basin, :classes, "basin"),
              MapPanel("GRL-PAL-16KM", m.group, :classes, "basin_group"; labels=Dict(Int(g) => string(g) for g in unique(m.group) if g > 0)),
              MapPanel("GRL-PAL-16KM", m.original, :classes, "basin within basin_mask")],
        "The Zwally2012 basins of Greenland on GRL-PAL-16KM: basins, their groups (major drainage systems) and their original extent."),

    Example("The same region on every domain", """
        The tree is global, so a region has the same code on all domains and grids.""",
        """
        greenland = map(["North/NH-16KM", "GreenlandPaleo/GRL-PAL-16KM"]) do g
            file = joinpath(ENV["FESMDATA"], "products", g, basename(g) * "_REGIONS.nc")
            NCDataset(d -> in_region(d["region_2"][:, :], region_code("1.3")), file)
        end""",
        m -> [MapPanel("NH-16KM", m.greenland[1], :mask, "1.3 Greenland on NH-16KM"),
              MapPanel("GRL-PAL-16KM", m.greenland[2], :mask, "1.3 Greenland on GRL-PAL-16KM")],
        "Region 1.3 Greenland (its land and EEZ) on NH-16KM and GRL-PAL-16KM."),
]

"""
    run_example(m, code) -> String

Run the code of an example in module `m` and return what it printed.
"""
function run_example(m::Module, code::AbstractString)
    return mktemp() do path, io
        redirect_stdout(io) do
            Base.include_string(m, code, "example")
        end
        flush(io)
        return read(path, String)
    end
end

"""
    regions_figures() -> Vector{String}

The gallery of Regions: the examples, run in order, with their code, output and maps.
"""
function regions_figures()
    m = Module(:RegionsExamples)
    dir = figures_dir("Regions")
    paths = String[]
    open(gallery_file("Regions"), "w") do io
        println(io, "<!-- Generated by `julia fesmdata.jl figures Regions` (do not edit). -->\n")
        println(io, "## Region codes by example\n")
        for (k, ex) in enumerate(regions_examples())
            out = run_example(m, ex.code)
            println(io, "### ", ex.heading, "\n\n", ex.text, "\n\n```julia\n", ex.code, "\n```\n")
            isempty(strip(out)) || println(io, "```\n", rstrip(out), "\n```\n")
            ex.maps === nothing && continue
            file = "Regions-example-$k.png"
            plot_maps(joinpath(dir, file), Base.invokelatest(ex.maps, m))
            println("wrote $file")
            push!(paths, joinpath(dir, file))
            println(io, figure_markdown(ex.caption, "../figures/Regions/$file", joinpath(dir, file)), "\n")
        end
    end
    return [paths; gallery_file("Regions")]
end
