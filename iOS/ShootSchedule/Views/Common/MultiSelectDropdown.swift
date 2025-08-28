//
//  MultiSelectDropdown.swift
//  ShootSchedule
//
//  Created on 1/24/25.
//

import SwiftUI

struct MultiSelectDropdown: View {
    let title: String
    let options: [String]
    @Binding var selectedItems: Set<String>
    @State private var isExpanded = false
    
    var displayText: String {
        if selectedItems.isEmpty {
            return title
        } else {
            return "\(title) (\(selectedItems.count))"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with dropdown button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(displayText)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondaryBackground.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(UIColor.separator), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Selected items pills
            if !selectedItems.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 60), spacing: 6)
                ], spacing: 6) {
                    ForEach(Array(selectedItems).sorted(), id: \.self) { item in
                        SelectedPill(text: item) {
                            removeItem(item)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            
            // Dropdown options
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            toggleSelection(option)
                        }) {
                            HStack {
                                Text(option)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedItems.contains(option) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemBackground))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if option != options.last {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondaryBackground.opacity(0.9))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
    }
    
    private func toggleSelection(_ item: String) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    private func removeItem(_ item: String) {
        selectedItems.remove(item)
    }
}

struct SelectedPill: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.15))
        )
    }
}

// MARK: - Month Dropdown Variant
struct MonthMultiSelectDropdown: View {
    @Binding var selectedMonths: Set<Int>
    @State private var isExpanded = false
    
    let monthNames = [
        1: "January", 2: "February", 3: "March", 4: "April",
        5: "May", 6: "June", 7: "July", 8: "August",
        9: "September", 10: "October", 11: "November", 12: "December"
    ]
    
    var displayText: String {
        if selectedMonths.isEmpty {
            return "Months"
        } else {
            return "Months (\(selectedMonths.count))"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with dropdown button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(displayText)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondaryBackground.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(UIColor.separator), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Selected months pills
            if !selectedMonths.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80), spacing: 6)
                ], spacing: 6) {
                    ForEach(Array(selectedMonths).sorted(), id: \.self) { month in
                        SelectedPill(text: monthNames[month] ?? "") {
                            selectedMonths.remove(month)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            
            // Dropdown options
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(1...12, id: \.self) { month in
                        Button(action: {
                            if selectedMonths.contains(month) {
                                selectedMonths.remove(month)
                            } else {
                                selectedMonths.insert(month)
                            }
                        }) {
                            HStack {
                                Text(monthNames[month] ?? "")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedMonths.contains(month) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemBackground))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if month != 12 {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondaryBackground.opacity(0.9))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
    }
}

// MARK: - Previews
struct MultiSelectDropdown_Previews: PreviewProvider {
    @State static var selectedStates = Set<String>(["CA", "TX", "NY"])
    @State static var selectedMonths = Set<Int>([1, 6, 12])
    
    static var previews: some View {
        VStack(spacing: 20) {
            MultiSelectDropdown(
                title: "States",
                options: ["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA"],
                selectedItems: $selectedStates
            )
            
            MonthMultiSelectDropdown(selectedMonths: $selectedMonths)
            
            Spacer()
        }
        .padding()
        .background(Color.primaryBackground)
        .previewLayout(.sizeThatFits)
    }
}