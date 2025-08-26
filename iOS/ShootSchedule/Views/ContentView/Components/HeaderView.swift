//
//  HeaderView.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var showAccountDetails: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ShootSchedule")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(" NSSA-NSCA shoots finder and scheduler. Created by Postflight.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // User Settings Avatar
            Button(action: {
                showAccountDetails = true
            }) {
                UserAvatarView()
            }
        }
    }
}

// MARK: - User Avatar Component
struct UserAvatarView: View {
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Previews
struct HeaderView_Previews: PreviewProvider {
    @State static var showAccountDetails = false
    
    static var previews: some View {
        Group {
            // Logged out state
            HeaderView(showAccountDetails: .constant(false))
                .environmentObject({
                    let authManager = AuthenticationManager()
                    return authManager
                }())
                .padding()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Logged Out")
            
            // Logged in state with display name
            HeaderView(showAccountDetails: .constant(false))
                .environmentObject({
                    let authManager = AuthenticationManager()
                    authManager.currentUser = User(
                        id: "123",
                        email: "john.doe@example.com",
                        displayName: "John Doe"
                    )
                    return authManager
                }())
                .padding()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Logged In - Full Name")
            
            // Logged in state with email only
            HeaderView(showAccountDetails: .constant(false))
                .environmentObject({
                    let authManager = AuthenticationManager()
                    authManager.currentUser = User(
                        id: "456",
                        email: "jane@example.com",
                        displayName: nil
                    )
                    return authManager
                }())
                .padding()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Logged In - Email Only")
            
            // Logged in state with single name
            HeaderView(showAccountDetails: .constant(false))
                .environmentObject({
                    let authManager = AuthenticationManager()
                    authManager.currentUser = User(
                        id: "789",
                        email: "alice@example.com",
                        displayName: "Alice"
                    )
                    return authManager
                }())
                .padding()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Logged In - Single Name")
        }
    }
}
