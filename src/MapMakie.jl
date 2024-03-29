module MapMakie

using FileIO
using HTTP
using IntervalSets
using LRUCache
using Makie
using MapMaths
using TileProviders
using Unitful

export MapAxis

include("mapped_ticks.jl")
include("ticks_coordinate.jl")
include("limits.jl")
include("map_axis.jl")

end # module MapMakie
