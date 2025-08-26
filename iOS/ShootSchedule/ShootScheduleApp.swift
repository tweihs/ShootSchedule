//
//  ShootScheduleApp.swift
//  ShootSchedule
//
//  Created on 1/24/25.
//

import SwiftUI

// Location usage description for Info.plist
// This is handled by the build system in modern iOS projects
@main
struct ShootScheduleApp: App {
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
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // App is going to background, save data
                    dataManager.saveUserData()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // App entered background, ensure data is saved
                    dataManager.saveUserData()
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