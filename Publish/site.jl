# Static website of the published products (GitHub Pages), from the registry and
# datasets.toml: one section per dataset, one table per record with its grids and files.

include(joinpath(@__DIR__, "registry.jl"))

const SITE_CSS = """
:root { --bg: #ffffff; --fg: #1d2329; --muted: #5d6873; --line: #dde3e8; --accent: #1f6f9f; --code: #f2f5f7; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #14181c; --fg: #e3e8ec; --muted: #9aa6b1; --line: #2d353c; --accent: #6db3e0; --code: #1d2329; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 16px/1.55 system-ui, sans-serif; }
main { max-width: 960px; margin: 0 auto; padding: 32px 16px 64px; }
h1 { margin: 0 0 4px; font-size: 28px; }
h2 { margin: 40px 0 8px; font-size: 22px; border-bottom: 1px solid var(--line); padding-bottom: 6px; }
h3 { margin: 24px 0 6px; font-size: 18px; }
p, li { color: var(--fg); }
.muted { color: var(--muted); }
a { color: var(--accent); }
code, pre { background: var(--code); border-radius: 4px; font-size: 14px; }
code { padding: 1px 4px; }
pre { padding: 10px 12px; overflow-x: auto; }
table { width: 100%; border-collapse: collapse; font-size: 14px; }
th, td { text-align: left; padding: 4px 8px 4px 0; border-bottom: 1px solid var(--line); vertical-align: top; }
td.size { text-align: right; white-space: nowrap; color: var(--muted); }
details { margin: 4px 0; }
summary { cursor: pointer; }
.wrap { overflow-x: auto; }
"""

esc(s) = replace(string(s), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

function human_size(n::Integer)
    n < 1e6 && return "$(round(n / 1e3; digits=1)) kB"
    n < 1e9 && return "$(round(n / 1e6; digits=1)) MB"
    return "$(round(n / 1e9; digits=2)) GB"
end

"Resolution of a grid name in metres (ANT-4KM, GRL-PAL-500M), for sorting."
function grid_resolution(grid::AbstractString)
    m = match(r"-(\d+(?:\.\d+)?)(KM|M)$", grid)
    m === nothing && return Inf
    return parse(Float64, m[1]) * (m[2] == "KM" ? 1000 : 1)
end

"Grids of a record, by region prefix and then resolution, with their files."
function record_grids(files::AbstractDict)
    grids = Dict{String,Vector{Pair{String,Any}}}()
    for (name, e) in files
        push!(get!(grids, entry_grid(e), Pair{String,Any}[]), name => e)
    end
    order = sort(collect(keys(grids)); by=g -> (replace(g, r"-[\d.]+K?M$" => ""), grid_resolution(g)))
    return [g => sort(grids[g]; by=first) for g in order]
end

function record_html(io::IO, domain::AbstractString, dataset::AbstractString)
    info, files = read_record(domain, dataset)
    total = sum(e -> get(e, "size", 0), values(files); init=0)
    concept = get(info, "concept_doi", "")
    println(io, "<h3>$(esc(domain))</h3>")
    println(io, "<p>Version $(esc(get(info, "version", "?"))) ($(esc(get(info, "publication_date", ""))), ",
            "<a href=\"https://doi.org/$(esc(get(info, "doi", "")))\">doi:$(esc(get(info, "doi", "")))</a>",
            isempty(concept) ? "" : "; all versions: <a href=\"https://doi.org/$(esc(concept))\">doi:$(esc(concept))</a>",
            "). $(length(files)) files, $(human_size(total)).</p>")
    println(io, "<pre>julia --project=Publish Publish/scripts/fetch.jl $(esc(domain)) $(esc(dataset)) [GRID ...]</pre>")
    for (grid, entries) in record_grids(files)
        size = sum(e -> get(e, "size", 0), last.(entries); init=0)
        println(io, "<details><summary><b>$(esc(grid))</b> <span class=\"muted\">",
                "$(length(entries)) files, $(human_size(size))</span></summary><div class=\"wrap\"><table>")
        for (name, e) in entries
            println(io, "<tr><td><a href=\"$(esc(e["uri"]))\">$(esc(name))</a></td>",
                    "<td class=\"size\">$(human_size(get(e, "size", 0)))</td></tr>")
        end
        println(io, "</table></div></details>")
    end
end

"""
    write_site(dir)

Write the website (index.html) into `dir`.
"""
function write_site(dir::AbstractString)
    datasets = TOML.parsefile(joinpath(@__DIR__, "datasets.toml"))
    records = list_records()
    mkpath(dir)
    open(joinpath(dir, "index.html"), "w") do io
        println(io, """
            <!doctype html>
            <html lang="en"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>FesmData products</title>
            <style>$SITE_CSS</style></head><body><main>
            <h1>FesmData products</h1>
            <p class="muted">Processed datasets for ice-sheet and Earth-system models, on the
            grids of each model domain.</p>
            <p>The products are made with <a href="$REPO_URL">FesmData</a> and archived on
            <a href="https://zenodo.org/communities/fesmc">Zenodo</a>, one record per dataset
            and domain, with a DOI per version. Each grid has its own files, with its grid
            description for cdo (<code>grid_&lt;GRID&gt;.txt</code>) and grid file
            (<code>&lt;GRID&gt;_grid.nc</code>). To download into <code>\$ICE_DATA/v2/&lt;Domain&gt;/&lt;GRID&gt;/</code>
            and verify the checksums, from a clone of FesmData:</p>
            <pre>julia --project=Publish -e 'using Pkg; Pkg.instantiate()'
            julia --project=Publish Publish/scripts/fetch.jl                  # list the records
            julia --project=Publish Publish/scripts/fetch.jl Antarctica Topo ANT-8KM</pre>
            <p>Coarser or other grids can be made from the base grids with the FesmData
            pipelines; see the README of each dataset.</p>""")
        for dataset in sort(filter(!startswith("_"), collect(keys(datasets))))
            cfg = datasets[dataset]
            println(io, "<h2>$(esc(dataset)): $(esc(cfg["title"]))</h2>")
            println(io, "<p>$(esc(strip(replace(cfg["description"], '\n' => ' ')))) ",
                    "<a href=\"$REPO_URL/blob/main/$(esc(cfg["readme"]))\">README</a></p>")
            recs = [d for (d, s) in records if s == dataset]
            isempty(recs) && println(io, "<p class=\"muted\">Not published yet.</p>")
            foreach(d -> record_html(io, d, dataset), recs)
        end
        println(io, "</main></body></html>")
    end
    return joinpath(dir, "index.html")
end
