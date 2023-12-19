function convert_limits(
    C::Type{<:Coordinate{2}},
    limits::NTuple{4, Any};
    origin::Coordinate{2},
)
    return convert_limits(
        C,
        (
            (limits[1], limits[2]),
            (limits[3], limits[4]),
        );
        origin
    )
end

function convert_limits(
    C::Type{<:Coordinate{2}},
    limits::NTuple{2, Any};
    origin::Coordinate{2},
)
    return (
        convert_limits(EastWestCoordinate(C), limits[1]; origin),
        convert_limits(NorthSouthCoordinate(C), limits[2]; origin),
    )
end

function convert_limits(
    ::Type{<:Coordinate{1}},
    ::Nothing;
    origin::Coordinate{2},
)
    return nothing
end

function convert_limits(
    C::Type{<:Coordinate{1}},
    limits::NTuple{2, Any};
    origin::Coordinate{2},
)
    return (
        convert_limit(C, limits[1]; origin),
        convert_limit(C, limits[2]; origin),
    )
end

function convert_limit(
    ::Type{<:Coordinate{1}},
    ::Nothing;
    origin::Coordinate{2}
)
    return nothing
end

function convert_limit(
    ::Type{<:Coordinate{1}},
    v::Number;
    origin::Coordinate{2}
)
    return v
end

function convert_limit(
    C::Type{<:Coordinate{1}},
    c::Coordinate{1};
    origin::Coordinate{2}
)
    (C(c, NorthSouthCoordinate(origin)) - C(origin))[]
end

function convert_limit(
    C::Type{<:Coordinate{1}},
    c::Union{East, North};
    origin::Coordinate{2}
)
    C(c, NorthSouthCoordinate(origin))[]
end
