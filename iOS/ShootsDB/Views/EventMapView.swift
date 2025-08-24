//
//  EventMapView.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/8/24.
//

import SwiftUI
import MapKit

struct EventMapView: View {
    let events: [Event]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903), // Default to Denver, CO
        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
    )
    @State private var selectedEvent: Event?

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, annotationItems: events) { event in
                MapAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: event.coordinates.latitude, longitude: event.coordinates.longitude)
                ) {
                    Button(action: {
                        selectedEvent = event
                    }) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title)
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .sheet(item: $selectedEvent) { event in
                ShootDetailView(event: event)
            }
        }
    }
}

#Preview {
    EventMapView(events: sampleEvents)
}
