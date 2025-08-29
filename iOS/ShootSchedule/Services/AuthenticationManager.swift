//
//  AuthenticationManager.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit
import os

// MARK: - Import DataManager for Logger extensions
// Note: Logger extensions are temporarily defined in DataManager.swift
// until AppLogger.swift is added to the Xcode project

// MARK: - Notification Names
extension NSNotification.Name {
    static let userPreferencesLoaded = NSNotification.Name("userPreferencesLoaded")
    static let newUserNeedsPreferenceSync = NSNotification.Name("newUserNeedsPreferenceSync")
}

struct User {
    let id: String
    let email: String?
    let displayName: String?
    let appleUserID: String?
    let identityToken: String?
    
    init(id: String, email: String?, displayName: String?, appleUserID: String? = nil, identityToken: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.appleUserID = appleUserID
        self.identityToken = identityToken
    }
}

// MARK: - Local User Preferences
// Single object to store all user preferences locally
struct LocalUserPreferences: Codable {
    var calendarSyncEnabled: Bool = false
    var useFahrenheit: Bool = true
    var selectedCalendarSourceId: String? = nil
    var hasSelectedCalendarSource: Bool = false
    var markedShootIds: Set<Int> = []
    var filterSettings: FilterSettingsData? = nil
    
    struct FilterSettingsData: Codable {
        var search: String = ""
        var shootTypes: [String] = []
        var months: [Int] = []
        var states: [String] = []
        var notable: Bool = false
        var future: Bool = true
        var marked: Bool = false
    }
    
    static let storageKey = "userPreferences"
    
    // Load preferences from UserDefaults
    static func load() -> LocalUserPreferences {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let preferences = try? JSONDecoder().decode(LocalUserPreferences.self, from: data) {
            return preferences
        }
        return LocalUserPreferences() // Return default preferences
    }
    
    // Save preferences to UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: LocalUserPreferences.storageKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    // Clear all preferences
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.synchronize()
    }
}

class AuthenticationManager: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isSigningIn = false
    
    private var currentNonce: String?
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        Logger.auth.debug("🔐 Checking authentication status...")
        
        // Check stored credentials
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(StoredUser.self, from: userData) {
            self.currentUser = User(id: user.id, email: user.email, displayName: user.displayName, appleUserID: user.appleUserID, identityToken: user.identityToken)
            self.isAuthenticated = true
            
            Logger.auth.info("👤 Current user loaded:")
            Logger.auth.debug("   - Email: \(user.email ?? "none")")
            Logger.auth.debug("   - Display Name: \(user.displayName ?? "none")")
            Logger.auth.debug("   - User ID: \(user.id)")
            Logger.auth.debug("   - Apple User ID: \(user.appleUserID ?? "none")")
            
            // If email or displayName is missing, log warning but don't fetch
            if user.email == nil || user.displayName == nil {
                Logger.auth.warning("⚠️ User data incomplete - email: \(user.email ?? "missing"), displayName: \(user.displayName ?? "missing")")
                Logger.auth.warning("⚠️ This should only happen if the user data was corrupted or cleared")
            }
            
            // Check if Apple ID is still valid
            if let appleUserID = user.appleUserID {
                let appleIDProvider = ASAuthorizationAppleIDProvider()
                appleIDProvider.getCredentialState(forUserID: appleUserID) { [weak self] (credentialState, error) in
                    DispatchQueue.main.async {
                        switch credentialState {
                        case .authorized:
                            Logger.auth.debug("✅ Apple ID credential is valid")
                        case .revoked, .notFound:
                            Logger.auth.warning("❌ Apple ID credential revoked or not found")
                            self?.signOut()
                        default:
                            break
                        }
                    }
                }
            }
        } else {
            Logger.auth.info("👤 No stored user credentials found")
        }
    }
    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
        
        isSigningIn = true
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // Legacy mock sign in for development
    func signInMock() {
        let mockUser = User(
            id: UUID().uuidString,
            email: "user@example.com",
            displayName: "Tyson Weihs"
        )
        self.currentUser = mockUser
        self.isAuthenticated = true
        
        // Store user
        if let encoded = try? JSONEncoder().encode(StoredUser(from: mockUser)) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
        }
    }
    
    func signOut() {
        Logger.auth.info("🚪 User signing out - clearing all local data")
        
        // Clear user data
        currentUser = nil
        isAuthenticated = false
        
        // Clear stored user credentials
        UserDefaults.standard.removeObject(forKey: "currentUser")
        
        // Clear all user preferences with single call
        LocalUserPreferences.clear()
        
        // Ensure synchronization
        UserDefaults.standard.synchronize()
        
        Logger.auth.info("✅ All local user data cleared")
    }
}

// MARK: - Apple Sign In Delegates

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            
            guard let appleIDToken = appleIDCredential.identityToken else {
                Logger.auth.error("Unable to fetch identity token")
                isSigningIn = false
                return
            }
            
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                Logger.auth.error("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                isSigningIn = false
                return
            }
            
            // Check if we already have stored user data for this Apple ID
            var storedEmail: String? = nil
            var storedDisplayName: String? = nil
            
            if let existingUserData = UserDefaults.standard.data(forKey: "currentUser"),
               let existingUser = try? JSONDecoder().decode(StoredUser.self, from: existingUserData),
               existingUser.appleUserID == appleIDCredential.user {
                // We have existing user data for this Apple ID
                storedEmail = existingUser.email
                storedDisplayName = existingUser.displayName
                Logger.auth.debug("📂 Found existing stored data for Apple ID: email=\(storedEmail ?? "none"), displayName=\(storedDisplayName ?? "none")")
            }
            
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            let displayName = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            
            // Use new values if provided, otherwise use stored values
            let finalEmail = email ?? storedEmail
            let finalDisplayName = displayName.isEmpty ? storedDisplayName : displayName
            
            // Note: email may be a private relay address (xxxxx@privaterelay.appleid.com)
            // or the user's real email if they chose to share it
            if let email = email {
                Logger.auth.info("📧 User provided NEW email: \(email.contains("@privaterelay.appleid.com") ? "Private relay" : "Real email")")
            } else if let storedEmail = storedEmail {
                Logger.auth.debug("📧 Using STORED email: \(storedEmail)")
            }
            
            if !displayName.isEmpty {
                Logger.auth.info("👤 User provided NEW display name: \(displayName)")
            } else if let storedDisplayName = storedDisplayName {
                Logger.auth.debug("👤 Using STORED display name: \(storedDisplayName)")
            }
            
            let user = User(
                id: UUID().uuidString, // Generate internal ID (will be updated by backend)
                email: finalEmail,
                displayName: finalDisplayName,
                appleUserID: appleIDCredential.user,
                identityToken: idTokenString
            )
            
            self.currentUser = user
            self.isAuthenticated = true
            self.isSigningIn = false
            
            // Store user with all available data
            if let encoded = try? JSONEncoder().encode(StoredUser(from: user)) {
                UserDefaults.standard.set(encoded, forKey: "currentUser")
                Logger.auth.info("💾 Saved user data locally with email: \(user.email ?? "none"), displayName: \(user.displayName ?? "none")")
            }
            
            Logger.auth.info("✅ Apple Sign In successful for user: \(appleIDCredential.user)")
            
            // TODO: Send user data to backend for association
            Task {
                await syncUserToBackend(user: user)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Logger.auth.error("❌ Apple Sign In error: \(error.localizedDescription)")
        isSigningIn = false
    }
    
    private func syncUserToBackend(user: User) async {
        let preferencesService = UserPreferencesService()
        
        do {
            // Associate the Apple user with backend and get user ID + preferences in one call
            let (databaseUserId, backendEmail, backendDisplayName, existingPreferences) = try await preferencesService.associateAppleUser(user: user)
            Logger.auth.info("✅ Successfully associated Apple user with backend")
            
            // Update the user with the correct database ID
            // For email and displayName, prefer local values, then backend values
            let updatedUser = User(
                id: databaseUserId,  // Use the database ID from backend
                email: user.email ?? backendEmail,  // Keep local email if we have it
                displayName: user.displayName ?? backendDisplayName,  // Keep local displayName if we have it
                appleUserID: user.appleUserID,
                identityToken: user.identityToken
            )
            
            Logger.auth.info("📝 Updated user data:")
            Logger.auth.debug("   - Email: \(updatedUser.email ?? "none")")
            Logger.auth.debug("   - Display Name: \(updatedUser.displayName ?? "none")")
            Logger.auth.debug("   - Database ID: \(updatedUser.id)")
            
            // Update our stored user with the correct ID
            self.currentUser = updatedUser
            if let encoded = try? JSONEncoder().encode(StoredUser(from: updatedUser)) {
                UserDefaults.standard.set(encoded, forKey: "currentUser")
            }
            
            // Check if we received existing preferences from the server
            if let existingPreferences = existingPreferences {
                Logger.sync.info("📥 Found existing user preferences, applying to app")
                
                // Apply preferences to DataManager via notification
                NotificationCenter.default.post(name: .userPreferencesLoaded, object: existingPreferences)
            } else {
                Logger.sync.info("👤 New user - will sync local preferences to backend when available")
                
                // Signal that we need to sync current local preferences to backend
                NotificationCenter.default.post(name: .newUserNeedsPreferenceSync, object: updatedUser)
            }
        } catch {
            Logger.auth.error("❌ Failed to sync user to backend: \(error)")
            // Don't prevent login on sync failure - user can still use app locally
        }
    }
}

extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign In")
        }
        return window
    }
}

// Codable version for storage
private struct StoredUser: Codable {
    let id: String
    let email: String?
    let displayName: String?
    let appleUserID: String?
    let identityToken: String?
    
    init(from user: User) {
        self.id = user.id
        self.email = user.email
        self.displayName = user.displayName
        self.appleUserID = user.appleUserID
        self.identityToken = user.identityToken
    }
}