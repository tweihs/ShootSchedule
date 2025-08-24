//
//  EventModel.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/8/24.
//

import Foundation
import MapKit

struct Event: Identifiable, Hashable {
    var id: Int?
    var name: String?
    var type: String?
    var startDate: Date?
    var endDate: Date?
    var club: String?
    var address1: String?
    var address2: String?
    var city: String?
    var state: String?
    var zip: String?
    var country: String?
    var zone: String?
    var clubEmail: String?
    var pocName: String?
    var pocPhone: String?
    var pocEmail: String?
    var clubID: Int?
    var eventType: String?
    var region: String?
    var fullAddress: String?
    var latitude: Double?
    var longitude: Double?
    var isFavorite: Bool = false // Add the `isFavorite` attribute
    
    init(
            id: Int? = nil,
            name: String,
            type: String? = nil,
            startDate: Date,
            endDate: Date,
            club: String,
            address1: String? = nil,
            address2: String? = nil,
            city: String,
            state: String,
            zip: String? = nil,
            country: String? = nil,
            zone: String? = nil,
            clubEmail: String? = nil,
            pocName: String,
            pocPhone: String,
            pocEmail: String,
            clubID: Int? = nil,
            eventType: String? = nil,
            region: String? = nil,
            fullAddress: String? = nil,
            latitude: Double? = nil,
            longitude: Double? = nil,
            isFavorite: Bool = false
        ) {
            self.id = id
            self.name = name
            self.type = type
            self.startDate = startDate
            self.endDate = endDate
            self.club = club
            self.address1 = address1
            self.address2 = address2
            self.city = city
            self.state = state
            self.zip = zip
            self.country = country
            self.zone = zone
            self.clubEmail = clubEmail
            self.pocName = pocName
            self.pocPhone = pocPhone
            self.pocEmail = pocEmail
            self.clubID = clubID
            self.eventType = eventType
            self.region = region
            self.fullAddress = fullAddress
            self.latitude = latitude
            self.longitude = longitude
            self.isFavorite = isFavorite
        }
    
    // Custom initializer to accept coordinates
    init(
        name: String? = nil,
        club: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        city: String? = nil,
        state: String? = nil,
        address: String? = nil,
        pocName: String? = nil,
        pocEmail: String? = nil,
        pocPhone: String? = nil,
        coordinates: CLLocationCoordinate2D? = nil
    ) {
        self.name = name
        self.club = club
        self.startDate = startDate
        self.endDate = endDate
        self.city = city
        self.state = state
        self.pocName = pocName
        self.pocEmail = pocEmail
        self.pocPhone = pocPhone

        // If coordinates are provided, set latitude and longitude
        if let coordinates = coordinates {
            self.latitude = coordinates.latitude
            self.longitude = coordinates.longitude
        }
        
        if let address = address{
            self.fullAddress = address
        }
    }
    
    
    var address: String {
        return "\(address1 ?? String())\n\(address2 ?? String())"
    }
    
    var coordinates: CLLocationCoordinate2D {
        get {
            if latitude == nil || longitude == nil {
                return CLLocationCoordinate2D()
            }else{
                return CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!)
            }
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    var formattedStartDate: String {
        if(startDate == nil){
            return "N/A"
        }else{
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE MMM d"
            return formatter.string(from: startDate!)
        }
    }

    var formattedEndDate: String {
        if(endDate == nil){
            return "N/A"
        }else{
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE MMM d"
            return formatter.string(from: endDate!)
        }
    }

    // Conformance to Equatable
    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.club == rhs.club &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.city == rhs.city &&
               lhs.state == rhs.state &&
                lhs.fullAddress == rhs.fullAddress &&
               lhs.pocName == rhs.pocName &&
               lhs.pocEmail == rhs.pocEmail &&
               lhs.pocPhone == rhs.pocPhone &&
               lhs.coordinates.latitude == rhs.coordinates.latitude &&
               lhs.coordinates.longitude == rhs.coordinates.longitude
    }

    // Conformance to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(club)
        hasher.combine(startDate)
        hasher.combine(endDate)
        hasher.combine(city)
        hasher.combine(state)
        hasher.combine(fullAddress)
        hasher.combine(pocName)
        hasher.combine(pocEmail)
        hasher.combine(pocPhone)
        hasher.combine(latitude)
        hasher.combine(longitude)
        hasher.combine(isFavorite) // Include `isFavorite` in the hash
    }
}

extension Array where Element == Event {
    func groupedByMonthArray() -> [(String, [Event])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: self) { formatter.string(from: $0.startDate ?? Date()) }
        return grouped.sorted { lhs, rhs in
            guard let lhsDate = formatter.date(from: lhs.key),
                  let rhsDate = formatter.date(from: rhs.key) else {
                return false
            }
            return lhsDate < rhsDate
        }
    }
}
