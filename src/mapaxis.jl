"""
    MapAxis(args...; origin, kwargs...) -> axis::Axis

Create a new `Makie.Axis` showing OpenStreetMap.

The object returned by this function is a standard `Makie.Axis` and can be used
to plot additional data like any other `Makie.Axis`. The map is shown in
WebMercator coordinates normalized to the square `[-1,1]^2` and shifted by
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
        limits = ((-1,1) .- origin[1], (-1,1) .- origin[2]),
        kwargs...,
    )

    limits = axis.finallimits[]
    limits = Rect2f(origin .+ limits.origin, limits.widths)
    resolution = axis.scene.camera.resolution[]

    (; zoom, xmin, xmax, ymin, ymax) = tile_indices(limits, resolution)
    img = image!(
        map_xlimits(zoom, xmin, xmax) .- origin[1],
        map_ylimits(zoom, ymin, ymax) .- origin[2],
        map_image(; zoom, xmin, xmax, ymin, ymax)
    )
    onany(axis.finallimits, axis.scene.camera.resolution) do limits, resolution
        limits = Rect2f(origin .+ limits.origin, limits.widths)
        (; zoom, xmin, xmax, ymin, ymax) = tile_indices(limits, resolution)
        img[1][] = map_xlimits(zoom, xmin, xmax) .- origin[1]
        img[2][] = map_ylimits(zoom, ymin, ymax) .- origin[2]
        img[3][] = map_image(; zoom, xmin, xmax, ymin, ymax)
    end

    return axis
end

const tile_cache = LRU{Tuple{Int,Int,Int}, Any}(maxsize = Int(1e8), by = Base.summarysize)
function map_tile(zoom::Int, x::Int, y::Int)
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
            256*(ymax-y) .+ (1:256),
        ] .= rotr90(map_tile(zoom, x, y))
    end
    return map
end

map_xlimits(zoom, min, max) = [min, max+1] .* 2f0^(1-zoom) .- 1f0
map_ylimits(zoom, min, max) = 1f0 .- [max+1, min] .* 2f0^(1-zoom)

function tile_indices(limits, resolution)
    zoom = clamp(round(Int, log2(first(resolution ./ widths(limits)))) - 8, 0, 19)
    xmin = floor(Int, 2f0^(zoom-1) * (minimum(limits)[1] + 1f0))
    ymin = floor(Int, 2f0^(zoom-1) * (1f0 - maximum(limits)[2]))
    xmax =  ceil(Int, 2f0^(zoom-1) * (maximum(limits)[1] + 1f0)) - 1
    ymax =  ceil(Int, 2f0^(zoom-1) * (1f0 - minimum(limits)[2])) - 1
    (ymin, ymax) = clamp.((ymin, ymax), 0, 1<<zoom-1)
    return (; zoom, xmin, xmax, ymin, ymax)
end
