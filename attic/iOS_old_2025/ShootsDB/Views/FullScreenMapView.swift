//
//  MapView.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/8/24.
//

import SwiftUI
import MapKit

struct FullScreenMapView: View {
    var coordinate: CLLocationCoordinate2D
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            MapView(coordinate: coordinate)
                .edgesIgnoringSafeArea(.all)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    FullScreenMapView(coordinate: CLLocationCoordinate2D(latitude: 39.1911, longitude: -106.8175))
}

