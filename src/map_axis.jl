"""
    MapAxis(args...; origin, kwargs...) -> axis::Makie.Axis

Create a new `Axis` showing OpenStreetMap.

The object returned by this function is a plain `Makie.Axis` and can be used to
plot additional data like any other `Axis`. The map is shown in
`MapMaths.WebMercator` coordinates shifted by `-WebMercator(origin)`.

All positional arguments and any keyword arguments other than the ones mentioned
below are forwarded to `Axis()`.

# Keyword arguments

- `origin::MapMaths.Coordinate{2}`: Map origin.

  This parameter serves two purposes:
  1) Avoid the loss of precision that would otherwise be incurred for locations
     at high latitudes and longitudes due to Makie performing most computations
     in `Float32`. See also [Loss of precision when plotting large floats in
     Makie](https://github.com/MakieOrg/Makie.jl/issues/1196) and related issues
     in Makie.jl.
  2) Set the origin for the x- and y-ticks if `ticks_coordinate` is `EastNorth`
     (see `ticks_coordinate` below).

- `ticks_coordinate = WebMercator`: The coordinate system in which to show the
  x- and y-ticks.

  Can be any subtype of `MapMaths.Coordinate{2}`, or `(MapMaths.EastNorth,
  unit)` where `unit` is either a plain number denoting meters, a
  `Unitful.LengthUnits` or a `Unitful.Length`. `EastNorth` ticks are shown
  relative to `origin`, all other ticks are shown using their global values.

- `limits = ((-1,1), (-1,1))`: Axis limits.

  Follows the same format as `Makie.Axis()`, except that any number can also be
  a `MapMaths.EastWestCoordinate` or `MapMaths.NorthSouthCoordinate` as
  appropriate. `East` and `North` limits are applied relative to `origin`, all
  other limits are applied as global values.

- `tile_provider - OpenStreetMap()`: Where to get map tiles from.

  `tile_provider` must be such that `FileIO.load(tile_provider(zoom, x, y)`
  loads the map tile covering
  ```
  map(
      (x,y) -> MapMaths.WebMercator((0.5^(zoom-1) .* (x,y) .- 1)...),
      x .+ (0,1),
      y .+ (0,1)
  )
  ```

  MapMakie provides the following tile providers:

  - `OpenStreetMap()`: Load map tiles from the OpenStreetMap tile server.

# Example

```
using GLMakie, MapMakie, MapMaths, Unitful
f = Figure()
a = MapAxis(
    f[1,1];
    origin = LatLon(1.286770, 103.854307), # Merlion, Singapore
    ticks_coordinate = (EastNorth, u"km"),
    limits = (East.(2e3.*(-1,1)), North.(2e3.*(-1,1))),
)
scatter!(
    a,
    Point2f[(0,0)], # WebMercator coordinates relative to `origin`
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
    tile_provider = OpenStreetMap(),
    ticks_coordinate = WebMercator,
    limits = ((-1,1), (-1,1)),
    kwargs...
)
    origin = WebMercator(origin)
    kwargs = map_ticks_coordinate(;
        plot_coordinate = WebMercator,
        ticks_coordinate,
        origin,
        kwargs...,
    )
    axis = Axis(
        args...;
        autolimitaspect = 1.0,
        limits = convert_limits(WebMercator, limits; origin),
        kwargs...,
    )

    limits = axis.finallimits[]
    limits = Rect2f(origin .+ limits.origin, limits.widths)
    resolution = axis.scene.camera.resolution[]

    (; zoom, xmin, xmax, ymin, ymax) = tile_indices(limits, resolution)
    img = image!(
        ClosedInterval((map_xlimits(zoom, xmin, xmax) .- origin[1])...),
        ClosedInterval((map_ylimits(zoom, ymin, ymax) .- origin[2])...),
        map_image(; tile_provider, zoom, xmin, xmax, ymin, ymax)
    )
    onany(axis.finallimits, axis.scene.camera.resolution) do limits, resolution
        limits = Rect2f(origin .+ limits.origin, limits.widths)
        (; zoom, xmin, xmax, ymin, ymax) = tile_indices(limits, resolution)
        img[1][] = ClosedInterval((map_xlimits(zoom, xmin, xmax) .- origin[1])...)
        img[2][] = ClosedInterval((map_ylimits(zoom, ymin, ymax) .- origin[2])...)
        img[3][] = map_image(; tile_provider, zoom, xmin, xmax, ymin, ymax)
    end

    return axis
end

"""
    OpenStreetMap()

Load map tiles from the OpenStreetMap tile server.
"""
OpenStreetMap() = (zoom, x, y) -> HTTP.URI("https://tile.openstreetmap.org/$zoom/$x/$y.png")

const tile_cache = LRU{Tuple{Int,Int,Int}, Any}(maxsize = Int(1e8), by = Base.summarysize)
function map_tile(tile_provider, zoom::Int, x::Int, y::Int)
    @assert 0 <= y <= 1<<zoom-1
    reduced_x = mod(x, 1<<zoom)
    return get!(
        () -> load(tile_provider(zoom, reduced_x, y)),
        tile_cache,
        (zoom, reduced_x, y),
    )
end

function map_image(; tile_provider, zoom, xmin, xmax, ymin, ymax)
    map = Matrix{RGBf}(undef, 256*(xmax-xmin+1), 256*(ymax-ymin+1))
    @sync for y in ymin:ymax, x in xmin:xmax
        @async map[
            256*(x-xmin) .+ (1:256),
            256*(ymax-y) .+ (1:256),
        ] .= rotr90(map_tile(tile_provider, zoom, x, y))
    end
    return map
end

map_xlimits(zoom, min, max) = (min, max+1) .* 2f0^(1-zoom) .- 1f0
map_ylimits(zoom, min, max) = 1f0 .- (max+1, min) .* 2f0^(1-zoom)

function tile_indices(limits, resolution)
    zoom = clamp(round(Int, log2(first(resolution ./ widths(limits)))) - 7, 0, 19)
    xmin = floor(Int, 2f0^(zoom-1) * (minimum(limits)[1] + 1f0))
    ymin = floor(Int, 2f0^(zoom-1) * (1f0 - maximum(limits)[2]))
    xmax =  ceil(Int, 2f0^(zoom-1) * (maximum(limits)[1] + 1f0)) - 1
    ymax =  ceil(Int, 2f0^(zoom-1) * (1f0 - minimum(limits)[2])) - 1
    (ymin, ymax) = clamp.((ymin, ymax), 0, 1<<zoom-1)
    return (; zoom, xmin, xmax, ymin, ymax)
end
