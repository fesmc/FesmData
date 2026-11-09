# Prepare the basal shear stress of PaleoMIST 1.0 (Gowan et al., 2021) for remapping: the
# shear stress domains (polygons) of ICESHEET 2.0 and their values through time, as used for
# the published reconstruction (minimal and maximal MIS 3 scenarios alike), one prepared
# NetCDF file per region in $FESMDATA_PREPARED/Gowan2021_PaleoMIST_taub/:
# Gowan2021_PaleoMIST_taub_<region>.nc (NorthAmerica, with Greenland; Eurasia; Antarctica;
# not Patagonia), on the 5 km grid of the region in ICESHEET (the nodes of its shear stress
# grids, those of the regional reconstructions of PaleoMIST), with
#
#   taub_domain(x, y)    domain of each node (domain_id); the nodes with ice in any time
#                        slice of PaleoMIST outside all polygons are in the domain 0 of
#                        their region (5000 Pa, as in ICESHEET); the other nodes within
#                        EXTEND_KM of that ice get the nearest domain; missing elsewhere
#   taub_map(x, y)       base shear stress of the domain (Pa)
#   mask_extended(x, y)  1 where the domain is the nearest one (beyond the polygons and
#                        the ice), 0 in the polygons and the ice, missing elsewhere
#
# and, in every file, all domains of the three regions (dimension `domain`):
# domain_id = 1000 region + id of Gowan, region (1 North_America, 2 Eurasia,
# 3 Antarctica), taub = taub_max (base value), taub_min, and taub_t(domain, time), the
# value at each time slice of the reconstruction (80000 to 0 years ago).
#
# How create_ss_grid (ICESHEET) sets the shear stress of a time slice (see README.md):
# the value of each domain is that of domains_max.txt (else the attribute of its polygon
# in the GMT file); the lines `domain t_max t_min ss_min` of adjust_0.txt, in the order of
# the file, change it at the times t between t_min and t_max: linearly from ss_min at
# t_min to the current value at t_max (ss_min = 0: the value of domains_min.txt, 5000 Pa
# if none), or to the value of domains_min.txt for ss_min < 0. A node gets the value of
# the last polygon containing it (even-odd rule), 5000 Pa outside all polygons.
#
# Usage:
#     julia --project=Gowan2021_PaleoMIST_taub Gowan2021_PaleoMIST_taub/prepare.jl
#     julia fesmdata.jl remap IceHistory PaleoMIST_taub

using FesmUtils
using NCDatasets
import Proj

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "gowan2021_icesheet"           # ICESHEET 2.0 (GitHub), global/ setup of PaleoMIST
const KEY_PALEOMIST = "gowan2021_paleomist" # PaleoMIST 1.0: grids and ice of the regions

# Time slices of PaleoMIST (years ago), oldest first
const TIMES = collect(80000:-2500:0)

# Shear stress of the nodes outside all domains (nominal_shear_stress of create_ss_grid),
# and the minimum of the domains without a value in domains_min.txt
const NOMINAL = 5000

# Domain of the ice outside all polygons (id 1000 region in the files), and of no node
# (0) on the grids of the regions
const NOMINAL_DOMAIN = -1

# Distance (km) from the ice of a region (any time slice, 5 km grid) within which the
# nodes outside the polygons get the nearest domain: the ice of IceHistory-PaleoMIST on
# the model grids reaches beyond these margins (the 25 km Gaussian filter of the 0.25°
# grids of the author, their cells of up to 28 km, the remapping smoothing of up to 3 x
# 14 km and the model cells), so that every cell with ice there has a domain
const EXTEND_KM = 150.0

# Regions: code, folder in ICESHEET global/ and PaleoMIST, name of the prepared file,
# domain file (shear_stress_domain_file of projection_info.sh), projection of the
# polygons (QGIS, x and y from the projection centre) and lower-left corner (lon, lat) of
# the GMT grids (x and y from that corner; none for Antarctica, centred on the pole).
const REGIONS = [
    (code=1, name="North_America", file="NorthAmerica", domains="shear_stress_domains.gmt",
     proj="+proj=laea +lat_0=60 +lon_0=-94 +datum=WGS84 +units=m", corner=(-135.0, 25.0)),
    (code=2, name="Eurasia", file="Eurasia", domains="shear_stress_domains.gmt",
     proj="+proj=laea +lat_0=90 +lon_0=0 +datum=WGS84 +units=m", corner=(-12.0, 47.0)),
    (code=3, name="Antarctica", file="Antarctica", domains="shear_stress_domains3.gmt",
     proj="+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +datum=WGS84 +units=m", corner=nothing),
]

"""
    read_domains(path) -> (polygons, attr)

Polygons of a GMT (OGR) text file of shear stress domains, in the order of the file, as
(domain, x, y) in m, and the shear stress attribute of each domain (Pa, that of its last
polygon), as create_ss_grid reads them: the line `# @D...|domain|shear_stress|...` after
each `>`.
"""
function read_domains(path)
    polygons = Tuple{Int,Vector{Float64},Vector{Float64}}[]
    attr = Dict{Int,Int}()
    for line in eachline(path)
        if startswith(line, ">")
            push!(polygons, (0, Float64[], Float64[]))
        elseif startswith(line, "# @D")
            f = split(line[5:end], '|')
            d, v = parse(Int, f[2]), parse(Int, f[3])
            polygons[end] = (d, polygons[end][2], polygons[end][3])
            attr[d] = v
        elseif startswith(line, "#") || isempty(strip(line))
            continue
        else
            x, y = parse.(Float64, split(line)[1:2])
            push!(polygons[end][2], x)
            push!(polygons[end][3], y)
        end
    end
    any(p -> p[1] == 0 || length(p[2]) < 3, polygons) && error("$path: polygon without domain or points")
    return polygons, attr
end

"Pairs `a b` of the integer table `path` (domains_max.txt, domains_min.txt), empty if none."
function read_pairs(path)
    isfile(path) || return Dict{Int,Int}()
    t = Dict{Int,Int}()
    for line in eachline(path)
        f = split(line)
        length(f) >= 2 && (t[parse(Int, f[1])] = parse(Int, f[2]))
    end
    return t
end

"Lines `domain t_max t_min ss_min` of an adjustment file, in their order."
function read_adjust(path)
    rows = NTuple{4,Int}[]
    for line in eachline(path)
        f = split(line)
        length(f) >= 4 || continue
        push!(rows, Tuple(parse.(Int, f[1:4])))
    end
    return rows
end

"""
    shear_stress(base, smin, adjust, t) -> Dict(domain => Pa)

Shear stress of each domain at time `t` (years ago), as create_ss_grid (lines 247-300):
the base values `base`, changed by the lines of `adjust` in their order.
"""
function shear_stress(base::Dict{Int,Int}, smin::Dict{Int,Int}, adjust, t::Int)
    v = copy(base)
    for (d, tmax, tmin, ssmin) in adjust
        haskey(v, d) || continue                 # a domain without polygon
        min(tmax, tmin) <= t <= max(tmax, tmin) || continue
        lo = get(smin, d, NOMINAL)
        if ssmin >= 0
            tmax == tmin && error("adjustment of domain $d with t_max = t_min")
            x1, y1 = Float64(tmin), Float64(ssmin == 0 ? lo : ssmin)
            x2, y2 = Float64(tmax), Float64(v[d])
            slope = (y2 - y1) / (x2 - x1)
            v[d] = round(Int, slope * t + (y1 - slope * x1), RoundNearestTiesAway)   # nint
        else
            v[d] = lo
        end
    end
    return v
end

# Even-odd test of create_ss_grid (point_in_polygon of global_parameters.f90)
function inside(xs, ys, x, y)
    n = length(xs)
    (xs[1] == xs[n] && ys[1] == ys[n]) && (n -= 1)
    c = false
    for k in 1:n
        k2 = k == n ? 1 : k + 1
        if min(ys[k], ys[k2]) < y && max(ys[k], ys[k2]) >= y
            xs[k] + (y - ys[k]) / (ys[k2] - ys[k]) * (xs[k2] - xs[k]) < x && (c = !c)
        end
    end
    return c
end

"""
    domain_grid(polygons, x, y) -> (D, noverlap)

Domain of each node of the grid `x`, `y` (the polygons in the same coordinates): that of
the last polygon containing it, 0 outside all; `noverlap`, the nodes in polygons of
different domains.
"""
function domain_grid(polygons, x, y)
    D = zeros(Int32, length(x), length(y))
    noverlap = 0
    dx, dy = x[2] - x[1], y[2] - y[1]
    for (d, xs, ys) in polygons
        i0, i1 = max(1, floor(Int, (minimum(xs) - x[1]) / dx) + 1), min(length(x), ceil(Int, (maximum(xs) - x[1]) / dx) + 1)
        j0, j1 = max(1, floor(Int, (minimum(ys) - y[1]) / dy) + 1), min(length(y), ceil(Int, (maximum(ys) - y[1]) / dy) + 1)
        for j in j0:j1, i in i0:i1
            inside(xs, ys, x[i], y[j]) || continue
            D[i, j] != 0 && D[i, j] != d && (noverlap += 1)
            D[i, j] = d
        end
    end
    return D, noverlap
end

"Nodes x, y (m, from the lower-left corner for the Lambert grids) of a regional grid of PaleoMIST."
regional_grid(dir) = NCDataset(ds -> (Float64.(ds["x"].var[:]), Float64.(ds["y"].var[:])), joinpath(dir, "thickness", "0.nc"))

"Nodes with ice (thickness > 0) in any time slice of a regional reconstruction of PaleoMIST."
function ice_any(dir, n)
    ice = falses(n)
    for t in TIMES
        NCDataset(joinpath(dir, "thickness", "$t.nc")) do ds
            ice .|= coalesce.(ds["z"].var[:, :] .> 0, false)
        end
    end
    return ice
end

"""
The domains of a region: global ids, grid of domain ids and base value per node, base,
minimum and time slices of each domain, and the log of the checks.
"""
function prepare_region(r, icesheet, paleomist)
    ssdir = joinpath(icesheet, "global", r.name, "shear_stress")
    polygons, attr = read_domains(joinpath(ssdir, r.domains))
    smax = read_pairs(joinpath(ssdir, "domains_max.txt"))
    smin = read_pairs(joinpath(ssdir, "domains_min.txt"))
    adjust = read_adjust(joinpath(ssdir, "adjust_0.txt"))
    ids = sort(collect(keys(attr)))
    base = Dict(d => get(smax, d, attr[d]) for d in ids)
    vals = [shear_stress(base, smin, adjust, t) for t in TIMES]

    # Grid of the region (GMT, m) and the polygons on it (QGIS, from the projection centre)
    dir = joinpath(paleomist, "ice_reconstruction_files", r.name)
    xg, yg = regional_grid(dir)
    x0, y0 = r.corner === nothing ? (0.0, 0.0) : Proj.Transformation("EPSG:4326", r.proj; always_xy=true)(r.corner)
    shifted = [(d, xs .- x0, ys .- y0) for (d, xs, ys) in polygons]
    D, noverlap = domain_grid(shifted, xg, yg)

    ice = ice_any(dir, size(D))
    nice, nout = count(ice), count(ice .& (D .== 0))
    missing_domains = setdiff(ids, unique(D))
    println("$(r.name): $(length(polygons)) polygons, $(length(ids)) domains ($(length(missing_domains)) " *
            "on no node), $(length(adjust)) adjustments; $(count(!=(0), D)) nodes in domains, $noverlap " *
            "in overlapping polygons; $nice nodes with ice in any time slice, $nout of them outside " *
            "the polygons (domain 0, 5000 Pa)")
    allv = [v[d] for v in vals for d in ids]
    println("    shear stress $(minimum(allv))-$(maximum(allv)) Pa; base $(minimum(values(base)))-" *
            "$(maximum(values(base))) Pa; $(count(d -> any(v -> v[d] != base[d], vals), ids)) domains time dependent")

    # Domain 0: the ice outside all polygons, at the nominal shear stress of ICESHEET
    # (the other nodes outside the polygons are left out: no ice of this region there)
    D[ice .& (D .== 0)] .= NOMINAL_DOMAIN
    ids = [NOMINAL_DOMAIN; ids]
    base[NOMINAL_DOMAIN] = NOMINAL
    vals = [merge(v, Dict(NOMINAL_DOMAIN => NOMINAL)) for v in vals]

    # Nearest domain (distance along the grid) for the other nodes near the ice
    dx = (xg[2] - xg[1]) / 1000
    E = extend_labels(D, distance_to(ice, dx) .<= EXTEND_KM, dx)
    ext = (D .== 0) .& (E .!= 0)
    println("    $(count(ext)) nodes within $(EXTEND_KM) km of the ice get the nearest domain")

    gid(d) = Int32(1000 * r.code + (d == NOMINAL_DOMAIN ? 0 : d))
    dom = map(d -> d == 0 ? missing : gid(d), E)
    taub_map = map(d -> d == 0 ? NaN32 : Float32(base[d]), E)
    mask_ext = map((d, e) -> d == 0 ? missing : Int8(e), E, ext)
    table = (ids=gid.(ids), region=fill(Int8(r.code), length(ids)), base=[base[d] for d in ids],
             min=[get(smin, d, NOMINAL) for d in ids], t=[v[d] for d in ids, v in vals])
    return (x=(xg .+ x0) ./ 1000, y=(yg .+ y0) ./ 1000, dom, taub_map, mask_ext, table,
            stats=(nice=nice, nout=nout, noverlap=noverlap))
end

icesheet = only(filter(isdir, readdir(download_dataset(manifest(), KEY); join=true)))   # icesheet-<commit>/
paleomist = joinpath(download_dataset(manifest(), KEY_PALEOMIST), "ice_reconstruction")
regions = [prepare_region(r, icesheet, paleomist) for r in REGIONS]

# All domains, in every file (variables off the grid are taken from the first file)
ids = reduce(vcat, [g.table.ids for g in regions])
region = reduce(vcat, [g.table.region for g in regions])
base = Float32.(reduce(vcat, [g.table.base for g in regions]))
smin = Float32.(reduce(vcat, [g.table.min for g in regions]))
taub_t = Float32.(reduce(vcat, [g.table.t for g in regions]))
allunique(ids) || error("domain ids not unique")

const REFERENCES = "Gowan, E. J., Zhang, X., Khosravi, S., Rovere, A., Stocchi, P., Hughes, A. L. C., " *
    "Gyllencreutz, R., Mangerud, J., Svendsen, J.-I. and Lohmann, G.: A new global ice sheet reconstruction " *
    "for the past 80 000 years, Nat. Commun., 12, 1199, 2021, doi:10.1038/s41467-021-21469-w; Gowan, E. J., " *
    "Tregoning, P., Purcell, A., Lea, J., Fransner, O. J., Noormets, R. and Dowdeswell, J. A.: ICESHEET 1.0: " *
    "a program to produce paleo-ice sheet reconstructions with minimal assumptions, Geosci. Model Dev., 9, " *
    "1673-1682, 2016, doi:10.5194/gmd-9-1673-2016; code and inputs: ICESHEET 2.0, " *
    "https://github.com/evangowan/icesheet (commit 641d172)"

outdir = prepared_dir("Gowan2021_PaleoMIST_taub")
mkpath(outdir)
for (r, g) in zip(REGIONS, regions)
    path = joinpath(outdir, "Gowan2021_PaleoMIST_taub_$(r.file).nc")
    rm(path; force=true)
    NCDataset(path, "c") do ds
        defVar(ds, "x", g.x, ("x",); attrib=["units" => "km", "standard_name" => "projection_x_coordinate"])
        defVar(ds, "y", g.y, ("y",); attrib=["units" => "km", "standard_name" => "projection_y_coordinate"])
        defVar(ds, "crs", Int32(0), (); attrib=["proj_params" => replace(r.proj, "+units=m" => "+units=km")])
        defVar(ds, "taub_domain", g.dom, ("x", "y"); fillvalue=Int32(-9999), deflatelevel=1, attrib=[
            "units" => "1", "long_name" => "basal shear stress domain (domain_id)", "grid_mapping" => "crs",
            "comment" => "domain of the node: 1000 region + id of the domain in ICESHEET 2.0 " *
                         "(global/<region>/shear_stress); 1000 region (domain 0, 5000 Pa as in ICESHEET) for the " *
                         "nodes with ice in any time slice of PaleoMIST outside all polygons; the nearest domain " *
                         "for the other nodes within $(EXTEND_KM) km of that ice (mask_extended); missing elsewhere; " *
                         "where polygons overlap, the last in the file (as create_ss_grid)"])
        defVar(ds, "taub_map", g.taub_map, ("x", "y"); fillvalue=NaN32, deflatelevel=1, attrib=[
            "units" => "Pa", "long_name" => "basal shear stress, base value of the domain (taub)",
            "grid_mapping" => "crs",
            "comment" => "time independent: the value of domains_max.txt (else of the polygon); the value of each " *
                         "time slice is taub_t of the domain"])
        defVar(ds, "mask_extended", g.mask_ext, ("x", "y"); fillvalue=Int8(-1), deflatelevel=1, attrib=[
            "units" => "1", "long_name" => "domain extended to the node (nearest domain)", "grid_mapping" => "crs",
            "flag_values" => Int8[0, 1], "flag_meanings" => "domain nearest_domain",
            "comment" => "1: outside the polygons and the ice of PaleoMIST (any time slice), within $(EXTEND_KM) km " *
                         "of that ice: the nearest domain (distance along the grid); 0: in the polygons or the ice"])
        defDim(ds, "domain", length(ids))
        defVar(ds, "time", Float64.(TIMES), ("time",); attrib=["units" => "years ago",
               "long_name" => "time (years before 1950 CE)"])
        defVar(ds, "domain_id", Int32.(ids), ("domain",); attrib=["units" => "1", "long_name" => "domain id",
               "comment" => "1000 region + id of the domain in ICESHEET 2.0 (taub_domain); 1000 region: the ice " *
                            "outside all polygons (5000 Pa, nominal_shear_stress of create_ss_grid)"])
        defVar(ds, "region", region, ("domain",); attrib=["units" => "1", "long_name" => "region of the domain",
               "flag_values" => Int8[1, 2, 3], "flag_meanings" => "North_America Eurasia Antarctica"])
        defVar(ds, "taub", base, ("domain",); attrib=["units" => "Pa",
               "long_name" => "basal shear stress of the domain, base value (= taub_max)",
               "comment" => "the value at the time slices outside the adjustments of adjust_0.txt (taub_t)"])
        defVar(ds, "taub_max", base, ("domain",); attrib=["units" => "Pa",
               "long_name" => "basal shear stress of the domain, base value (domains_max.txt, else the polygon)"])
        defVar(ds, "taub_min", smin, ("domain",); attrib=["units" => "Pa",
               "long_name" => "minimum basal shear stress of the domain (domains_min.txt, else 5000 Pa)",
               "comment" => "the value adjust_0.txt decreases to (ss_min <= 0)"])
        defVar(ds, "taub_t", taub_t, ("domain", "time"); attrib=["units" => "Pa",
               "long_name" => "basal shear stress of the domain at each time slice",
               "comment" => "taub changed by the lines of adjust_0.txt (create_ss_grid of ICESHEET 2.0), as used " *
                            "for PaleoMIST 1.0"])
        ds.attrib["title"] = "Basal shear stress of PaleoMIST 1.0 (Gowan et al., 2021): domains and values " *
                             "through time (ICESHEET 2.0)"
        ds.attrib["references"] = REFERENCES
        ds.attrib["doi"] = "10.1038/s41467-021-21469-w"
        ds.attrib["license"] = "GPL-3.0-only (ICESHEET 2.0, E. J. Gowan): derived from the input files of its global/ " *
                               "setup (shear stress domains and values), distributed under the GPL-3.0"
        ds.attrib["comment"] = "Domains of North_America (with Greenland), Eurasia and Antarctica of ICESHEET 2.0 " *
            "(global/<region>/shear_stress/), rasterized at the nodes of the 5 km grids of the regional " *
            "reconstructions of PaleoMIST 1.0 as create_ss_grid does; values from domains_max.txt, domains_min.txt " *
            "and adjust_0.txt, the files of the published reconstruction (both MIS 3 scenarios). Nodes with ice " *
            "in any time slice outside the polygons (domain 1000 region, 5000 Pa as in ICESHEET): " *
            join(("$(q.name) $(h.stats.nout) of $(h.stats.nice)" for (q, h) in zip(REGIONS, regions)), ", ") *
            ". Patagonia is left out."
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
    end
    println("Wrote $path")
end
