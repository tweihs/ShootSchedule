//
//  Shoot.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import Foundation
import MapKit

struct Shoot: Identifiable, Codable, Hashable {
    let id: Int
    let shootName: String
    let shootType: String?
    let startDate: Date
    let endDate: Date?
    let clubName: String
    let address1: String?
    let address2: String?
    let city: String
    let state: String
    let zip: String?
    let country: String?
    let zone: Int?
    let clubEmail: String?
    let pocName: String?
    let pocPhone: String?
    let pocEmail: String?
    let clubID: Int?
    let eventType: String
    let region: String?
    let fullAddress: String?
    let latitude: Double?
    let longitude: Double?
    
    // Local properties
    var isMarked: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id = "Shoot ID"
        case shootName = "Shoot Name"
        case shootType = "Shoot Type"
        case startDate = "Start Date"
        case endDate = "End Date"
        case clubName = "Club Name"
        case address1 = "Address 1"
        case address2 = "Address 2"
        case city = "City"
        case state = "State"
        case zip = "Zip"
        case country = "Country"
        case zone = "Zone"
        case clubEmail = "Club E-Mail"
        case pocName = "POC Name"
        case pocPhone = "POC Phone"
        case pocEmail = "POC E-Mail"
        case clubID = "ClubID"
        case eventType = "Event Type"
        case region = "Region"
        case fullAddress = "full_address"
        case latitude
        case longitude
        case isMarked
    }
    
    // Computed properties
    var coordinates: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if let endDate = endDate, endDate != startDate {
            let startStr = formatter.string(from: startDate)
            
            // If same month, show "May 6-9"
            if Calendar.current.isDate(startDate, equalTo: endDate, toGranularity: .month) {
                formatter.dateFormat = "d"
                let endStr = formatter.string(from: endDate)
                formatter.dateFormat = "MMM d"
                return "\(startStr)-\(endStr)"
            } else {
                // Different months
                let endStr = formatter.string(from: endDate)
                return "\(startStr) - \(endStr)"
            }
        } else {
            return formatter.string(from: startDate)
        }
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startDate)
    }
    
    var locationString: String {
        if let state = state.isEmpty ? nil : state {
            return "\(city), \(state)"
        }
        return city
    }
    
    var isNotable: Bool {
        return shootType != nil && shootType != "None" && !shootType!.isEmpty
    }
    
    var isFuture: Bool {
        return startDate > Date()
    }
}

// MARK: - Filter Options
enum ShootAffiliation: String, CaseIterable {
    case nsca = "NSCA"
    case nssa = "NSSA"
    case ata = "ATA"
    
    var displayName: String { rawValue }
}

struct FilterOptions: ObservableObject {
    @Published var searchText = ""
    @Published var selectedAffiliations = Set<ShootAffiliation>()
    @Published var selectedMonths = Set<Int>()
    @Published var selectedStates = Set<String>()
    @Published var showFutureOnly = false
    @Published var showNotableOnly = false
    @Published var showMarkedOnly = false
    
    func reset() {
        searchText = ""
        selectedAffiliations.removeAll()
        selectedMonths.removeAll()
        selectedStates.removeAll()
        showFutureOnly = false
        showNotableOnly = false
        showMarkedOnly = false
    }
    
    func apply(to shoots: [Shoot]) -> [Shoot] {
        shoots.filter { shoot in
            // Search text filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let matches = shoot.shootName.lowercased().contains(searchLower) ||
                              shoot.clubName.lowercased().contains(searchLower) ||
                              shoot.city.lowercased().contains(searchLower) ||
                              (shoot.state.lowercased().contains(searchLower))
                if !matches { return false }
            }
            
            // Affiliation filter
            if !selectedAffiliations.isEmpty {
                let hasAffiliation = selectedAffiliations.contains { affiliation in
                    shoot.eventType.contains(affiliation.rawValue)
                }
                if !hasAffiliation { return false }
            }
            
            // Month filter
            if !selectedMonths.isEmpty {
                let month = Calendar.current.component(.month, from: shoot.startDate)
                if !selectedMonths.contains(month) { return false }
            }
            
            // State filter
            if !selectedStates.isEmpty {
                if !selectedStates.contains(shoot.state) { return false }
            }
            
            // Toggle filters
            if showFutureOnly && !shoot.isFuture { return false }
            if showNotableOnly && !shoot.isNotable { return false }
            if showMarkedOnly && !shoot.isMarked { return false }
            
            return true
        }
    }
}