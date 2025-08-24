//
//  DataManager.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import Foundation
import Combine

class DataManager: ObservableObject {
    @Published var shoots: [Shoot] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var markedShootIds: Set<Int> = []
    private let markedShootsKey = "markedShoots"
    
    init() {
        loadMarkedShoots()
        loadSampleData() // For testing
    }
    
    func loadCachedData() {
        // Load from cache if available
        if let cachedData = UserDefaults.standard.data(forKey: "cachedShoots"),
           let cachedShoots = try? JSONDecoder().decode([Shoot].self, from: cachedData) {
            self.shoots = cachedShoots
        }
    }
    
    func fetchShoots() {
        isLoading = true
        // TODO: Implement actual API call
        // For now, use sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.loadSampleData()
            self?.isLoading = false
        }
    }
    
    func markShoot(_ shoot: Shoot) {
        markedShootIds.insert(shoot.id)
        saveMarkedShoots()
        
        // Update the shoot in the array
        if let index = shoots.firstIndex(where: { $0.id == shoot.id }) {
            shoots[index].isMarked = true
        }
    }
    
    func unmarkShoot(_ shoot: Shoot) {
        markedShootIds.remove(shoot.id)
        saveMarkedShoots()
        
        // Update the shoot in the array
        if let index = shoots.firstIndex(where: { $0.id == shoot.id }) {
            shoots[index].isMarked = false
        }
    }
    
    func isShootMarked(_ shoot: Shoot) -> Bool {
        return markedShootIds.contains(shoot.id)
    }
    
    private func loadMarkedShoots() {
        if let data = UserDefaults.standard.data(forKey: markedShootsKey),
           let ids = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            markedShootIds = ids
        }
    }
    
    private func saveMarkedShoots() {
        if let data = try? JSONEncoder().encode(markedShootIds) {
            UserDefaults.standard.set(data, forKey: markedShootsKey)
        }
    }
    
    private func loadSampleData() {
        // Create sample data matching the screenshots
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        shoots = [
            Shoot(
                id: 1,
                shootName: "WESTERN REGIONAL 2025",
                shootType: "Regional",
                startDate: formatter.date(from: "2025-08-25")!,
                endDate: formatter.date(from: "2025-08-28")!,
                clubName: "ROCK CREEK RANCH, A LITTLE TRAPPER CLUB",
                address1: nil,
                address2: nil,
                city: "EMMETT",
                state: "ID",
                zip: nil,
                country: "USA",
                zone: nil,
                clubEmail: nil,
                pocName: nil,
                pocPhone: nil,
                pocEmail: nil,
                clubID: nil,
                eventType: "NSCA",
                region: "Western",
                fullAddress: nil,
                latitude: 43.8735,
                longitude: -116.4993,
                isMarked: false
            ),
            Shoot(
                id: 2,
                shootName: "CLAYS FOR DAYS SHOOT",
                shootType: nil,
                startDate: formatter.date(from: "2025-08-25")!,
                endDate: nil,
                clubName: "BERETTA SHOOTING GROUNDS",
                address1: nil,
                address2: nil,
                city: "ADAIRSVILLE",
                state: "GA",
                zip: nil,
                country: "USA",
                zone: nil,
                clubEmail: nil,
                pocName: nil,
                pocPhone: nil,
                pocEmail: nil,
                clubID: nil,
                eventType: "NSCA",
                region: nil,
                fullAddress: nil,
                latitude: 34.3687,
                longitude: -84.9341,
                isMarked: false
            ),
            Shoot(
                id: 3,
                shootName: "BLACKMORE CHALLENGE 3",
                shootType: nil,
                startDate: formatter.date(from: "2025-08-26")!,
                endDate: nil,
                clubName: "BLACKMORE SHOOTING SPORTS",
                address1: nil,
                address2: nil,
                city: "WINFIELD",
                state: "None",
                zip: nil,
                country: "USA",
                zone: nil,
                clubEmail: nil,
                pocName: nil,
                pocPhone: nil,
                pocEmail: nil,
                clubID: nil,
                eventType: "NSCA",
                region: nil,
                fullAddress: nil,
                latitude: nil,
                longitude: nil,
                isMarked: false
            ),
            Shoot(
                id: 4,
                shootName: "WEDNESDAY NIGHT SPORTING CLAYS #1",
                shootType: nil,
                startDate: formatter.date(from: "2025-08-27")!,
                endDate: nil,
                clubName: "BIRCHWOOD RECREATION SHOOTING",
                address1: nil,
                address2: nil,
                city: "CHUGIAK",
                state: "AK",
                zip: nil,
                country: "USA",
                zone: nil,
                clubEmail: nil,
                pocName: nil,
                pocPhone: nil,
                pocEmail: nil,
                clubID: nil,
                eventType: "NSCA",
                region: nil,
                fullAddress: nil,
                latitude: 61.3955,
                longitude: -149.4799,
                isMarked: false
            ),
            Shoot(
                id: 5,
                shootName: "TARGET BLAST # 6",
                shootType: nil,
                startDate: formatter.date(from: "2025-08-27")!,
                endDate: nil,
                clubName: "THE GALT SPORTMEN'S CLUB",
                address1: nil,
                address2: nil,
                city: "CAMBRIDGE",
                state: "None",
                zip: nil,
                country: "USA",
                zone: nil,
                clubEmail: nil,
                pocName: nil,
                pocPhone: nil,
                pocEmail: nil,
                clubID: nil,
                eventType: "NSCA",
                region: nil,
                fullAddress: nil,
                latitude: nil,
                longitude: nil,
                isMarked: false
            ),
            Shoot(
                id: 6,
                shootName: "PIEDMONT LABOR DAY OPEN",
                shootType: nil,
                startDate: formatter.date(from: "2025-08-28")!,
                endDate: formatter.date(from: "2025-09-01")!,
                clubName: "PIEDMONT SPORTSMAN CLUB",
                address1: nil,
                address2: nil,
                city: "GORDONSVILLE",
                state: "VA",
                zip: nil,
                country: "USA",
                zone: nil,
                clubEmail: nil,
                pocName: nil,
                pocPhone: nil,
                pocEmail: nil,
                clubID: nil,
                eventType: "NSSA",
                region: nil,
                fullAddress: nil,
                latitude: 38.1375,
                longitude: -78.1875,
                isMarked: false
            ),
            Shoot(
                id: 7,
                shootName: "MISSISSIPPI STATE CHAMPIONSHIP",
                shootType: "State Championship",
                startDate: formatter.date(from: "2025-08-28")!,
                endDate: formatter.date(from: "2025-08-31")!,
                clubName: "DESOTO RIFLE AND PISTOL CLUB",
                address1: nil,
                address2: nil,
                city: "COMO",
                state: "MS",
                zip: nil,
                country: "USA",
                zone: nil,
                clubEmail: nil,
                pocName: nil,
                pocPhone: nil,
                pocEmail: nil,
                clubID: nil,
                eventType: "NSCA",
                region: nil,
                fullAddress: nil,
                latitude: 34.5112,
                longitude: -89.9404,
                isMarked: false
            )
        ]
        
        // Apply marked status
        for index in shoots.indices {
            shoots[index].isMarked = markedShootIds.contains(shoots[index].id)
        }
    }
}