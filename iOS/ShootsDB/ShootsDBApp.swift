//
//  ShootsDBApp.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

@main
struct ShootsDBApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(dataManager)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Configure appearance
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.label]
        
        // Load cached data
        dataManager.loadCachedData()
        
        // Check authentication status
        authManager.checkAuthenticationStatus()
    }
}