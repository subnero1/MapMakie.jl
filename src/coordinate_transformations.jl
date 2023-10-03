###########################################
# Web Mercator <--> latitude and longitude

"""
    webmercator(lat, lon) -> (wmx, wmy)

Convert latitude and longitude to Web Mercator coordinates.

Latitude and longitude are assumed to be in degrees, and the Web Mercator
coordinates are shifted and scaled such that we have the following identities.

```
webmercator( 0, 0 ) == (0, 0)
webmercator(  90, 0 ) == (0,  Inf)
webmercator( -90, 0 ) == (0, -Inf)
webmercator( 0,  180 ) == ( 1, 0)
webmercator( 0, -180 ) == (-1, 0)
```

This form of the Web Mercator coordinates was chosen because it yields the
following properties.

- The longitude-to-`wmx` conversion is a linear rather than an affine function
  (namely `wmx = lon / 180`). This is useful because it means we can convert
  translations `d_lon` and `d_wmx` using the same function as we use for
  converting points `lon` and `wmx`.

- It preserves the signs of both the east-west and north-south coordinate pairs,
  i.e. `sign(lon) == sign(wmx)` and `sign(lat) == sign(wmy)`. This is useful
  because some Makie ticks functions struggle with inverted axes.
"""
webmercator(lat, lon) = (wmx_from_lon(lon), wmy_from_lat(lat))

wmx_from_lon(lon) = lon/180
lon_from_wmx(wmx) = 180*wmx

function wmy_from_lat(lat)
    @assert abs(lat) <= 90
    return log(tand((lat+90)/2)) / π
end

lat_from_wmy(wmy) = 2*atand(exp(π * wmy)) - 90


###################################################
# Easting and northing <--> latitude and longitude

# WGS84 ellipsoid
const a = 6.378137e6
const inv_f = 298.257_223_563
const f = inv(inv_f)
const b = a * (1-f)
const e2 = (2 - f) / inv_f

function N(lat)
    s,c = sincosd(lat)
    return a^2/sqrt((a*c)^2 + (b*s)^2)
end

lon_from_east(east, lat) = 180*east / (π*ror_from_lat(lat))
east_from_lon(lon, lat) = π*ror_from_lat(lat)*lon / 180
ror_from_lat(lat) = N(lat) * cosd(lat)

function north_from_lat(lat)
    @assert abs(lat) <= 90
    return a * (1-f)^2 * Elliptic.Pi(e2, lat*π/180, e2)
end

function lat_from_north(north)
    @assert abs(north) <= north_from_lat(90)
    return bisect(lat -> north_from_lat(lat) - north, -90.0, 90.0)
end

function bisect(f, a, b)
    fa = f(a)
    fb = f(b)
    @assert sign(fa) != sign(fb)
    while true
        m = (a+b)/2
        fm = f(m)
        if a == m || b == m
            break
        end
        if sign(fa) == sign(fm)
            a,fa = m,fm
        else
            b,fb = m,fm
        end
    end
    return a
end
