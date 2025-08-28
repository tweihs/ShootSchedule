//
//  UserPreferencesService.swift
//  ShootSchedule
//
//  Created on 8/26/25.
//

import Foundation

struct UserPreferences: Codable {
    let userId: String
    let filterSettings: FilterSettings
    let markedShoots: [Int]
    let temperatureUnit: String // "fahrenheit" or "celsius"
    let calendarSyncEnabled: Bool
    
    struct FilterSettings: Codable {
        let search: String
        let shootTypes: [String]       // ["NSCA", "NSSA", "ATA"] - matches UserDataManager
        let months: [Int]              // [1, 2, 3, ...12]
        let states: [String]           // ["AL", "AK", ...]
        let notable: Bool              // matches UserDataManager
        let future: Bool               // matches UserDataManager  
        let marked: Bool               // matches UserDataManager
    }
    
    // Custom decoding to handle missing fields with defaults
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        filterSettings = try container.decode(FilterSettings.self, forKey: .filterSettings)
        markedShoots = try container.decodeIfPresent([Int].self, forKey: .markedShoots) ?? []
        temperatureUnit = try container.decodeIfPresent(String.self, forKey: .temperatureUnit) ?? "fahrenheit"
        // Use local value as default if server doesn't have the preference
        calendarSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .calendarSyncEnabled) ?? UserDefaults.standard.bool(forKey: "calendarSyncEnabled")
    }
    
    // Standard initializer for creating instances
    init(userId: String, filterSettings: FilterSettings, markedShoots: [Int], temperatureUnit: String, calendarSyncEnabled: Bool) {
        self.userId = userId
        self.filterSettings = filterSettings
        self.markedShoots = markedShoots
        self.temperatureUnit = temperatureUnit
        self.calendarSyncEnabled = calendarSyncEnabled
    }
    
    enum CodingKeys: String, CodingKey {
        case userId
        case filterSettings
        case markedShoots
        case temperatureUnit
        case calendarSyncEnabled
    }
}

struct AppleUserAssociation: Codable {
    let appleUserID: String
    let email: String?
    let displayName: String?
    let identityToken: String
    
    enum CodingKeys: String, CodingKey {
        case appleUserID
        case email
        case displayName
        case identityToken
    }
}

class UserPreferencesService: ObservableObject {
    private let baseURL = "https://us-central1-shootsdb-11bb7.cloudfunctions.net"
    private let session = URLSession.shared
    
    // MARK: - User Association
    
    // Response structure for the enriched associateAppleUser endpoint
    struct AssociationResponse: Codable {
        let userId: String
        let isNewUser: Bool
        let email: String?
        let displayName: String?
        let createdAt: String?
        let preferences: UserPreferencesData?
        
        struct UserPreferencesData: Codable {
            let filterSettings: FilterSettingsData?
            let markedShoots: [Int]?
            
            struct FilterSettingsData: Codable {
                let search: String?
                let shootTypes: [String]?
                let months: [Int]?
                let states: [String]?
                let notable: Bool?
                let future: Bool?
                let marked: Bool?
            }
        }
    }
    
    func associateAppleUser(user: User) async throws -> (userId: String, preferences: UserPreferences?) {
        guard let appleUserID = user.appleUserID,
              let identityToken = user.identityToken else {
            print("❌ Missing Apple credentials - appleUserID: \(user.appleUserID ?? "nil"), identityToken: \(user.identityToken != nil ? "present" : "nil")")
            throw UserPreferencesError.missingAppleCredentials
        }
        
        let association = AppleUserAssociation(
            appleUserID: appleUserID,
            email: user.email,
            displayName: user.displayName,
            identityToken: identityToken
        )
        
        let endpoint = URL(string: "\(baseURL)/associateAppleUser")!
        print("📡 Calling Firebase function: \(endpoint)")
        print("   Apple ID: \(appleUserID)")
        print("   Email: \(user.email ?? "none")")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(association)
            print("📤 Sending request to: \(endpoint)")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw UserPreferencesError.serverError
            }
            
            print("📥 Response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Response data: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                print("❌ Server returned error status: \(httpResponse.statusCode)")
                throw UserPreferencesError.serverError
            }
            
            let associationResponse = try JSONDecoder().decode(AssociationResponse.self, from: data)
            print("✅ Successfully associated Apple user: \(appleUserID)")
            print("   Database User ID: \(associationResponse.userId)")
            print("   Is new user: \(associationResponse.isNewUser)")
            
            // Convert response preferences to UserPreferences if they exist
            var userPreferences: UserPreferences? = nil
            if let prefs = associationResponse.preferences {
                let filterSettings = UserPreferences.FilterSettings(
                    search: prefs.filterSettings?.search ?? "",
                    shootTypes: prefs.filterSettings?.shootTypes ?? [],
                    months: prefs.filterSettings?.months ?? [],
                    states: prefs.filterSettings?.states ?? [],
                    notable: prefs.filterSettings?.notable ?? false,
                    future: prefs.filterSettings?.future ?? true,
                    marked: prefs.filterSettings?.marked ?? false
                )
                
                userPreferences = UserPreferences(
                    userId: associationResponse.userId,
                    filterSettings: filterSettings,
                    markedShoots: prefs.markedShoots ?? [],
                    temperatureUnit: "fahrenheit", // Default, will be overridden if preferences exist
                    calendarSyncEnabled: UserDefaults.standard.bool(forKey: "calendarSyncEnabled") // Use local value as default
                )
                
                print("📥 Preferences included in response for existing user")
            } else {
                print("👤 New user - no preferences to load")
            }
            
            return (associationResponse.userId, userPreferences)
        } catch {
            print("❌ Failed to associate Apple user: \(error)")
            print("   Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Preference Synchronization
    
    func syncUserPreferences(user: User, preferences: UserPreferences) async throws {
        let endpoint = URL(string: "\(baseURL)/syncUserPreferences")!
        print("📤 Syncing preferences to: \(endpoint)")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(user.identityToken ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            request.httpBody = try encoder.encode(preferences)
            
            // Log the JSON being sent
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                print("📤 JSON being sent to database:")
                print("=====================================")
                print(jsonString)
                print("=====================================")
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw UserPreferencesError.serverError
            }
            
            print("📥 Sync response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Sync response data: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                print("❌ Server returned error status: \(httpResponse.statusCode)")
                throw UserPreferencesError.serverError
            }
            
            print("✅ Successfully synced user preferences for: \(user.id)")
        } catch {
            print("❌ Failed to sync user preferences: \(error)")
            print("   Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchUserPreferences(for user: User) async throws -> UserPreferences? {
        let endpoint = URL(string: "\(baseURL)/fetchUserPreferences?userId=\(user.id)")!
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(user.identityToken ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UserPreferencesError.serverError
            }
            
            if httpResponse.statusCode == 404 {
                return nil // No preferences found - new user
            }
            
            guard httpResponse.statusCode == 200 else {
                throw UserPreferencesError.serverError
            }
            
            let preferences = try JSONDecoder().decode(UserPreferences.self, from: data)
            print("✅ Successfully fetched user preferences for: \(user.id)")
            return preferences
        } catch {
            print("❌ Failed to fetch user preferences: \(error)")
            throw error
        }
    }
    
    // MARK: - Marked Shoots Management
    
    func syncMarkedShoots(user: User, markedShootIds: [Int]) async throws {
        let endpoint = URL(string: "\(baseURL)/syncUserPreferences")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(user.identityToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "userId": user.id,
            "markedShoots": markedShootIds
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                throw UserPreferencesError.serverError
            }
            
            print("✅ Successfully synced marked shoots for: \(user.id)")
        } catch {
            print("❌ Failed to sync marked shoots: \(error)")
            throw error
        }
    }
    
    // MARK: - Local to Remote Preference Mapping
    
    func createUserPreferences(from user: User, dataManager: DataManager) -> UserPreferences {
        let filterSettings = UserPreferences.FilterSettings(
            search: dataManager.filterOptions?.searchText ?? "",
            shootTypes: Array(dataManager.filterOptions?.selectedAffiliations.map { $0.rawValue } ?? []),
            months: Array(dataManager.filterOptions?.selectedMonths ?? []),
            states: Array(dataManager.filterOptions?.selectedStates ?? []),
            notable: dataManager.filterOptions?.showNotableOnly ?? false,
            future: dataManager.filterOptions?.showFutureOnly ?? true,
            marked: false  // Always false - this is just a view filter, not a saved preference
        )
        
        let markedShootIds = Array(dataManager.markedShootIds)
        
        return UserPreferences(
            userId: user.id,
            filterSettings: filterSettings,
            markedShoots: markedShootIds,
            temperatureUnit: UserDefaults.standard.bool(forKey: "useFahrenheit") ? "fahrenheit" : "celsius",
            calendarSyncEnabled: dataManager.isCalendarSyncEnabled
        )
    }
    
    func applyUserPreferences(_ preferences: UserPreferences, to dataManager: DataManager) {
        // Update filter options
        DispatchQueue.main.async {
            if let filterOptions = dataManager.filterOptions {
                filterOptions.searchText = preferences.filterSettings.search
                filterOptions.selectedAffiliations = Set(preferences.filterSettings.shootTypes.compactMap { ShootAffiliation(rawValue: $0) })
                filterOptions.selectedMonths = Set(preferences.filterSettings.months)
                filterOptions.selectedStates = Set(preferences.filterSettings.states)
                filterOptions.showNotableOnly = preferences.filterSettings.notable
                filterOptions.showFutureOnly = preferences.filterSettings.future
                // Note: showMarkedOnly is NOT set from preferences - it's just a view filter
            }
            
            // Update marked shoots
            let previousMarkedShootIds = dataManager.markedShootIds
            dataManager.markedShootIds = Set(preferences.markedShoots)
            
            print("📥 Applying marked shoots from server:")
            print("   Previous local: \(Array(previousMarkedShootIds).sorted()) (count: \(previousMarkedShootIds.count))")
            print("   New from server: \(Array(dataManager.markedShootIds).sorted()) (count: \(dataManager.markedShootIds.count))")
            
            // Always update local storage and UI when receiving from server
            // Save to local storage only (iCloud and UserDefaults)
            if let data = try? JSONEncoder().encode(dataManager.markedShootIds) {
                let iCloudStore = NSUbiquitousKeyValueStore.default
                iCloudStore.set(data, forKey: "markedShoots")
                iCloudStore.synchronize()
                UserDefaults.standard.set(data, forKey: "markedShoots_backup")
                UserDefaults.standard.synchronize()
                print("📥 Saved marked shoots to local storage: \(Array(dataManager.markedShootIds).sorted())")
            }
            
            // Always apply to shoots list and update UI
            dataManager.applyMarkedStatus() // Apply to shoots list
            // Trigger UI update for marked count
            dataManager.objectWillChange.send()
            
            print("📥 Marked count after apply: \(dataManager.markedShootsCount)")
            
            // Update temperature preference
            let useFahrenheit = preferences.temperatureUnit == "fahrenheit"
            UserDefaults.standard.set(useFahrenheit, forKey: "useFahrenheit")
            
            // Update calendar sync - apply server setting to all devices
            dataManager.setCalendarSyncEnabled(preferences.calendarSyncEnabled)
        }
    }
}

// MARK: - Error Types

enum UserPreferencesError: Error, LocalizedError {
    case missingAppleCredentials
    case serverError
    case invalidResponse
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .missingAppleCredentials:
            return "Missing Apple Sign In credentials"
        case .serverError:
            return "Server error occurred"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network connection error"
        }
    }
}