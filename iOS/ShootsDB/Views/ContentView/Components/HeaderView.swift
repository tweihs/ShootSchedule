//
//  HeaderView.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ShootsDB")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Find NSSA and NSCA shoots")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let user = authManager.currentUser {
                HStack(spacing: 12) {
                    Text(user.displayName ?? user.email ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        authManager.signOut()
                    }) {
                        Text("Logout")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Button(action: {
                    authManager.signIn()
                }) {
                    Text("Login")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView()
            .environmentObject(AuthenticationManager())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}