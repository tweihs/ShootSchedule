import pandas as pd
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter


def test_geocode_a():
    gl = Nominatim(user_agent="ClubFinder")
    gc = RateLimiter(gl.geocode, min_delay_seconds=1)
    loc = gc("CHEROKEE GUN CLUB,1700 CANDLER ROAD,,GAINESVILLE,GA,30503,USA")
    print(loc)


def test_geocoding(address):
    try:
        geolocator = Nominatim(user_agent="ClubFinder")
        location = geolocator.geocode(address)
        if location:
            print(f"Latitude: {location.latitude}, Longitude: {location.longitude}")
        else:
            print("Location not found.")
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    test_geocoding("1600 Amphitheatre Parkway, Mountain View, CA")