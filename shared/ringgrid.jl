# Points of an equal-area grid (rings of constant latitude) on a regular lon-lat grid,
# for sources given as such points (e.g. Lösing and Ebbing, 2021; Colgan and Wansing,
# 2021; Fox Maule et al., 2005). No package dependencies.

"""
    ring_grid(lon, lat, cols; dlon) -> (lons, lats, fields)

Points on rings of constant latitude (an equal-area grid: rings evenly spaced in latitude,
points spaced about as much divided by cos(latitude) in longitude) on a regular lon-lat grid with the
ring latitudes and a longitude spacing `dlon`: each cell takes the values `cols` of the
nearest point of its ring, if within half the spacing of the ring (plus 1%), so that each point
fills its own equal-area cell. A point at a pole fills its ring.
"""
function ring_grid(lon, lat, cols; dlon)
    rings = sort(unique(lat))
    dlat = minimum(diff(rings))
    lats = rings[1]:dlat:rings[end]
    all(r -> any(l -> isapprox(l, r; atol=1e-6), lats), rings) || error("rings are not regularly spaced")
    lons = collect(-180 + dlon / 2:dlon:180 - dlon / 2)
    fields = [fill(NaN32, length(lons), length(lats)) for _ in cols]
    for (j, φ) in enumerate(lats)
        k = findall(l -> isapprox(l, φ; atol=1e-6), lat)
        isempty(k) && continue
        λ = mod.(lon[k] .+ 180, 360) .- 180            # 180 becomes -180 (same point)
        d = length(λ) > 1 ? minimum(filter(>(1e-6), diff(sort(unique(λ))))) : dlat / cosd(φ)
        for (i, l) in enumerate(lons)
            dist = abs.(mod.(λ .- l .+ 180, 360) .- 180)
            m = argmin(dist)
            (abs(φ) ≈ 90 || dist[m] <= 0.51d) || continue      # 1%: spacings rounded in the file
            for (F, c) in zip(fields, cols)
                F[i, j] = c[k[m]]
            end
