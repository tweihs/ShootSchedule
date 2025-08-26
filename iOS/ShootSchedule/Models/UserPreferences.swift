//
//  UserPreferences.swift
//  ShootSchedule
//
//  Created on 1/25/25.
//

import Foundation
import MapKit

struct MapState: Codable {
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
    
    static let defaultUSCenter = MapState(from: MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795), // Center of US
        span: MKCoordinateSpan(latitudeDelta: 25, longitudeDelta: 25)
    ))
}

struct UserPreferences: Codable {
    var mapState: MapState
    
    init(mapState: MapState = .defaultUSCenter) {
        self.mapState = mapState
    }
}

class UserPreferencesManager: ObservableObject {
    @Published var preferences: UserPreferences
    
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let preferencesKey = "UserPreferences"
    
    init() {
        // Try to load from iCloud first
        if let data = iCloudStore.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            self.preferences = decoded
            print("☁️ LOADED USER PREFERENCES FROM ICLOUD")
        } else {
            // Fallback to UserDefaults for migration
            if let data = UserDefaults.standard.data(forKey: preferencesKey),
               let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
                self.preferences = decoded
                print("📱 MIGRATED USER PREFERENCES FROM LOCAL STORAGE")
                // Save to iCloud and remove from UserDefaults
                savePreferences()
                UserDefaults.standard.removeObject(forKey: preferencesKey)
            } else {
                self.preferences = UserPreferences()
                print("📱 CREATED DEFAULT USER PREFERENCES")
            }
        }
        
        // Listen for iCloud sync notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            iCloudStore.set(encoded, forKey: preferencesKey)
            iCloudStore.synchronize()
            print("☁️ SAVED USER PREFERENCES TO ICLOUD")
        }
    }
    
    func updateMapState(_ region: MKCoordinateRegion) {
        preferences.mapState = MapState(from: region)
        savePreferences()
    }
    
    @objc private func iCloudStoreDidChange(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        // Check if our key was updated
        if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
           changedKeys.contains(preferencesKey) {
            
            // Reload preferences from iCloud
            if let data = iCloudStore.data(forKey: preferencesKey),
               let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
                
                DispatchQueue.main.async {
                    self.preferences = decoded
                    print("☁️ SYNCED USER PREFERENCES FROM ICLOUD")
                }
            }
        }
    }
}