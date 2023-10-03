#######################
# assemble_coordinates

function assemble_coordinates(;
    origin,
    ticks_coordinates,
    ticks = Makie.automatic,
    xticks = ticks,
    yticks = ticks,
    kwargs...,
)
    if ticks_coordinates == :WebMercator
        return (; xticks, yticks, kwargs...)
    end

    if isnothing(ticks_coordinates)
        return kwargs
    end

    unit = 1.0
    if ticks_coordinates isa Tuple{Any, Any}
        unit = ticks_coordinates[2]
        ticks_coordinates = ticks_coordinates[1]
    end

    if ticks_coordinates == :EastingNorthing
        return (;
            xticks = EastingTicks(;
                origin_wmy = origin[2],
                ticks = xticks,
                unit
            ),
            yticks = NorthingTicks(;
                origin_wmy = origin[2],
                ticks = yticks,
                unit
            ),
            kwargs...
        )
    end

    error("Unknown coordinate system: $ticks_coordinates")
end


################
# NorthingTicks

struct NorthingTicks
    origin_wmy::Float32
    ticks::Any
    unit::Float32
end

function NorthingTicks(;
    origin_wmy = 0,
    ticks = Makie.automatic,
    unit = u"m"
)
    NorthingTicks(
        origin_wmy,
        ticks,
        canonicalize(unit)
    )
end

function Makie.get_ticks(
    ticks::NorthingTicks,
    scale,
    format,
    shifted_wmy_min, shifted_wmy_max
)
    origin_wmy = ticks.origin_wmy
    origin_north = north_from_lat(lat_from_wmy(origin_wmy))

    (shifted_north_min, shifted_north_max) = (
        (shifted_wmy_min, shifted_wmy_max)
        .|> shifted_wmy -> shifted_wmy + origin_wmy
        .|> wmy -> clamp(wmy, -1, 1)
        .|> wmy -> lat_from_wmy(wmy)
        .|> lat -> north_from_lat(lat)
        .|> north -> (north - origin_north) / ticks.unit
    )

    (shifted_north, labels) =
        Makie.get_ticks(
            ticks.ticks,
            scale,
            format,
            shifted_north_min,
            shifted_north_max,
        )

    shifted_wmy = (
        shifted_north
        .|> shifted_north -> ticks.unit * shifted_north + origin_north
        .|> lat_from_north
        .|> wmy_from_lat
        .|> wmy -> wmy - origin_wmy
    )

    return ( shifted_wmy, labels )
end

###############
# EastingTicks

struct EastingTicks
    origin_wmy::Float64
    ticks::Any
    unit::Float32
end

function EastingTicks(;
    origin_wmy = 0,
    ticks = Makie.automatic,
    unit = u"m"
)
    EastingTicks(
        origin_wmy,
        ticks,
        canonicalize(unit)
    )
end

function Makie.get_ticks(
    ticks::EastingTicks,
    scale,
    format,
    wmx_min, wmx_max
)
    origin_lat = lat_from_wmy(ticks.origin_wmy)

    (east_min, east_max) = (
        (wmx_min, wmx_max)
        .|> wnx -> lon_from_wmx(wnx)
        .|> lon -> east_from_lon(lon, origin_lat)
        .|> east -> east / ticks.unit
    )

    (east, labels) =
        Makie.get_ticks(
            ticks.ticks,
            scale,
            format,
            east_min,
            east_max,
        )

    wmx = (
        east
        .|> east -> ticks.unit * east
        .|> east -> lon_from_east(east, origin_lat)
        .|> lon -> wmx_from_lon(lon)
    )

    return ( wmx, labels )
end


###############
# canonicalize

canonicalize(unit::Unitful.LengthUnits) = canonicalize(1unit)
canonicalize(unit::Unitful.Length) = canonicalize(ustrip(u"m", unit))
canonicalize(unit::Number) = canonicalize(Float32(unit))
canonicalize(unit::Float32) = unit
