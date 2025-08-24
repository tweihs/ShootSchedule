import Foundation

// Event model representing a shooting event
struct ShootEvent: Identifiable {
    let id: Int
    let name: String
    let type: String
    let startDate: Date
    let endDate: Date
    let clubName: String
    let address1: String
    let address2: String?
    let city: String
    let state: String
    let zip: String
    let country: String
    let zone: String?
    let clubEmail: String?
    let pocName: String?
    let pocPhone: String?
    let pocEmail: String?
    let clubID: Int?
    let eventType: String
    let region: String?
    let fullAddress: String
    let latitude: Double
    let longitude: Double
}

// Enum for shoot types
enum ShootType: String, Codable, CaseIterable {
    case sporting
    case skeet
    case trap
    case fitasc
    case other
}

// Enum for shoot zones
enum ShootZone: String, Codable, CaseIterable {
    case zone1, zone2, zone3, zone4, zone5, zone6, zone7
}

// Filter model to capture user's filter selections
struct ShootFilter {
    var types: Set<ShootType> = []
    var months: Set<Int> = []
    var zones: Set<ShootZone> = []
    var states: Set<String> = []
    var isNotable: Bool? = nil
    var isFutureShoot: Bool? = nil
    var isMarked: Bool? = nil
    var searchText: String = ""
    
    // Reset all filters
    mutating func reset() {
        types.removeAll()
        months.removeAll()
        zones.removeAll()
        states.removeAll()
        isNotable = nil
        isFutureShoot = nil
        isMarked = nil
        searchText = ""
    }
}
