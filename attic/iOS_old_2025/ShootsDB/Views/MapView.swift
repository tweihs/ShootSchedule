//
//  MapView.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/8/24.
//

import SwiftUI
import MapKit

struct MapView: View {
    var coordinate: CLLocationCoordinate2D
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        ))
    }
    
    var body: some View {
        Map(position: $cameraPosition) {
            // Add a marker to indicate the club's location
            Marker("Club Location", coordinate: coordinate)
        }
        .mapStyle(.standard) // Use the standard map style
        .onAppear {
            // Set the initial camera position to the specified coordinate
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
    }
}

#Preview {
    MapView(coordinate: CLLocationCoordinate2D(latitude: 39.1911, longitude: -106.8175))
        .frame(height: 200)
}

