//
//  ShootsMapView.swift
//  ShootSchedule
//
//  Created on 1/24/25.
//

import SwiftUI
import MapKit
import UIKit
import CoreLocation
import Combine

struct MapPositionData: Codable {
    let centerLatitude: Double
    let centerLongitude: Double
    let latitudeDelta: Double
    let longitudeDelta: Double
    
    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
    
    init(from region: MKCoordinateRegion) {
        centerLatitude = region.center.latitude
        centerLongitude = region.center.longitude
        latitudeDelta = region.span.latitudeDelta
        longitudeDelta = region.span.longitudeDelta
    }
}

// Custom annotation class for better performance
class ShootAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let shoot: Shoot
    
    init(shoot: Shoot, coordinate: CLLocationCoordinate2D) {
        self.shoot = shoot
        self.coordinate = coordinate
        self.title = "\(shoot.shootName) - \(shoot.userFriendlyDate)"
        self.subtitle = shoot.clubName
        super.init()
    }
}

// Location manager for current location
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocatingUser: Bool = false
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // Don't automatically request permission - wait for user to tap button
    }
    
    func goToCurrentLocation() {
        print("🎯 User requested go to location - current status: \(authorizationStatus)")
        isLocatingUser = true
        
        switch authorizationStatus {
        case .notDetermined:
            print("🎯 Requesting location permission...")
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("🎯 Permission granted, getting current location...")
            manager.requestLocation()
        case .denied, .restricted:
            print("🎯 Location access denied or restricted")
            isLocatingUser = false
        @unknown default:
            print("🎯 Unknown authorization status")
            isLocatingUser = false
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.first
        let wasUserRequested = isLocatingUser
        isLocatingUser = false // Clear the locating flag
        
        print("🎯 Location received: \(locations.first?.coordinate ?? CLLocationCoordinate2D()), user requested: \(wasUserRequested)")
        
        // Only trigger map animation if user explicitly requested location
        if wasUserRequested {
            requestMapAnimation = true
        }
    }
    
    @Published var requestMapAnimation = false
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        isLocatingUser = false // Clear the locating flag on error
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("🎯 Authorization changed to: \(authorizationStatus)")
        
        // Only get location if user explicitly requested it
        if isLocatingUser && (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) {
            print("🎯 Permission granted! Getting current location...")
            manager.requestLocation()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            isLocatingUser = false
        }
    }
}

// Map view with location button overlay
struct ShootsMapViewContainer: View {
    let shoots: [Shoot]
    @Binding var selectedShoot: Shoot?
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ZStack {
            ShootsMapView(shoots: shoots, selectedShoot: $selectedShoot, locationManager: locationManager)
            
            // Current location button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        locationManager.goToCurrentLocation()
                    }) {
                        Group {
                            if locationManager.isLocatingUser {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location")
                                    .font(.system(size: 20, weight: .medium))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .disabled(locationManager.isLocatingUser)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

// High-performance MapKit wrapper
struct ShootsMapView: UIViewRepresentable {
    let shoots: [Shoot]
    @Binding var selectedShoot: Shoot?
    let locationManager: LocationManager
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false // Will be controlled by tracking state
        mapView.userTrackingMode = .none
        mapView.mapType = .standard
        
        // Enable globe view when zoomed out
        if #available(iOS 17.0, *) {
            let standardConfig = MKStandardMapConfiguration()
            standardConfig.showsTraffic = false
            mapView.preferredConfiguration = standardConfig
            
            // Remove camera restrictions to allow globe view
            mapView.cameraBoundary = nil
            mapView.cameraZoomRange = nil
            
            // Enable globe rendering explicitly
            mapView.mapType = .standard
        }
        
        // Load saved map position
        if let savedData = UserDefaults.standard.data(forKey: "MapPosition"),
           let decoded = try? JSONDecoder().decode(MapPositionData.self, from: savedData) {
            mapView.setRegion(decoded.region, animated: false)
        } else {
            // Default to center of US
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
                span: MKCoordinateSpan(latitudeDelta: 25, longitudeDelta: 25)
            )
            mapView.setRegion(region, animated: false)
        }
        
        return mapView
    }
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Store map reference in coordinator for location updates
        context.coordinator.mapView = mapView
        
        // Always show user location when available
        mapView.showsUserLocation = locationManager.userLocation != nil
        
        // Remove existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add new annotations efficiently
        let annotations = shoots.compactMap { shoot -> ShootAnnotation? in
            guard let latitude = shoot.latitude,
                  let longitude = shoot.longitude else { return nil }
            
            return ShootAnnotation(
                shoot: shoot,
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            )
        }
        
        mapView.addAnnotations(annotations)
        
        // If we have a pending location update, handle it now
        context.coordinator.handlePendingLocationUpdate()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ShootsMapView
        var mapView: MKMapView?
        private var pendingLocationUpdate: CLLocation?
        
        init(_ parent: ShootsMapView) {
            self.parent = parent
            super.init()
            
            // Listen for location updates
            parent.locationManager.objectWillChange.sink { [weak self] in
                DispatchQueue.main.async {
                    self?.handleLocationUpdate()
                }
            }.store(in: &cancellables)
        }
        
        private var cancellables = Set<AnyCancellable>()
        
        func handleLocationUpdate() {
            guard let mapView = mapView else {
                // Store for later if map isn't ready yet
                pendingLocationUpdate = parent.locationManager.userLocation
                return
            }
            
            // Always show user location when available
            mapView.showsUserLocation = parent.locationManager.userLocation != nil
            
            // Only animate to location if user requested it
            if let userLocation = parent.locationManager.userLocation,
               parent.locationManager.requestMapAnimation {
                print("🎯 Animating to user location: \(userLocation.coordinate)")
                let region = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    latitudinalMeters: 50000, // 50km radius
                    longitudinalMeters: 50000
                )
                mapView.setRegion(region, animated: true)
                
                // Clear the animation request
                parent.locationManager.requestMapAnimation = false
                pendingLocationUpdate = nil
            } else if parent.locationManager.userLocation != nil {
                print("🎯 Location updated but no animation requested")
            }
        }
        
        func handlePendingLocationUpdate() {
            if pendingLocationUpdate != nil {
                handleLocationUpdate()
            }
        }
        
        // Efficient annotation view creation with reuse
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let shootAnnotation = annotation as? ShootAnnotation else { return nil }
            
            let identifier = "ShootMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            // Configure marker with target glyph and color based on marked status and notability
            annotationView?.glyphImage = UIImage(systemName: "target")
            
            // Color hierarchy: marked (blue) > world (gold) > state (bronze) > other (light grey)
            if shootAnnotation.shoot.isMarked {
                annotationView?.markerTintColor = UIColor.systemBlue
                annotationView?.displayPriority = .required // Always show marked shoots
            } else {
                switch shootAnnotation.shoot.notabilityLevel {
                case .world:
                    annotationView?.markerTintColor = UIColor.systemYellow // Gold
                    annotationView?.displayPriority = .defaultHigh // Show notable shoots
                case .state:
                    annotationView?.markerTintColor = UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1.0) // Bronze
                    annotationView?.displayPriority = .defaultHigh // Show notable shoots
                case .other:
                    annotationView?.markerTintColor = UIColor.lightGray // Light grey for other shoots
                    annotationView?.displayPriority = .defaultLow
                case .none:
                    annotationView?.markerTintColor = UIColor.lightGray // Light grey for regular shoots
                    annotationView?.displayPriority = .defaultLow
                }
            }
            annotationView?.glyphTintColor = UIColor.white
            
            // Reduce marker size by 50%
            annotationView?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            
            // Enable callout to show shoot name and club
            annotationView?.canShowCallout = true
            
            // Debug callout
            print("📍 Marker setup: title='\(shootAnnotation.title ?? "nil")', subtitle='\(shootAnnotation.subtitle ?? "nil")', canShowCallout=\(annotationView?.canShowCallout ?? false)")
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let shootAnnotation = view.annotation as? ShootAnnotation {
                parent.selectedShoot = shootAnnotation.shoot
            }
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Save map position
            let positionData = MapPositionData(from: mapView.region)
            if let encoded = try? JSONEncoder().encode(positionData) {
                UserDefaults.standard.set(encoded, forKey: "MapPosition")
            }
        }
    }
}

struct ShootLocation: Identifiable {
    let id = UUID()
    let shoot: Shoot
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Previews
struct ShootsMapView_Previews: PreviewProvider {
    static var sampleShoots: [Shoot] {
        [
            Shoot(
                id: 1,
                shootName: "California Championship",
                shootType: "State Championship",
                startDate: Date(),
                endDate: nil,
                clubName: "Golden Gate Gun Club",
                address1: "123 Main St",
                address2: nil,
                city: "San Francisco",
                state: "CA",
                zip: "94102",
                country: "USA",
                zone: 1,
                clubEmail: "info@ggc.com",
                pocName: "John Doe",
                pocPhone: "(555) 123-4567",
                pocEmail: "john@ggc.com",
                clubID: 1,
                eventType: "NSCA",
                region: "West",
                fullAddress: nil,
                latitude: 37.7749,
                longitude: -122.4194,
                notabilityLevelRaw: nil, isMarked: false
            ),
            Shoot(
                id: 2,
                shootName: "Texas Open",
                shootType: nil,
                startDate: Date(),
                endDate: nil,
                clubName: "Lone Star Shooting Club",
                address1: "456 Oak Ave",
                address2: nil,
                city: "Dallas",
                state: "TX",
                zip: "75201",
                country: "USA",
                zone: 2,
                clubEmail: "contact@lssc.com",
                pocName: "Jane Smith",
                pocPhone: "(555) 987-6543",
                pocEmail: "jane@lssc.com",
                clubID: 2,
                eventType: "NSSA",
                region: "South",
                fullAddress: nil,
                latitude: 32.7767,
                longitude: -96.7970,
                notabilityLevelRaw: nil, isMarked: false
            )
        ]
    }
    
    static var previews: some View {
        ShootsMapViewContainer(shoots: sampleShoots, selectedShoot: .constant(nil))
            .previewDisplayName("Map with Sample Shoots")
    }
}