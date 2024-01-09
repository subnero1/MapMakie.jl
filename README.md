# MapMakie.jl

Plot on OpenStreetMap using Makie.

## Example

![](README.png)

```julia
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
save("/tmp/merlion.png", f)
```

## Documentation

#### MapAxis

```
MapAxis(args...; origin, kwargs...) -> axis::Makie.Axis
```

Create a new `Axis` showing OpenStreetMap.

The object returned by this function is a plain `Makie.Axis` and can be used to plot additional data like any other `Axis`. The map is shown in `MapMaths.WebMercator` coordinates shifted by `-WebMercator(origin)`.

All positional arguments and any keyword arguments other than the ones mentioned below are forwarded to `Axis()`.

##### Keyword arguments

- `origin::MapMaths.Coordinate{2}`: Map origin.

  This parameter serves two purposes:
  1) Avoid the loss of precision that would otherwise be incurred for locations at high latitudes and longitudes due to Makie performing most computations in `Float32`. See also [Loss of precision when plotting large floats in Makie](https://github.com/MakieOrg/Makie.jl/issues/1196) and related issues in Makie.jl.
  2) Set the origin for the x- and y-ticks if `ticks_coordinate` is `EastNorth` (see `ticks_coordinate` below).

- `ticks_coordinate = WebMercator`: The coordinate system in which to show the x- and y-ticks.

  Can be any subtype of `MapMaths.Coordinate{2}`, or `(MapMaths.EastNorth, unit)` where `unit` is either a plain number denoting meters, a `Unitful.LengthUnits` or a `Unitful.Length`. `EastNorth` ticks are shown relative to `origin`, all other ticks are shown using their global values.

- `limits = ((-1,1), (-1,1))`: Axis limits.

  Follows the same format as `Makie.Axis()`, except that any number can also be a `MapMaths.EastWestCoordinate` or `MapMaths.NorthSouthCoordinate` as appropriate. `East` and `North` limits are applied relative to `origin`, all other limits are applied as global values.

- `tile_provider = TileProviders.OpenStreetMap()`: Any tile provider from the `TileProviders` package.

## Technical details

MapMakie dynamically loads the map tiles required from https://tile.openstreetmap.org/. Users of this package must therefore adhere to [OpenStreetMap's Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/). The most-recently used 100 MB of map tiles are cached in memory using [LRUCache.jl](https://github.com/JuliaCollections/LRUCache.jl).