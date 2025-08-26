//
//  AuthenticationManager.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import Foundation
import SwiftUI

struct User {
    let id: String
    let email: String?
    let displayName: String?
}

class AuthenticationManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    init() {
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        // Check stored credentials
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(StoredUser.self, from: userData) {
            self.currentUser = User(id: user.id, email: user.email, displayName: user.displayName)
            self.isAuthenticated = true
        }
    }
    
    func signIn() {
        // TODO: Implement actual sign-in flow
        // For now, mock a user
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

// Codable version for storage
private struct StoredUser: Codable {
    let id: String
    let email: String?
    let displayName: String?
    
    init(from user: User) {
        self.id = user.id
        self.email = user.email
        self.displayName = user.displayName
    }
}