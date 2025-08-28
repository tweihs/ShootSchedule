import os
import pandas as pd
from geopy.geocoders import GoogleV3


def create_full_address(row):
    address_parts = [
        str(row['Club Name']) if not pd.isna(row['Club Name']) else '',
        str(row['Address 1']) if not pd.isna(row['Address 1']) else '',
        str(row['Address 2']) if not pd.isna(row['Address 2']) else '',
        str(row['City']) if not pd.isna(row['City']) else '',
        str(row['State']) if not pd.isna(row['State']) else '',
        str(row['Country']) if not pd.isna(row['Country']) else ''
    ]
    full_address = ', '.join(filter(None, address_parts))
    return full_address if full_address else f"{row['Club Name']}, {row['Country']}"


def load_cached_locations(filename):
    try:
        cached_data = pd.read_csv(filename)
        return dict(zip(cached_data['full_address'], zip(cached_data['latitude'], cached_data['longitude'])))
    except FileNotFoundError:
        return {}


def geocode_addresses(dataframe, api_key, cached_locations):
    print("Geocoding addresses")
    # Increase timeout to 10 seconds for slow connections
    geolocator = GoogleV3(api_key=api_key, timeout=10)
    location_dict = cached_locations.copy()

    # Create the 'full_address' column
    dataframe['full_address'] = dataframe.apply(create_full_address, axis=1)
    unique_addresses = dataframe['full_address'].unique()
    
    # Count how many need geocoding
    uncached_count = sum(1 for addr in unique_addresses if addr not in location_dict)
    print(f"  Found {len(unique_addresses)} unique addresses")
    print(f"  Already cached: {len(unique_addresses) - uncached_count}")
    print(f"  Need geocoding: {uncached_count}")

    for i, address in enumerate(unique_addresses):
        if address not in location_dict:
            try:
                location = geolocator.geocode(address)
                if location:
                    location_dict[address] = (location.latitude, location.longitude)
                    if (i + 1) % 10 == 0:  # Print progress every 10 addresses
                        print(f"  Geocoded {i + 1}/{uncached_count} new addresses...")
                else:
                    location_dict[address] = (None, None)
                    print(f"  No results for: {address[:50]}...")
            except Exception as e:
                location_dict[address] = (None, None)
                print(f"  Geocoding failed for {address[:50]}...: {str(e)[:50]}")
        # else:
        #     print("Location cached for address: {}".format(address))

    dataframe['latitude'] = dataframe['full_address'].map(lambda x: location_dict[x][0])
    dataframe['longitude'] = dataframe['full_address'].map(lambda x: location_dict[x][1])

    print("Geocoding complete")

    return dataframe, location_dict


def main(output_dir):
    combined_data = pd.read_csv(os.path.join(output_dir, "Combined_Shoot_Schedule_2024.csv"))
    required_columns = ['Address 1', 'Address 2', 'City', 'State', 'Country', 'Club Name']
    if all(column in combined_data.columns for column in required_columns):
        # Replace 'YOUR_API_KEY' with your actual Google Maps API key
        api_key = "AIzaSyDGsAWaEy8X2j0k8x26yGxlkJcnPJASAtI"
        cached_locations = load_cached_locations(os.path.join(output_dir, "Club_Locations.csv"))
        geocoded_data, location_dict = geocode_addresses(combined_data, api_key, cached_locations)

        # Write out successfully looked up addresses to "Club_Locations.csv"
        club_locations_df = pd.DataFrame({'full_address': list(location_dict.keys()),
                                          'latitude': [loc[0] for loc in location_dict.values()],
                                          'longitude': [loc[1] for loc in location_dict.values()]})
        club_locations_df.to_csv(os.path.join(output_dir, "Club_Locations.csv"), index=False)

        # Save the geocoded data to a new CSV file
        geocoded_data.to_csv(os.path.join(output_dir, "Geocoded_Combined_Shoot_Schedule_2024.csv"), index=False)
        print("Geocoded data saved successfully.")
    else:
        missing = [column for column in required_columns if column not in combined_data.columns]
        print(f"Error: Missing columns {missing}. Please check the CSV file.")


if __name__ == "__main__":
    # Determine if running inside a Docker container
    if os.path.exists('/.dockerenv'):
        output_dir = "/app/data"
    else:
        output_dir = "../data"

    main(output_dir)
