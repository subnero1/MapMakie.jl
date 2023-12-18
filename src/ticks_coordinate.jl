"""
    map_ticks_coordinate(;
        plot_coordinate,
        [ticks_coordinate | (ticks_coordinate = MapMaths.EastNorth, unit)],
        origin,
        xticks = Makie.automatic,
        yticks = Makie.automatic,
    ) -> kwargs

Show axis ticks in the `ticks_coordinate` system (optionally scaled by `unit`),
assuming the plot axis are in the `plot_coordinate` system.
"""
function map_ticks_coordinate end

function map_ticks_coordinate(; plot_coordinate, ticks_coordinate, kwargs...)
    map_ticks_coordinate(plot_coordinate, ticks_coordinate; kwargs...)
end

function map_ticks_coordinate(plot_coordinate, ticks_coordinate_and_unit::Tuple; kwargs...)
    return map_ticks_coordinate(plot_coordinate, ticks_coordinate_and_unit...; kwargs...)
end

function map_ticks_coordinate(
    plot_coordinate::Type{<:Coordinate{2}},
    ticks_coordinate::Type{<:Coordinate{2}},
    unit::Union{Number, Unitful.Unit};
    kwargs...,
)
    error("Scaling of $ticks_coordinate coordinates is not supported")
end

function map_ticks_coordinate(
    plot_coordinate::Type{<:Coordinate{2}},
    ticks_coordinate::Type{<:Coordinate{2}};
    origin::Coordinate{2},
    xticks = Makie.automatic,
    yticks = Makie.automatic,
    kwargs...,
)
    plot_ew = EastWestCoordinate(plot_coordinate)
    plot_ns = NorthSouthCoordinate(plot_coordinate)
    ticks_ew = EastWestCoordinate(ticks_coordinate)
    ticks_ns = NorthSouthCoordinate(ticks_coordinate)
    return (;
        xticks = MappedTicks(
            ticks = xticks,
            plot_to_ticks = x -> ticks_ew(plot_ew(x) + plot_ew(origin))[],
            ticks_to_plot = x -> plot_ew(ticks_ew(x) - ticks_ew(origin))[],
        ),
        yticks = MappedTicks(
            ticks = yticks,
            plot_to_ticks = x -> ticks_ns(plot_ns(x) + plot_ns(origin))[],
            ticks_to_plot = x -> plot_ns(ticks_ns(x) - ticks_ns(origin))[],
        ),
        axis_labels(ticks_coordinate)...,
    )
end

axis_labels(::Type{WebMercator}) = (;)
function axis_labels(::Union{Type{LatLon}, Type{LonLat}})
    return (;
        xlabel = "Latitude [°]",
        ylabel = "Longitude [°]",
    )
end

function map_ticks_coordinate(
    plot_coordinate::Type{<:Coordinate{2}},
    ticks_coordinate::Type{EastNorth};
    kwargs...,
)
    return map_ticks_coordinate(plot_coordinate, ticks_coordinate, u"m"; kwargs...)
end

function map_ticks_coordinate(
    plot_coordinate::Type{<:Coordinate{2}},
    ticks_coordinate::Type{EastNorth},
    unit::Number;
    kwargs...,
)
    return map_ticks_coordinate(plot_coordinate, ticks_coordinate, unit*u"m"; kwargs...)
end

function map_ticks_coordinate(
    plot_coordinate::Type{<:Coordinate{2}},
    ::Type{EastNorth},
    unit::Union{Unitful.LengthUnits, Unitful.Length};
    origin::Coordinate{2},
    xticks = Makie.automatic,
    yticks = Makie.automatic,
    kwargs...,
)
    return (;
        east_north_ticks(unit, WMY(origin), xticks, yticks)...,
        xlabel = "Easting [$unit]",
        ylabel = "Northing [$unit]",
        kwargs...,
    )
end

function east_north_ticks(unit::Unitful.LengthUnits, wmy::WMY, xticks, yticks)
    return east_north_ticks(1*unit, wmy, xticks, yticks)
end

function east_north_ticks(unit::Unitful.Length, wmy::WMY, xticks, yticks)
    factor = ustrip(u"m", unit)
    return (;
        xticks = MappedTicks(
            ticks = xticks,
            plot_to_ticks = x -> East(WMX(x), wmy)[] / factor,
            ticks_to_plot = x -> WMX(East(x * factor), wmy)[],
        ),
        yticks = MappedTicks(
            ticks = yticks,
            plot_to_ticks = y -> North(WMY(y), wmy)[] / factor,
            ticks_to_plot = y -> WMY(North(y * factor), wmy)[],
        ),
    )
end
