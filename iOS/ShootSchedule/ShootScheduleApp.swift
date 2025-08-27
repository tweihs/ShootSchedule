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
    @State private var showSignIn = false
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(dataManager)
                    .onAppear {
                        setupApp()
                        // Setup authenticated features now that user is logged in
                        dataManager.setupAuthenticatedFeatures()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        // App is returning to foreground, sync preferences from server
                        print("📱 App returning to foreground, syncing preferences...")
                        Task {
                            // Small delay to ensure UI is ready
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            await dataManager.fetchAndApplyUserPreferences()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        // App is going to background, save data
                        dataManager.saveUserData()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                        // App entered background, ensure data is saved
                        dataManager.saveUserData()
                    }
            } else {
                // Inline SignInView to avoid import issues
                ZStack {
                    Color(red: 1.0, green: 0.992, blue: 0.973)
                        .ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        // Logo with same sizing constraints as launch screen
                        Image("LaunchLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(minWidth: 393, minHeight: 328)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .offset(y: -50)
                        
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Button("Sign in with Apple") {
                                authManager.signInWithApple()
                            }
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            
                            Text("Sign in to save your shoots, sync with your calendar, and share your schedule with friends.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Text("We'll use your email to link your account across devices")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .padding(.top, 4)
                            
                            #if targetEnvironment(simulator)
                            Button("Skip Sign In (Simulator Only)") {
                                authManager.signInMock()
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                            #endif
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 50)
                        .opacity(showSignIn ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.8), value: showSignIn)
                    }
                }
                .navigationBarHidden(true)
                .environmentObject(authManager)
                .environmentObject(dataManager)
                .onAppear {
                    setupApp()
                    // Delay the sign-in UI appearance to allow splash screen to show first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSignIn = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // App is returning to foreground, sync preferences if authenticated
                    if authManager.isAuthenticated {
                        print("📱 App returning to foreground, syncing preferences...")
                        Task {
                            // Small delay to ensure UI is ready
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            await dataManager.fetchAndApplyUserPreferences()
                        }
                    }
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
    }
    
    private func setupApp() {
        // Configure appearance
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.label]
        
        // Connect managers
        dataManager.authManager = authManager
        
        // Load cached data
        dataManager.loadCachedData()
        
        // Check authentication status
        authManager.checkAuthenticationStatus()
    }
}
