from geopy.geocoders import GoogleV3


def test_geocoding(address, api_key):
    try:
        geolocator = GoogleV3(api_key="AIzaSyDGsAWaEy8X2j0k8x26yGxlkJcnPJASAtI")
        location = geolocator.geocode(address)
        if location:
            print(f"Latitude: {location.latitude}, Longitude: {location.longitude}")
        else:
            print("Location not found.")
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    # Replace 'YOUR_API_KEY' with your actual Google Maps API key
    test_geocoding("1600 Amphitheatre Parkway, Mountain View, CA", "YOUR_API_KEY")