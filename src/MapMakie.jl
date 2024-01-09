module MapMakie

using FileIO
using HTTP
using IntervalSets
using LRUCache
using Makie
using MapMaths
using Unitful

export MapAxis, OpenStreetMap

include("mapped_ticks.jl")
include("ticks_coordinate.jl")
include("limits.jl")
include("map_axis.jl")

end # module MapMakie
