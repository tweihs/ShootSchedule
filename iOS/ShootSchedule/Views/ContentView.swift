//
//  ContentView.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI
import Combine

// TODO: Implement tab view with Events and Clubs tabs
// - Events tab: Current shoot schedule functionality (search bar, filters, list/map view)
// - Clubs tab: New functionality for club management and information
struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var filterOptions = FilterOptions()
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var showingAccountDetails = false
    @State private var selectedViewMode: ViewMode = .list
    @State private var selectedShoot: Shoot? = nil
    @State private var filteredShoots: [Shoot] = []
    @State private var isFiltering = false
    
    private let filterQueue = DispatchQueue(label: "filter-queue", qos: .userInitiated)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Row: Search Bar and Avatar
                HStack(spacing: 12) {
                    SearchBar(text: $filterOptions.searchText)
                    
                    // User Settings Avatar
                    Button(action: {
                        showingAccountDetails = true
                    }) {
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
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                // Filter Pills
                FilterPillsView(filterOptions: filterOptions)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                // Toggle Controls
                ToggleControlsView(filterOptions: filterOptions)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                Divider()
                
                // View Toggle Control
                HStack {
                    ViewToggleControl(selectedMode: $selectedViewMode)
                    Spacer()
                    Text("\(filteredShoots.count) shoots")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
                
                // Content based on selected view mode
                if filteredShoots.isEmpty {
                    EmptyStateView()
                } else {
                    switch selectedViewMode {
                    case .list:
                        ShootsListView(shoots: filteredShoots)
                    case .map:
                        ShootsMapViewContainer(shoots: filteredShoots, selectedShoot: $selectedShoot)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color(red: 1.0, green: 0.992, blue: 0.973))
            .onTapGesture {
                // Dismiss keyboard when tapping outside search area
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onAppear {
                // Set filter options reference for auto-disable functionality
                dataManager.filterOptions = filterOptions
                // Initial filter application
                applyFilters()
            }
            .onReceive(filterOptions.$searchText.debounce(for: .milliseconds(300), scheduler: RunLoop.main)) { _ in
                applyFilters()
            }
            .onReceive(filterOptions.$selectedAffiliations) { _ in
                applyFilters()
            }
            .onReceive(filterOptions.$selectedMonths) { _ in
                applyFilters()
            }
            .onReceive(filterOptions.$selectedStates) { _ in
                applyFilters()
            }
            .onReceive(filterOptions.$showFutureOnly) { _ in
                applyFilters()
            }
            .onReceive(filterOptions.$showNotableOnly) { _ in
                applyFilters()
            }
            .onReceive(filterOptions.$showMarkedOnly) { _ in
                applyFilters()
            }
            .onChange(of: dataManager.shoots) { _ in
                applyFilters()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingAccountDetails) {
            AccountDetailsView()
                .background(Color(red: 1.0, green: 0.992, blue: 0.973))
        }
        .sheet(item: $selectedShoot) { shoot in
            ShootDetailView(shoot: shoot)
                .environmentObject(dataManager)
                .background(Color(red: 1.0, green: 0.992, blue: 0.973))
        }
    }
    
    private func applyFilters() {
        let currentShoots = dataManager.shoots
        let currentFilterOptions = filterOptions
        
        filterQueue.async {
            let filtered = currentFilterOptions.apply(to: currentShoots)
            DispatchQueue.main.async {
                self.filteredShoots = filtered
                self.isFiltering = false
            }
        }
        
        isFiltering = true
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No shoots found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Try adjusting your filters or search terms")
                .font(.system(size: 13))
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