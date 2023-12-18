module MapMakie

using FileIO
using HTTP
using LRUCache
using Makie
using MapMaths
using Unitful

export MapAxis

include("mapped_ticks.jl")
include("ticks_coordinate.jl")
include("map_axis.jl")

end # module MapMakie
