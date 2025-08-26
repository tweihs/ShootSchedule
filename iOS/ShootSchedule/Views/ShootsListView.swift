//
//  ShootsListView.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct ShootsListView: View {
    let shoots: [Shoot]
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedShoot: Shoot? = nil
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(shoots) { shoot in
                    Button(action: {
                        selectedShoot = shoot
                    }) {
                        ShootRowView(shoot: shoot)
                            .background(Color(red: 1.0, green: 0.992, blue: 0.973))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .padding(.leading)
                }
            }
        }
        .sheet(item: $selectedShoot) { shoot in
            ShootDetailView(shoot: shoot)
                .background(Color(red: 1.0, green: 0.992, blue: 0.973))
        }
    }
}

struct ShootsListView_Previews: PreviewProvider {
    static var previews: some View {
        ShootsListView(shoots: DataManager().shoots)
            .environmentObject(DataManager())
    }
}