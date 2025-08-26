//
//  UserDataManager.swift
//  ShootSchedule
//
//  Created on 1/24/25.
//

import Foundation

// Replica of Retool localStorage structure
struct UserData: Codable {
    var user: UserProfile
    var marked: [Int]
    var filterSettings: FilterSettings
    
    struct UserProfile: Codable {
        let uuid: String
        var temp: Bool = true
        
        init() {
            self.uuid = UUID().uuidString
            self.temp = true
        }
    }
    
    struct FilterSettings: Codable {
        var search: String = ""
        var shootTypes: [String] = []  // ["NSCA", "NSSA", "ATA"]
        var months: [Int] = []         // [1, 2, 3, ...12]
        var states: [String] = []      // ["AL", "AK", ...]
        var notable: Bool = false
        var future: Bool = true        // Default to future shoots
        var marked: Bool = false
    }
    
    init() {
        self.user = UserProfile()
        self.marked = []
        self.filterSettings = FilterSettings()
    }
}

class UserDataManager: ObservableObject {
    @Published var userData: UserData
    
    private let userDataKey = "shootScheduleUserData"
    
    init() {
        // Try to load existing user data
        if let savedData = UserDefaults.standard.data(forKey: userDataKey),
           let decodedData = try? JSONDecoder().decode(UserData.self, from: savedData) {
            self.userData = decodedData
        } else {
            // Create new user data with default filter settings
            var newData = UserData()
            newData.filterSettings.future = true // Default to showing future shoots
            self.userData = newData
            saveUserData()
        }
    }
    
    // MARK: - Persistence
    func saveUserData() {
        if let encoded = try? JSONEncoder().encode(userData) {
            UserDefaults.standard.set(encoded, forKey: userDataKey)
        }
    }
    
    // MARK: - Marked Shoots
    func isShootMarked(_ shootId: Int) -> Bool {
        return userData.marked.contains(shootId)
    }
    
    func markShoot(_ shootId: Int) {
        if !userData.marked.contains(shootId) {
            userData.marked.append(shootId)
            saveUserData()
        }
    }
    
    func unmarkShoot(_ shootId: Int) {
        userData.marked.removeAll { $0 == shootId }
        saveUserData()
    }
    
    func isShootMarked(id: Int) -> Bool {
        return userData.marked.contains(id)
    }
    
    func markShoot(id: Int) {
        if !userData.marked.contains(id) {
            userData.marked.append(id)
            saveUserData()
        }
    }
    
    func unmarkShoot(id: Int) {
        userData.marked.removeAll { $0 == id }
        saveUserData()
    }
    
    func getMarkedShootIds() -> [Int] {
        return userData.marked
    }
    
    // MARK: - Filter Settings
    func updateSearchText(_ text: String) {
        userData.filterSettings.search = text
        saveUserData()
    }
    
    func updateShootTypes(_ types: [String]) {
        userData.filterSettings.shootTypes = types
        saveUserData()
    }
    
    func updateMonths(_ months: [Int]) {
        userData.filterSettings.months = months
        saveUserData()
    }
    
    func updateStates(_ states: [String]) {
        userData.filterSettings.states = states
        saveUserData()
    }
    
    func updateNotableFilter(_ notable: Bool) {
        userData.filterSettings.notable = notable
        saveUserData()
    }
    
    func updateFutureFilter(_ future: Bool) {
        userData.filterSettings.future = future
        saveUserData()
    }
    
    func updateMarkedFilter(_ marked: Bool) {
        userData.filterSettings.marked = marked
        saveUserData()
    }
    
    // MARK: - Reset
    func resetFilters() {
        userData.filterSettings = UserData.FilterSettings()
        userData.filterSettings.future = true // Keep default future filter
        saveUserData()
    }
    
    // MARK: - JSON Import/Export
    func exportToJSON() throws -> Data {
        return try JSONEncoder().encode(userData)
    }
    
    func importFromJSON(_ data: Data) throws {
        let decodedData = try JSONDecoder().decode(UserData.self, from: data)
        userData = decodedData
        saveUserData()
    }
    
    // MARK: - Testing Support
    func clearAllData() {
        userData = UserData()
        userData.filterSettings.future = true
        saveUserData()
    }
    
    // MARK: - Debug
    func printUserData() {
        print("UserData JSON:", String(data: try! JSONEncoder().encode(userData), encoding: .utf8)!)
    }
}