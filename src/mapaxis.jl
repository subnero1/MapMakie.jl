"""
    MapAxis(args...; origin, kwargs...) -> axis::Makie.Axis

Create a new `Axis` showing OpenStreetMaps.

The object returned by this function is a plain `Makie.Axis` and can be used to
plot additional data like any other `Axis`. The map is shown in Web Mercator
coordinates (see `webmercator`) and shifted by `-origin`.

All positional arguments and any keyword arguments other than the ones mentioned
below are forwarded to `Axis()`.

# Keyword arguments

- `origin`: Origin of the map in Web Mercator coordinates.

  This parameter serves two purposes:

  1) Set the origin for the x- and y-ticks (see `ticks_coordinates` below).

  2) Avoid the loss of precision that would otherwise be incurred for locations
     at high latitudes and longitudes due to Makie performing most computations in
     `Float32`.

  # Example

  An error of `eps(Float32(180))` in the x-component of a Web Mercator
  coordinate at latitude 0° translates into an easting error of roughly 300
  meters. This means that with `origin = (0,0)`, locations near `lat = 0°`, `lon
  = 180°` would generally be rounded by up to 150m. By contrast, if we set
  `origin = (1,0)`, then rounding in such location is proportional to their
  distance to `lat = 0°`, `lon = 180°`, which can be much smaller.

  See also [Loss of precision when plotting large floats in Makie](https://github.com/MakieOrg/Makie.jl/issues/1196)
  and related issues in Makie.jl.

- `ticks_coordinates`: The coordinate system in which to show the x- and y-ticks.

  The following coordinate systems are currently supported:

  - `:WebMercator` (default)

  - `nothing`: Don't show any x- and y-ticks.

  - `:EastingNorthing` or `(:EastingNorthing, unit)` where `unit` can be any of
    the following.

    - A `Number`. Will be interpreted in meters.
    - A `Unitful.LengthUnits`
    - A `Unitfule.Lengths`

# Example

```
using GLMakie, MapMakie, Unitful

origin = webmercator(1.286770, 103.854307) # The Merlion, Singapore
f = Figure(resolution = 200 .* (4,3))
a = MapAxis(
    f[1,1];
    origin,
    ticks_coordinates = (:EastingNorthing, u"km"),
    xlabel = "Easting [km]",
    ylabel = "Northing [km]",
    limits = (-1,1,-1,1)./10_000, # Web Mercator units relative to `origin`
)
scatter!(
    a,
    Point2f[(0,0)], # Web Mercator units relative to `origin`
    color = :red,
    markersize = 15,
    strokewidth = 6,
)
display(f)
```
"""
function MapAxis(
    args...;
    origin,
    ticks_coordinates = :WebMercator,
    kwargs...
)
    kwargs = assemble_coordinates(; origin, ticks_coordinates, kwargs...)
    axis = Axis(
        args...;
        autolimitaspect = 1.0,
        limits = ((-1,1) .- origin[1], (-1,1) .- origin[2]),
        kwargs...,
    )
    if isnothing(ticks_coordinates)
        hidedecorations!(axis)
    end

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
    zoom = clamp(round(Int, log2(first(resolution ./ widths(limits)))) - 7, 0, 19)
    xmin = floor(Int, 2f0^(zoom-1) * (minimum(limits)[1] + 1f0))
    ymin = floor(Int, 2f0^(zoom-1) * (1f0 - maximum(limits)[2]))
    xmax =  ceil(Int, 2f0^(zoom-1) * (maximum(limits)[1] + 1f0)) - 1
    ymax =  ceil(Int, 2f0^(zoom-1) * (1f0 - minimum(limits)[2])) - 1
    (ymin, ymax) = clamp.((ymin, ymax), 0, 1<<zoom-1)
    return (; zoom, xmin, xmax, ymin, ymax)
end
