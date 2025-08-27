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
        // Check stored credentials
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(StoredUser.self, from: userData) {
            self.currentUser = User(id: user.id, email: user.email, displayName: user.displayName, appleUserID: user.appleUserID, identityToken: user.identityToken)
            self.isAuthenticated = true
            
            // Check if Apple ID is still valid
            if let appleUserID = user.appleUserID {
                let appleIDProvider = ASAuthorizationAppleIDProvider()
                appleIDProvider.getCredentialState(forUserID: appleUserID) { [weak self] (credentialState, error) in
                    DispatchQueue.main.async {
                        switch credentialState {
                        case .authorized:
                            print("Apple ID credential is valid")
                        case .revoked, .notFound:
                            print("Apple ID credential revoked or not found")
                            self?.signOut()
                        default:
                            break
                        }
                    }
                }
            }
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
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "currentUser")
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
                print("Unable to fetch identity token")
                isSigningIn = false
                return
            }
            
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                isSigningIn = false
                return
            }
            
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            let displayName = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            
            // Note: email may be a private relay address (xxxxx@privaterelay.appleid.com)
            // or the user's real email if they chose to share it
            if let email = email {
                print("📧 User provided email: \(email.contains("@privaterelay.appleid.com") ? "Private relay" : "Real email")")
            }
            
            let user = User(
                id: UUID().uuidString, // Generate internal ID
                email: email,
                displayName: displayName.isEmpty ? nil : displayName,
                appleUserID: appleIDCredential.user,
                identityToken: idTokenString
            )
            
            self.currentUser = user
            self.isAuthenticated = true
            self.isSigningIn = false
            
            // Store user
            if let encoded = try? JSONEncoder().encode(StoredUser(from: user)) {
                UserDefaults.standard.set(encoded, forKey: "currentUser")
            }
            
            print("✅ Apple Sign In successful for user: \(appleIDCredential.user)")
            
            // TODO: Send user data to backend for association
            Task {
                await syncUserToBackend(user: user)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign In error: \(error.localizedDescription)")
        isSigningIn = false
    }
    
    private func syncUserToBackend(user: User) async {
        let preferencesService = UserPreferencesService()
        
        do {
            // Associate the Apple user with backend and get user ID + preferences in one call
            let (databaseUserId, existingPreferences) = try await preferencesService.associateAppleUser(user: user)
            print("✅ Successfully associated Apple user with backend")
            
            // Update the user with the correct database ID
            let updatedUser = User(
                id: databaseUserId,  // Use the database ID
                email: user.email,
                displayName: user.displayName,
                appleUserID: user.appleUserID,
                identityToken: user.identityToken
            )
            
            // Update our stored user with the correct ID
            self.currentUser = updatedUser
            if let encoded = try? JSONEncoder().encode(StoredUser(from: updatedUser)) {
                UserDefaults.standard.set(encoded, forKey: "currentUser")
            }
            
            // Check if we received existing preferences from the server
            if let existingPreferences = existingPreferences {
                print("📥 Found existing user preferences, applying to app")
                
                // Apply preferences to DataManager via notification
                NotificationCenter.default.post(name: .userPreferencesLoaded, object: existingPreferences)
            } else {
                print("👤 New user - will sync local preferences to backend when available")
                
                // Signal that we need to sync current local preferences to backend
                NotificationCenter.default.post(name: .newUserNeedsPreferenceSync, object: updatedUser)
            }
        } catch {
            print("❌ Failed to sync user to backend: \(error)")
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