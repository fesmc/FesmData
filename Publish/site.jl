# Static website of the published products (GitHub Pages), from the registry and
# datasets.toml: one section per dataset, one table per record with its grids and files.

include(joinpath(@__DIR__, "catalog.jl"))

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

function record_html(io::IO, domain::AbstractString, dataset::AbstractString)
    tables, files = read_record(domain, dataset)
    release, zenodo = tables["_RELEASE"], get(tables, "_ZENODO", nothing)
    total = sum(e -> get(e, "size", 0), values(files); init=0)
    doi(d) = "<a href=\"https://doi.org/$(esc(d))\">doi:$(esc(d))</a>"
    archive = zenodo === nothing ? "" :
        zenodo["git_tag"] == release["git_tag"] ? "; $(doi(zenodo["doi"])) (all versions: $(doi(zenodo["concept_doi"])))" :
        "; archived versions: $(doi(zenodo["concept_doi"]))"
    println(io, "<h3>$(esc(domain))</h3>")
    println(io, "<p>Version $(esc(release["version"])) ($(esc(release["date"])), ",
            "<a href=\"$(esc(release["store"]))\">packages</a>$archive). ",
            "$(length(files)) files, $(human_size(total)).</p>")
    println(io, "<pre>julia fesmdata.jl fetch $(esc(domain)) $(esc(dataset)) [GRID ...]</pre>")
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

"Getting started: how to find, download and use the products (HTML)."
function guide_html(datasets::AbstractDict)
    packages = "$(datasets["_gitlab"]["url"])/$(datasets["_gitlab"]["project"])/-/packages"
    names = sort(filter(!startswith("_"), collect(keys(datasets))))
    nav = join(["<a href=\"#$(esc(d))\">$(esc(d))</a>" for d in names], " · ")
    return """
        <h1>FesmData products</h1>
        <p class="muted">Processed datasets for ice-sheet and Earth-system models, on the
        grids of each model domain, from the base grid (0.5-2 km) to 32 km.</p>
        <p>The products are made with <a href="$REPO_URL">FesmData</a> and released on
        <a href="$packages">GitLab (DKRZ)</a>, one package per domain, dataset and grid,
        versioned by the release; releases can also be archived on
        <a href="https://zenodo.org/communities/fesmc">Zenodo</a> with a DOI.
        <a href="#start">Getting started</a> · Datasets: $nav</p>

        <h2 id="start">Getting started</h2>

        <h3>1. Get the tool</h3>
        <p>You need <a href="https://julialang.org/downloads/">Julia</a> (a recent version;
        no packages to install) and a copy of FesmData. All commands are run from its
        folder.</p>
        <pre>git clone $REPO_URL.git
        cd FesmData
        julia fesmdata.jl help</pre>

        <h3>2. Choose where the data go</h3>
        <p>The environment variable <code>ICE_DATA</code> sets the folder for the data,
        e.g. in your <code>~/.bashrc</code>:</p>
        <pre>export ICE_DATA=/path/to/ice_data</pre>
        <p>Every file goes to <code>\$ICE_DATA/v2/&lt;Domain&gt;/&lt;GRID&gt;/</code>: one
        folder per domain, and in it one folder per grid with all datasets on that grid.
        A grid folder thus holds everything a model needs on that grid, and can be copied
        as a whole:</p>
        <pre>\$ICE_DATA/v2/
          Antarctica/
            ANT-8KM/
              grid_ANT-8KM.txt                 grid description (cdo)
              ANT-8KM_grid.nc                  lon, lat and area of the cells
              ANT-8KM_TOPO-BedMachine-v4.nc    a product of the dataset Topo
              ANT-8KM_TOPO-Bedmap3.nc
              ...
            ANT-16KM/
          Greenland/
            GRL-4KM/
          ...</pre>
        <p>Domains are named after their folder (Antarctica, Greenland, GreenlandPaleo,
        North, Laurentide, Eurasia, ...), grids after their domain and resolution
        (ANT-8KM, GRL-500M). A grid name thus also gives its domain.</p>

        <h3>3. Find what is there</h3>
        <pre>julia fesmdata.jl list                     # all records (dataset on a domain)
        julia fesmdata.jl list Topo                # the records of a dataset (or of a domain)
        julia fesmdata.jl list Antarctica Topo     # one record: its grids and files, their
                                                   # sizes, and which are already in \$ICE_DATA
        julia fesmdata.jl list ANT-8KM             # everything on a grid</pre>

        <h3>4. Download what you need</h3>
        <pre>julia fesmdata.jl fetch Topo ANT-8KM            # one grid
        julia fesmdata.jl fetch Topo ANT-8KM ANT-16KM   # several grids
        julia fesmdata.jl fetch Antarctica Topo         # all grids of a domain</pre>
        <p><code>fetch</code> needs the dataset, and a domain or grids (the arguments can
        be in any order). Each file is checked against its checksum. Files already
        present are kept; a file that differs (e.g. of an earlier release) stops the
        download, unless <code>--overwrite</code> is given.</p>

        <h3>5. Or mirror everything</h3>
        <p>To keep a copy of all products on a machine (or of a dataset or a domain):</p>
        <pre>julia fesmdata.jl mirror           # everything
        julia fesmdata.jl mirror Topo      # one dataset</pre>
        <p>It shows the total size and what is already there, and asks once before
        downloading. Run it again after new releases to update the copy: only new files
        are downloaded (<code>--yes</code> skips the question, e.g. in a job).</p>

        <h3>6. Versions and citation</h3>
        <p>Each release of a dataset has a version (e.g. Topo 2.0.0, tag
        <code>topo-v2.0.0</code> of FesmData), shown below and by <code>list</code>. Every
        file records how it was made in its global attributes (<code>fesmdata_version</code>,
        <code>fesmdata_commit</code>, <code>sources</code>). Please cite the original
        datasets (see the README of each dataset), and the DOI of the release where there
        is one.</p>
        <p>Single files can also be downloaded directly from the lists below or from
        <a href="$packages">GitLab</a>, without the tool. Other grids can be made from
        the base grids with the FesmData pipelines (see the README of each dataset).</p>
        """
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
            """)
        println(io, guide_html(datasets))
        for dataset in sort(filter(!startswith("_"), collect(keys(datasets))))
            cfg = datasets[dataset]
            println(io, "<h2 id=\"$(esc(dataset))\">$(esc(dataset)): $(esc(cfg["title"]))</h2>")
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
