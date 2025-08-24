//
//  ContentView.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var filterOptions = FilterOptions()
    @State private var searchText = ""
    @State private var showingFilters = false
    
    var filteredShoots: [Shoot] {
        filterOptions.apply(to: dataManager.shoots)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HeaderView()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Search Bar
                SearchBar(text: $filterOptions.searchText)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                // Filter Pills
                FilterPillsView(filterOptions: filterOptions)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                // Toggle Controls
                ToggleControlsView(filterOptions: filterOptions)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                Divider()
                
                // Shoots List
                if filteredShoots.isEmpty {
                    EmptyStateView()
                } else {
                    ShootsListView(shoots: filteredShoots)
                }
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No shoots found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your filters or search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthenticationManager())
            .environmentObject(DataManager())
    }
}