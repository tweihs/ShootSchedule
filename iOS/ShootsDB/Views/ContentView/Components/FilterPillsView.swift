//
//  FilterPillsView.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct FilterPillsView: View {
    @ObservedObject var filterOptions: FilterOptions
    @State private var showingTypePicker = false
    @State private var showingMonthPicker = false
    @State private var showingStatePicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Type Filter
            FilterPill(
                title: "Type",
                isActive: !filterOptions.selectedAffiliations.isEmpty,
                action: { showingTypePicker.toggle() }
            )
            .sheet(isPresented: $showingTypePicker) {
                AffiliationPicker(selectedAffiliations: $filterOptions.selectedAffiliations)
            }
            
            // Month Filter
            FilterPill(
                title: "Month",
                isActive: !filterOptions.selectedMonths.isEmpty,
                action: { showingMonthPicker.toggle() }
            )
            .sheet(isPresented: $showingMonthPicker) {
                MonthPicker(selectedMonths: $filterOptions.selectedMonths)
            }
            
            // State Filter
            FilterPill(
                title: "State",
                isActive: !filterOptions.selectedStates.isEmpty,
                action: { showingStatePicker.toggle() }
            )
            .sheet(isPresented: $showingStatePicker) {
                StatePicker(selectedStates: $filterOptions.selectedStates)
            }
            
            Spacer()
        }
    }
}

struct FilterPill: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isActive ? Color.blue.opacity(0.1) : Color.clear)
                    )
            )
            .foregroundColor(isActive ? .blue : .primary)
        }
    }
}

struct FilterPillsView_Previews: PreviewProvider {
    @StateObject static var filterOptions = FilterOptions()
    
    static var previews: some View {
        FilterPillsView(filterOptions: filterOptions)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}