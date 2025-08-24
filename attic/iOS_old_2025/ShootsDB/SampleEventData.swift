//
//  SampleEventData.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/8/24.
//

import Foundation
import MapKit

let sampleEvents = [
    Event(
        name: "Winter Shootout",
        club: "Aspen Skeet Club",
        startDate: Date(timeIntervalSince1970: 1704067200), // Jan 1, 2024
        endDate: Date(timeIntervalSince1970: 1704326400),   // Jan 3, 2024
        city: "Aspen",
        state: "CO",
        address: "123 Main Street, Aspen, CO 81611",
        pocName: "John Doe",
        pocEmail: "johndoe@example.com",
        pocPhone: "(123) 456-7890",
        coordinates: CLLocationCoordinate2D(latitude: 39.1911, longitude: -106.8175)
    ),
    Event(
        name: "New Year Blast",
        club: "Denver Gun Club",
        startDate: Date(timeIntervalSince1970: 1704153600), // Jan 2, 2024
        endDate: Date(timeIntervalSince1970: 1704412800),   // Jan 4, 2024
        city: "Denver",
        state: "CO",
        address: "456 Elm Street, Denver, CO 80202",
        pocName: "Jane Smith",
        pocEmail: "janesmith@example.com",
        pocPhone: "(987) 654-3210",
        coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
    ),
    Event(
        name: "Snowy Skeet Challenge",
        club: "Boulder Shooting Range",
        startDate: Date(timeIntervalSince1970: 1704500000), // Jan 3, 2024
        endDate: Date(timeIntervalSince1970: 1704600000),   // Jan 5, 2024
        city: "Boulder",
        state: "CO",
        address: "789 Maple Avenue, Boulder, CO 80301",
        pocName: "Michael Brown",
        pocEmail: "michaelbrown@example.com",
        pocPhone: "(555) 123-4567",
        coordinates: CLLocationCoordinate2D(latitude: 40.0150, longitude: -105.2705)
    ),
    Event(
        name: "Frosty Clays",
        club: "Eagle Valley Club",
        startDate: Date(timeIntervalSince1970: 1704700000), // Jan 4, 2024
        endDate: Date(timeIntervalSince1970: 1704900000),   // Jan 6, 2024
        city: "Eagle",
        state: "CO",
        address: "101 Pine Street, Eagle, CO 81631",
        pocName: "Lisa Johnson",
        pocEmail: "lisajohnson@example.com",
        pocPhone: "(444) 555-6666",
        coordinates: CLLocationCoordinate2D(latitude: 39.6553, longitude: -106.8287)
    ),
    Event(
        name: "January Open",
        club: "Glenwood Gun Club",
        startDate: Date(timeIntervalSince1970: 1705000000), // Jan 6, 2024
        endDate: Date(timeIntervalSince1970: 1705200000),   // Jan 8, 2024
        city: "Glenwood Springs",
        state: "CO",
        address: "202 Birch Road, Glenwood Springs, CO 81601",
        pocName: "Emily Davis",
        pocEmail: "emilydavis@example.com",
        pocPhone: "(333) 444-5555",
        coordinates: CLLocationCoordinate2D(latitude: 39.5501, longitude: -107.3248)
    )
]

