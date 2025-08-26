//
//  ShootDetailView.swift
//  ShootSchedule
//
//  Created on 1/24/25.
//

import SwiftUI
import MapKit
import Foundation

struct ShootDetailView: View {
    let shoot: Shoot
    @EnvironmentObject var dataManager: DataManager
    @State private var region = MKCoordinateRegion()
    @State private var isMarked = false
    @State private var mapPosition: MapCameraPosition = .automatic
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Section
                VStack(alignment: .leading, spacing: 6) {
                    // Title and Date Row
                    HStack(alignment: .top) {
                        Text(shoot.displayLabel.uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(3)
                            .truncationMode(.tail)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(shoot.userFriendlyDate)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.trailing)
                            
                            // Notability Tag
                            if shoot.notabilityLevel != .none {
                                Text(notabilityDisplayText(for: shoot.notabilityLevel))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            
                            // TemperatureDurationView(shoot: shoot) - Hidden for now
                        }
                    }
                    
                    Text(shoot.clubName.uppercased())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(shoot.locationString.uppercased())
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Mark Button
                Button(action: {
                    toggleMark()
                }) {
                    if isMarked {
                        // Marked state - checkmark with blue background
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                            Text("Marked")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    } else {
                        // Unmarked state - "Mark" text with border
                        Text("Mark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue, lineWidth: 1.5)
                            )
                    }
                }
                .padding(.horizontal)
                
                // Map Section
                if let coordinates = shoot.coordinates {
                    Map(position: $mapPosition, interactionModes: [.zoom]) {
                        Marker("", coordinate: coordinates)
                            .tint(.blue)
                    }
                    .onMapCameraChange(frequency: .continuous) { context in
                        // Keep map centered on club location during zoom
                        let newRegion = MKCoordinateRegion(
                            center: coordinates, // Always use club coordinates as center
                            span: context.region.span // Keep the user's zoom level
                        )
                        mapPosition = .region(newRegion)
                    }
                    .onTapGesture {
                        // Launch default Maps app with the location
                        openInMaps(coordinates: coordinates)
                    }
                    .frame(height: 250)
                }
                
                // Club Address Section
                if let address = buildFullAddress() {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Club Address")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(address)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                }
                
                // Club Contact Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Club Contact")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let pocName = shoot.pocName, !pocName.isEmpty, pocName.lowercased() != "none" {
                        Text(pocName.uppercased())
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                    }
                    
                    if let pocPhone = shoot.pocPhone, !pocPhone.isEmpty, pocPhone.lowercased() != "none" {
                        Button(action: {
                            if let url = URL(string: "tel:\(pocPhone.filter { $0.isNumber })") {
                                if UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url)
                                } else {
                                    // Fallback for simulator or when phone capability is not available
                                    UIPasteboard.general.string = pocPhone
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "phone")
                                    .font(.system(size: 12))
                                Text(pocPhone)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.blue)
                            .underline()
                        }
                    }
                    
                    if let email = shoot.pocEmail ?? shoot.clubEmail, !email.isEmpty, email.lowercased() != "none" {
                        Button(action: {
                            if let url = URL(string: "mailto:\(email)") {
                                if UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url)
                                } else {
                                    // Fallback for simulator or when no mail app is available
                                    UIPasteboard.general.string = email
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 12))
                                Text(email.uppercased())
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.blue)
                            .underline()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(red: 1.0, green: 0.992, blue: 0.973))
        .ignoresSafeArea(edges: .horizontal)
        .onAppear {
            isMarked = dataManager.isShootMarked(shoot)
            setupMapRegion()
            
            // Initialize map position
            if let coordinates = shoot.coordinates {
                mapPosition = .region(MKCoordinateRegion(
                    center: coordinates,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }
    
    private func notabilityDisplayText(for level: ShootNotabilityLevel) -> String {
        switch level {
        case .world:
            return "World"
        case .state:
            return "State"
        case .other:
            return "Regional"
        case .none:
            return ""
        }
    }
    
    
    private func buildFullAddress() -> String? {
        var addressParts: [String] = []
        
        if let address1 = shoot.address1, !address1.isEmpty {
            addressParts.append(address1.uppercased())
        }
        
        if let address2 = shoot.address2, !address2.isEmpty {
            addressParts.append(address2.uppercased())
        }
        
        var cityStateZip = ""
        if let city = shoot.city, city.uppercased() != "NONE" {
            cityStateZip = city.uppercased()
        }
        
        if let state = shoot.state, !state.isEmpty, state.uppercased() != "NONE" {
            cityStateZip += cityStateZip.isEmpty ? state.uppercased() : ", \(state.uppercased())"
        }
        
        if let zip = shoot.zip, !zip.isEmpty, zip.uppercased() != "NONE" {
            cityStateZip += " \(zip)"
        }
        
        if !cityStateZip.isEmpty {
            addressParts.append(cityStateZip)
        }
        
        return addressParts.isEmpty ? nil : addressParts.joined(separator: "\n")
    }
    
    private func toggleMark() {
        if isMarked {
            dataManager.unmarkShoot(shoot)
        } else {
            dataManager.markShoot(shoot)
        }
        isMarked = dataManager.isShootMarked(shoot)
    }
    
    private func setupMapRegion() {
        if let coordinates = shoot.coordinates {
            region = MKCoordinateRegion(
                center: coordinates,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
    
    private func openInMaps(coordinates: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinates)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = shoot.clubName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinates),
            MKLaunchOptionsMapTypeKey: NSNumber(value: MKMapType.standard.rawValue)
        ])
    }
}

// MARK: - Temperature Duration Component
struct TemperatureDurationView: View {
    let shoot: Shoot
    @State private var useFahrenheit: Bool = true
    
    var body: some View {
        Text(buildDurationAndTempText())
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.trailing)
            .onAppear {
                loadTemperaturePreference()
            }
    }
    
    private func buildDurationAndTempText() -> String {
        let duration = calculateShootDuration()
        let temps = getHistoricalTemperatures()
        
        let morningTemp = convertTemperature(temps.morning)
        let afternoonTemp = convertTemperature(temps.afternoon)
        let unit = temperatureUnit()
        
        let dayText = duration == 1 ? "Day" : "Days"
        return "\(duration) \(dayText) (\(morningTemp)\(unit) - \(afternoonTemp)\(unit))"
    }
    
    private func convertTemperature(_ fahrenheit: Int) -> Int {
        if useFahrenheit {
            return fahrenheit
        } else {
            // Convert F to C: (F - 32) * 5/9
            return Int((Double(fahrenheit) - 32.0) * 5.0 / 9.0)
        }
    }
    
    private func temperatureUnit() -> String {
        return useFahrenheit ? "°F" : "°C"
    }
    
    private func loadTemperaturePreference() {
        useFahrenheit = UserDefaults.standard.object(forKey: "useFahrenheit") != nil 
            ? UserDefaults.standard.bool(forKey: "useFahrenheit")
            : true
    }
    
    private func calculateShootDuration() -> Int {
        guard let endDate = shoot.endDate else { return 1 }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: shoot.startDate, to: endDate)
        return max(1, (components.day ?? 0) + 1)
    }
    
    private func getHistoricalTemperatures() -> (morning: Int, afternoon: Int) {
        let month = Calendar.current.component(.month, from: shoot.startDate)
        
        // Base afternoon high temperatures by month (rough averages for US at 3 PM)
        let baseHighTemps = [1: 50, 2: 55, 3: 65, 4: 75, 5: 83, 6: 90, 
                            7: 93, 8: 92, 9: 85, 10: 75, 11: 63, 12: 53]
        
        var afternoonHigh = baseHighTemps[month] ?? 75
        
        // Add regional variation based on state
        if let state = shoot.state {
            switch state {
            case "FL", "TX", "AZ", "CA", "NV":
                afternoonHigh += 8
            case "MT", "WY", "ND", "SD", "MN", "WI", "ME", "VT", "NH":
                afternoonHigh -= 8
            case "WA", "OR", "ID":
                afternoonHigh -= 3
            default:
                break
            }
        }
        
        // Morning temperature difference by season
        let tempDifference: Int
        switch month {
        case 12, 1, 2: tempDifference = 12
        case 3, 4, 11: tempDifference = 18
        case 5, 6, 7, 8, 9, 10: tempDifference = 22
        default: tempDifference = 18
        }
        
        let morningLow = max(afternoonHigh - tempDifference, 20)
        return (morning: morningLow, afternoon: afternoonHigh)
    }
}

// Helper struct for map annotation
struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Previews
struct ShootDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ShootDetailView(shoot: mockShoot)
                .environmentObject(DataManager())
        }
    }
    
    static var mockShoot: Shoot {
        Shoot(
            id: 1,
            shootName: "Mississippi State Championship",
            shootType: "State Championship",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            clubName: "DeSoto Rifle and Pistol Club",
            address1: "7171 Compress Rd",
            address2: nil,
            city: "Como",
            state: "MS",
            zip: "38619",
            country: "USA",
            zone: 5,
            clubEmail: "jimmie@desotogunrange.com",
            pocName: "Jimmie Neal",
            pocPhone: "(662) 288-0525",
            pocEmail: "jimmie@desotogunrange.com",
            clubID: 123,
            eventType: "NSCA",
            region: "South",
            fullAddress: "7171 Compress Rd, Como, MS 38619",
            latitude: 34.5,
            longitude: -89.9,
            notabilityLevelRaw: nil,
            isMarked: false
        )
    }
}