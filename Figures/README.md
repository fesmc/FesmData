# Figures of the products for the website

Each dataset page of the website ends with a section of figures, made from the
products as released (the files in `$ICE_DATA/v2`), so that users see what they
download:

```bash
julia fesmdata.jl figures <Dataset>
```

writes a PNG per product and the section, `gallery.md`, to `docs/figures/<Dataset>/`,
which the page of the dataset (`docs/datasets/<name>.qmd`) includes at its end:

```
{{< include ../figures/<Dataset>/gallery.md >}}
```

The figures are committed (about 100-300 kB each) and made again when a dataset is
released. They need all files of the products, so they are made on Levante, on a
login node (a few minutes; Bagge2021 and the global 0.1° files are read one field at
a time):

```bash
source shared/machines/levante.env
julia --project=Figures -e 'using Pkg; Pkg.instantiate()'   # once
julia fesmdata.jl figures IceHistory
```

A new dataset needs the include line in its page, and its figures before the site is
published (the include fails without `gallery.md`).

## Gridded products

One figure per released product: a column per domain, on the grid with about 300
cells along its longer side (e.g. ANT-16KM, GRL-PAL-8KM, NH-32KM, GLOBAL-1DEG), and
a row per field, with a colour bar per row. The crops of a domain (Greenland,
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
thickness), and the bed around Jakobshavn Isbræ on grids of 1, 4 and 16 km
(`topo.jl`). Regions has worked examples of the region codes, zones and basins
(`regions.jl`): snippets of Julia code, run in order to make their maps, and shown
on the page with their output.
