# MapMakie.jl - OpenStreetMap in Makie

## Example

![](README.png)

```julia
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
save("/tmp/merlion.png", f)
```

## Installation

```julia
julia> using Pkg; Pkg.add(url="https://github.com/subnero1/MapMakie.jl")
```

## Technical details

- Dynamically loads map tiles from https://tile.openstreetmap.org/.
- Caches up to 100 MB of map tiles in memory using [LRUCache.jl](https://github.com/JuliaCollections/LRUCache.jl).
- Users of this package must adhere to [OpenStreetMap's Tile Usage Policy
](https://operations.osmfoundation.org/policies/tiles/).
- Coming soon: offline mode, and better integration with [MapMaths.jl](https://github.com/subnero1/MapMaths.jl).