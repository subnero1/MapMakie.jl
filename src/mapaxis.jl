"""
    MapAxis(args...; origin, kwargs...) -> axis::Axis

Create a new `Makie.Axis` showing OpenStreetMap.

The object returned by this function is a standard `Makie.Axis` and can be used
to plot additional data like any other `Makie.Axis`. The map is shown in
WebMercator coordinates normalized to the unit square `[0,1]^2` and shifted by
`-origin`. Any additional (keyword) arguments are forwarded to `Axis()`.

# Example
```
function webmercator(lat, lon)
    return (
        lon/360 + 0.5,
        0.5 - log(tand(45+lat/2))/(2π)
    )
end

origin = webmercator(1.286770, 103.854307) # The Merlion, Singapore
f = Figure(resolution = 400 .* (4,3))
a = MapAxis(
    f[1,1];
    origin,
    limits = (-1,1,-1,1)./40_000,
)
scatter!(
    a,
    Point2f[(0,0)],
    color = :red,
    markersize = 30,
    strokewidth = 10,
)
display(f)
```
"""
function MapAxis(
    args...;
    origin,
    coordinate_system = nothing,
    kwargs...
)
    kwargs = assemble_coordinates(; origin, coordinate_system, kwargs...)

    axis = Axis(
        args...;
        autolimitaspect = 1.0,
        yreversed = true,
        limits = ((0,1) .- origin[1], (0,1) .- origin[2]),

        kwargs...,
    )

    if isnothing(coordinate_system)
        hidedecorations!(axis)
    end

    limits = axis.finallimits[]
    limits = Rect2f(origin .+ limits.origin, limits.widths)
    resolution = axis.scene.camera.resolution[]

    (; zoom, xmin, xmax, ymin, ymax) = tile_indices(limits, resolution)
    img = image!(
        map_limits(zoom, xmin, xmax) .- origin[1],
        map_limits(zoom, ymin, ymax) .- origin[2],
        map_image(; zoom, xmin, xmax, ymin, ymax)
    )
    onany(axis.finallimits, axis.scene.camera.resolution) do limits, resolution
        limits = Rect2f(origin .+ limits.origin, limits.widths)
        (; zoom, xmin, xmax, ymin, ymax) = tile_indices(limits, resolution)
        img[1][] = map_limits(zoom, xmin, xmax) .- origin[1]
        img[2][] = map_limits(zoom, ymin, ymax) .- origin[2]
        img[3][] = map_image(; zoom, xmin, xmax, ymin, ymax)
    end

    return axis
end

const tile_cache = LRU{Tuple{Int,Int,Int}, Any}(maxsize = Int(1e8), by = Base.summarysize)
function map_tile(zoom, x, y)
    @assert 0 <= y <= 1<<zoom-1
    reduced_x = mod(x, 1<<zoom)
    return get!(
        () -> load(HTTP.URI("https://tile.openstreetmap.org/$zoom/$reduced_x/$y.png")),
        tile_cache,
        (zoom, reduced_x, y),
    )
end

function map_image(; zoom, xmin, xmax, ymin, ymax)
    map = Matrix{RGBf}(undef, 256*(xmax-xmin+1), 256*(ymax-ymin+1))
    @sync for y in ymin:ymax, x in xmin:xmax
        @async map[
            256*(x-xmin) .+ (1:256),
            256*(y-ymin) .+ (1:256),
        ] .= map_tile(zoom, x, y)'
    end
    return map
end

map_limits(zoom, min, max) = Float32[min, max+1]./(1<<zoom)

function tile_indices(limits, resolution)
    zoom = clamp(round(Int, log2(first(resolution ./ widths(limits)))) - 9, 0, 19)
    (xmin,ymin) = floor.(Int, 2.0^zoom .* minimum(limits))
    (xmax,ymax) =  ceil.(Int, 2.0^zoom .* maximum(limits)) .- 1
    (ymin, ymax) = clamp.((ymin, ymax), 0, 1<<zoom-1)
    return (; zoom, xmin, xmax, ymin, ymax)
end
