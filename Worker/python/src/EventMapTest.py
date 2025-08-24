import pandas as pd
import folium


def create_event_map(output_html, event_data):
    # Create a map centered at the center of the United States
    m = folium.Map(location=[39.8283, -98.5795], zoom_start=4)

    # Add circle markers for each shoot event
    for index, row in event_data.iterrows():
        location = (row["latitude"], row["longitude"])
        popup = f"{row['Shoot Name']} - {row['Start Date']} to {row['End Date']}"

        # Determine marker color based on event type
        event_type = row["type"].lower()
        if event_type == "nssa":
            color = "red"
        elif event_type == "nsca":
            color = "blue"
        else:
            color = "gray"  # Default color for unknown event types

        folium.CircleMarker(location=location, popup=popup, radius=5, color=color, fill=True, fill_opacity=0.7).add_to(
            m)

    # Save the map to an HTML file
    m.save(output_html)


if __name__ == "__main__":
    # Load geocoded shoot event data from the CSV file
    event_data = pd.read_csv("../data/Geocoded_Combined_Shoot_Schedule_2024.csv")

    # Create the event map
    create_event_map("Event_Map.html", event_data)
