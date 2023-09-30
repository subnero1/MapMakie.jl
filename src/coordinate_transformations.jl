###########################################
# Web Mercator <--> latitude and longitude

wmx_from_lon(lon) = (lon + 180)/ 360
lon_from_wmx(wmx) = 360*wmx - 180

function wmy_from_lat(lat)
    @assert abs(lat) <= 90
    return 0.5 - log(tand(lat/2 + 45)) / (2π)
end

lat_from_wmy(wmy) = 2*atand(exp(2π * (0.5 - wmy))) - 90


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
