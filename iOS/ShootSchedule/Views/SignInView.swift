//
//  SignInView.swift
//  ShootSchedule
//
//  Created on 8/26/25.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            // Same background as splash screen and app
            Color(red: 1.0, green: 0.992, blue: 0.973)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Replicate splash screen logo layout
                VStack(spacing: 0) {
                    Image("LaunchLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                }
                .offset(y: -50) // Same offset as launch screen
                
                Spacer()
                
                // Sign in with Apple button at bottom
                VStack(spacing: 16) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            // This is handled by AuthenticationManager
                        },
                        onCompletion: { result in
                            // This is handled by AuthenticationManager
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .onTapGesture {
                        authManager.signInWithApple()
                    }
                    
                    Text("Sign in to sync your preferences across devices")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    #if targetEnvironment(simulator)
                    // Mock sign-in for simulator testing
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
            }
        }
        .navigationBarHidden(true)
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .environmentObject(AuthenticationManager())
    }
}