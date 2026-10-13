# Figures of the products for the website

Each dataset page of the website ends with a section of figures, made from the
products as released (the files in `$FESMDATA_PRODUCTS`), so that users see what they
download:

```bash
julia fesmdata.jl figures <Dataset>
```

writes a PNG per product and the section, `gallery.md`, to `docs/figures/<Dataset>/`,
which the page of the dataset (`docs/datasets/<name>.qmd`) includes at its end (Quarto
`include` of `../figures/<Dataset>/gallery.md`).

The figures (PNG at 2 pixels per unit of their layout, mostly under 1 MB each) are made
again when a dataset is released. They need all files of the products, so they are
made on Levante, on a login node (a few minutes; Bagge2021 and the global 0.1° files
are read one field at a time):

```bash
source shared/machines/levante.env
julia --project=Figures -e 'using Pkg; Pkg.instantiate()'   # once
julia fesmdata.jl figures IceHistory
```

Only the galleries are committed to main; the figures are kept on the site branch
`gh-pages` alone, which has a single commit, so that they are not versioned. The docs
workflow takes them from there to build the site and publishes it again as a single
commit. To put new figures on the site, copy them to a checkout that can push to
GitHub, run `Figures/publish_figures.sh`, and then push the galleries (not while the
docs workflow deploys, which would replace gh-pages without them):

```bash
rsync -a levante:/work/ba1442/robinson/models/FesmData/docs/figures/IceHistory/ docs/figures/IceHistory/
Figures/publish_figures.sh IceHistory
git add docs/figures/IceHistory/gallery.md && git commit -m "Figures: IceHistory" && git push
```

A new dataset needs the include line in its page, and its figures before the site is
published (the include fails without `gallery.md`). Products not made yet (no file on
any of their grids, e.g. a source still to be downloaded) are left out of the figures;
run `figures` again once they are made.

## Gridded products

One figure per released product: a column per domain, on the finest grid with at
most 800 cells along its longer side (e.g. ANT-8KM, GRL-PAL-4KM, NH-16KM, GLOBAL-0.5DEG),
and a row per field, with a colour bar per row. The crops of a domain (Greenland,
Laurentide, Eurasia) are shown only if the domain itself is not. Coastlines are the
ice-free ocean margin of the topography of the domain on the same grid (the Topo
product of the zones of Regions), and the Natural Earth coastline on global grids.

By default the field is the first of the product's `variables` (or of its file), at:

- 21 ka and the present, for a time in years ago;
- the last time of a CF time axis;
- January and July of a monthly climatology;
- the first value of other dimensions (depth, structure, ...).

Integer variables are drawn as classes (named by `flag_values` and `flag_meanings`),
others with the 2-98% range of their values on all panels, symmetric with a diverging
colour map when they have both signs in similar amounts.

The `figure` table of a product in `<Dataset>/remap.toml` changes this:

```toml
figure = { variables = ["uxy_srf"], scale = "log10", colorrange = [1, 3000] }
figure = { select = { depth = [100, 300] }, colormap = "inferno" }
```

| Key | Value |
|---|---|
| `variables` | fields shown, a row each |
| `select` | values of other dimensions, by dimension: a value or a list (a row each); nearest in each file |
| `colormap` | a Makie colour map (e.g. `"viridis"`, `"balance"`, `"ice"`) |
| `colorrange` | `[min, max]` |
| `scale` | `"log10"` |
| `hide` | a value not drawn (e.g. `0`) |

`colormap`, `colorrange`, `scale` and `hide` can also be tables by variable, e.g.
`colormap = { z_bed = "oleron", H_ice = "ice" }`.

`figure = false` leaves a product without a figure, e.g. the products of a dataset
with many similar ones (Paleoclimate shows the LGM of each model only).

## Records

One figure per product: maps of the sites on the domains that contain them (GRL-PAL,
ANT, NH, each site on the first), and the data next to them: a line per site or
region against time (`timeSeries`) or depth (`profile`), or the observations against
their time (`point` with a time). Data at sites without a time or depth (e.g. GPS
uplift rates) colour the sites. The variable is the first data variable on the sites;
`figure = { variable = "dD" }` in `<Dataset>/records.toml` shows another.

## Topo and Regions

Topo has a figure per domain, its products side by side (bed elevation and ice
thickness, with colour ranges from the data of the domain: the bed centred on sea
level where it reaches below, otherwise over the land elevations), and the bed around
Jakobshavn Isbræ on grids of 1, 4 and 16 km (`topo.jl`). Regions has worked examples
of the region codes, zones and basins (`regions.jl`), on the North and on Antarctica:
snippets of Julia code, run in order to make their maps, and shown on the page with
their output.

## Overview of the domains

`julia fesmdata.jl figures Domains` makes an overview figure of each Topo product of
each domain, `docs/figures/Domains/<folder>_TOPO-<product>.png`, linked from the table
of the domains (Domains page; crops link to those of their domain): the bed and surface
elevation and ice thickness of the product, the three levels of the regions (labelled
by path and name), the zones and the basins of each basin set of the domain, on the
finest grid with at most 1600 cells along its longer side (`domains.jl`). They are
large (a few MB) and open on their own; they have no gallery. Publish them as the
other figures (`Figures/publish_figures.sh Domains`).
