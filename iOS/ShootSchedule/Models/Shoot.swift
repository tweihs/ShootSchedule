//
//  Shoot.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import Foundation
import MapKit
import SwiftUI

enum ShootNotabilityLevel {
    case world
    case state
    case other
    case none
    
    var starColor: Color {
        switch self {
        case .world: return .yellow  // Gold
        case .state: return Color(red: 0.8, green: 0.5, blue: 0.2)  // Bronze
        case .other: return Color(red: 0.75, green: 0.75, blue: 0.75)  // Silver
        case .none: return .clear
        }
    }
    
    var starIcon: String {
        switch self {
        case .world, .state, .other: return "star.fill"
        case .none: return ""
        }
    }
}

struct Shoot: Identifiable, Codable, Hashable {
    let id: Int
    let shootName: String
    let shootType: String?
    let startDate: Date
    let endDate: Date?
    let clubName: String
    let address1: String?
    let address2: String?
    let city: String?
    let state: String?
    let zip: String?
    let country: String?
    let zone: Int?
    let clubEmail: String?
    let pocName: String?
    let pocPhone: String?
    let pocEmail: String?
    let clubID: Int?
    let eventType: String?
    let region: String?
    let fullAddress: String?
    let latitude: Double?
    let longitude: Double?
    let notabilityLevelRaw: Int? // Pre-calculated: 0=none, 1=other, 2=state, 3=world
    
    // Weather data
    let morningTempF: Int?
    let afternoonTempF: Int?
    let morningTempC: Int?
    let afternoonTempC: Int?
    let durationDays: Int?
    let morningTempBand: String?
    let afternoonTempBand: String?
    let estimationMethod: String?
    
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
        case notabilityLevelRaw = "notability_level"
        case morningTempF = "morning_temp_f"
        case afternoonTempF = "afternoon_temp_f"
        case morningTempC = "morning_temp_c"
        case afternoonTempC = "afternoon_temp_c"
        case durationDays = "duration_days"
        case morningTempBand = "morning_temp_band"
        case afternoonTempBand = "afternoon_temp_band"
        case estimationMethod = "estimation_method"
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
    
    var userFriendlyDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: startDate)
    }
    
    var locationString: String {
        var components: [String] = []
        
        // Add city if available and not "NONE"
        if let city = city, !city.isEmpty, city.uppercased() != "NONE" {
            components.append(city)
        }
        
        // Add state if available and not "NONE"
        if let state = state, !state.isEmpty, state.uppercased() != "NONE" {
            components.append(state)
        }
        
        // Return joined components or fallback
        if !components.isEmpty {
            return components.joined(separator: ", ")
        }
        
        return "Unknown Location"
    }
    
    var isNotable: Bool {
        return shootType != nil && shootType != "None" && !shootType!.isEmpty
    }
    
    var notabilityLevel: ShootNotabilityLevel {
        // Use pre-calculated level if available
        if let level = notabilityLevelRaw {
            switch level {
            case 3: return .world
            case 2: return .state  
            case 1: return .other
            default: return .none
            }
        }
        
        // Fallback to computed logic for backward compatibility
        guard let shootType = shootType?.lowercased(), !shootType.isEmpty, shootType != "none" else {
            return .none
        }
        
        if shootType.contains("world") {
            return .world
        } else if shootType.contains("state") {
            return .state
        } else {
            return .other
        }
    }
    
    var isFuture: Bool {
        return startDate > Date()
    }
    
    var displayLabel: String {
        if let eventType = eventType, !eventType.isEmpty {
            return "\(eventType) \(shootName)"
        }
        return shootName
    }
    
    // Weather computed properties
    var duration: Int {
        // Use database value if available and valid, otherwise calculate
        if let durationDays = durationDays, durationDays > 0 {
            return durationDays
        }
        
        guard let endDate = endDate else { return 1 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return max(1, (components.day ?? 0) + 1)
    }
    
    var durationText: String {
        let days = duration
        return days == 1 ? "1 day" : "\(days) days"
    }
    
    var temperatureDisplay: String? {
        // Prefer user's temperature preference
        let useFahrenheit = UserDefaults.standard.object(forKey: "useFahrenheit") != nil 
            ? UserDefaults.standard.bool(forKey: "useFahrenheit")
            : true
        
        if useFahrenheit, let morning = morningTempF, let afternoon = afternoonTempF {
            return "\(morning)°F-\(afternoon)°F"
        } else if !useFahrenheit, let morning = morningTempC, let afternoon = afternoonTempC {
            return "\(morning)°C-\(afternoon)°C"
        }
        
        return nil
    }
}

// MARK: - Filter Options
enum ShootAffiliation: String, CaseIterable {
    case nsca = "NSCA"
    case nssa = "NSSA"
    case ata = "ATA"
    
    var displayName: String { rawValue }
}

class FilterOptions: ObservableObject {
    @Published var searchText = ""
    @Published var selectedAffiliations = Set<ShootAffiliation>()
    @Published var selectedMonths = Set<Int>()
    @Published var selectedStates = Set<String>()
    @Published var showFutureOnly = true
    @Published var showNotableOnly = false
    @Published var showMarkedOnly = false
    
    private var workItem: DispatchWorkItem?
    private let searchQueue = DispatchQueue(label: "search-queue", qos: .userInitiated)
    
    // Cache for state mappings to improve performance
    private static let stateMapping: [String: String] = [
        "al": "alabama", "ak": "alaska", "az": "arizona", "ar": "arkansas", "ca": "california",
        "co": "colorado", "ct": "connecticut", "de": "delaware", "fl": "florida", "ga": "georgia",
        "hi": "hawaii", "id": "idaho", "il": "illinois", "in": "indiana", "ia": "iowa",
        "ks": "kansas", "ky": "kentucky", "la": "louisiana", "me": "maine", "md": "maryland",
        "ma": "massachusetts", "mi": "michigan", "mn": "minnesota", "ms": "mississippi", "mo": "missouri",
        "mt": "montana", "ne": "nebraska", "nv": "nevada", "nh": "new hampshire", "nj": "new jersey",
        "nm": "new mexico", "ny": "new york", "nc": "north carolina", "nd": "north dakota", "oh": "ohio",
        "ok": "oklahoma", "or": "oregon", "pa": "pennsylvania", "ri": "rhode island", "sc": "south carolina",
        "sd": "south dakota", "tn": "tennessee", "tx": "texas", "ut": "utah", "vt": "vermont",
        "va": "virginia", "wa": "washington", "wv": "west virginia", "wi": "wisconsin", "wy": "wyoming"
    ]
    
    func reset() {
        searchText = ""
        selectedAffiliations.removeAll()
        selectedMonths.removeAll()
        selectedStates.removeAll()
        showFutureOnly = true
        showNotableOnly = false
        showMarkedOnly = false
    }
    
    func apply(to shoots: [Shoot]) -> [Shoot] {
        var remainingShoots = shoots
        
        // Search text filter with optimized multi-term matching
        if !searchText.isEmpty {
            remainingShoots = remainingShoots.filter { shoot in
                return searchMatches(shoot: shoot, searchText: searchText)
            }
        }
        
        // Affiliation filter
        if !selectedAffiliations.isEmpty {
            remainingShoots = remainingShoots.filter { shoot in
                guard let eventType = shoot.eventType else { return false }
                return selectedAffiliations.contains { affiliation in
                    eventType.contains(affiliation.rawValue)
                }
            }
        }
        
        // Month filter
        if !selectedMonths.isEmpty {
            remainingShoots = remainingShoots.filter { shoot in
                let month = Calendar.current.component(.month, from: shoot.startDate)
                return selectedMonths.contains(month)
            }
        }
        
        // State filter
        if !selectedStates.isEmpty {
            remainingShoots = remainingShoots.filter { shoot in
                guard let state = shoot.state else { return false }
                return selectedStates.contains(state)
            }
        }
        
        // Future filter
        if showFutureOnly {
            remainingShoots = remainingShoots.filter { $0.isFuture }
        }
        
        // Notable filter
        if showNotableOnly {
            remainingShoots = remainingShoots.filter { $0.isNotable }
        }
        
        // Marked filter
        if showMarkedOnly {
            remainingShoots = remainingShoots.filter { $0.isMarked }
        }
        
        return remainingShoots
    }
    
    private func searchMatches(shoot: Shoot, searchText: String) -> Bool {
        let searchTerms = searchText.lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // If no valid search terms, return true
        guard !searchTerms.isEmpty else { return true }
        
        // Get all searchable text from the shoot (optimized)
        let shootName = shoot.shootName.lowercased()
        let clubName = shoot.clubName.lowercased()
        let city = shoot.city?.lowercased() ?? ""
        let state = shoot.state?.lowercased() ?? ""
        let eventType = shoot.eventType?.lowercased() ?? ""
        let shootType = shoot.shootType?.lowercased() ?? ""
        
        // Create a combined searchable string
        let combinedText = "\(shootName) \(clubName) \(city) \(state) \(eventType) \(shootType)"
        
        // All terms must match somewhere in the shoot data
        return searchTerms.allSatisfy { term in
            // Direct text match (most common case)
            if combinedText.contains(term) {
                return true
            }
            
            // Check if term is a state abbreviation and state matches full name
            if let fullStateName = Self.stateMapping[term] {
                return state.contains(fullStateName) || city.contains(fullStateName)
            }
            
            // Check if term is a state full name and state matches abbreviation
            // Only check if term is longer than 3 characters to avoid unnecessary loops
            if term.count > 3 {
                for (abbrev, fullName) in Self.stateMapping {
                    if term.contains(fullName) && state.contains(abbrev) {
                        return true
                    }
                }
            }
            
            return false
        }
    }
}