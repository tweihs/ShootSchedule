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
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(shoots) { shoot in
                    ShootRowView(shoot: shoot)
                        .background(Color(UIColor.systemBackground))
                    
                    Divider()
                        .padding(.leading)
                }
            }
        }
    }
}

struct ShootsListView_Previews: PreviewProvider {
    static var previews: some View {
        ShootsListView(shoots: DataManager().shoots)
            .environmentObject(DataManager())
    }
}