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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(shoots) { shoot in
                        Button(action: {
                            selectedShoot = shoot
                        }) {
                            ShootRowView(shoot: shoot)
                                .background(Color.primaryBackground)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .id(shoot.id) // Explicit ID for ScrollViewReader
                        
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(.easeInOut(duration: 0.2), value: shoots.count) // Smooth animation only when count changes
        .sheet(item: $selectedShoot) { shoot in
            ShootDetailView(shoot: shoot)
                .background(Color.primaryBackground)
        }
    }
}

struct ShootsListView_Previews: PreviewProvider {
    static var previews: some View {
        ShootsListView(shoots: DataManager().shoots)
            .environmentObject(DataManager())
    }
}