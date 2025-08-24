import pandas as pd
import folium

def create_event_map(input_csv, output_html):
    # Read the geocoded CSV file
    event_data = pd.read_csv(input_csv)

    # Create a map centered at the mean latitude and longitude
    center = [event_data['latitude'].mean(), event_data['longitude'].mean()]
    m = folium.Map(location=center, zoom_start=5)

    # Add markers for each event
    for index, row in event_data.iterrows():
        # Determine marker color based on event type
        color = 'blue' if row['type'] == 'nsca' else 'red'

        # Create a circle marker for the event
        folium.CircleMarker(
            location=[row['latitude'], row['longitude']],
            radius=5,  # Adjust as needed
            color=color,
            fill=True,
            fill_color=color,
            fill_opacity=0.5,
            popup=f"<b>Shoot Name:</b> {row['Shoot Name']}<br>"
                  f"<b>Club Name:</b> {row['Club Name']}<br>"
                  f"<b>Start Date:</b> {row['Start Date']}<br>"
                  f"<b>End Date:</b> {row['End Date']}<br>"
                  f"<b>Event Type:</b> {row['type'].upper()}"
        ).add_to(m)

    # Add JavaScript code to toggle button state and filter markers
    js_code = """
    <script>
    function toggleMarkers(type) {
        var markers = document.getElementsByClassName("leaflet-marker-icon");
        for (var i = 0; i < markers.length; i++) {
            var marker = markers[i];
            if (marker.style.backgroundImage.includes(type)) {
                marker.style.display = "block";
            } else {
                marker.style.display = "none";
            }
        }
    }

    function toggleButton(button) {
        if (button.classList.contains('active')) {
            button.classList.remove('active');
        } else {
            button.classList.add('active');
        }
    }
    </script>
    """

    # Add filter buttons
    filter_html = """
    <div style="position: fixed; top: 10px; left: 10px; z-index: 1000; background-color: white; padding: 10px;">
    <button id="nssa-button" class="active" style="background-color: red; color: white;" onclick="toggleMarkers('red'); toggleButton(this);">NSSA</button>
    <button id="nsca-button" class="active" style="background-color: blue; color: white;" onclick="toggleMarkers('blue'); toggleButton(this);">NSCA</button>
    </div>
    """

    m.get_root().html.add_child(folium.Element(js_code + filter_html))

    # Save the map to an HTML file
    m.save(output_html)

if __name__ == "__main__":
    create_event_map("Geocoded_Combined_Shoot_Schedule_2024.csv", "Event_Map_with_Filters.html")
