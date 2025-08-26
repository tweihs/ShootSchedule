//
//  StatePicker.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct StatePicker: View {
    @Binding var selectedStates: Set<String>
    @Environment(\.dismiss) var dismiss
    
    let states = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
    ]
    
    let zones: [String: [String]] = [
        "West": ["CA", "AZ", "NM", "WA", "MT", "ID", "UT", "NV", "CO", "WY", "OR"],
        "South Central": ["TX", "OK", "AR", "LA", "MS"],
        "North Central": ["ND", "SD", "NE", "KS", "MN", "IA", "IL", "MI", "IN", "KY", "WI", "MO"],
        "Southeast": ["TN", "NC", "SC", "GA", "AL", "FL"],
        "Northeast": ["OH", "PA", "WV", "VA", "MD", "NJ", "DE", "CT", "NY", "VT", "NH", "MA", "RI"]
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Zones Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zones")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        StateFlowLayout(spacing: 8) {
                            ForEach(Array(zones.keys.sorted()), id: \.self) { zone in
                                ZoneButton(
                                    zone: zone,
                                    isSelected: isZoneSelected(zone)
                                ) {
                                    selectZone(zone)
                                }
                            }
                        }
                    }
                    
                    // States Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("States")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        StateFlowLayout(spacing: 8) {
                            ForEach(states, id: \.self) { state in
                                StateButton(
                                    state: state,
                                    isSelected: selectedStates.contains(state)
                                ) {
                                    if selectedStates.contains(state) {
                                        selectedStates.remove(state)
                                    } else {
                                        selectedStates.insert(state)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("State")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Helper functions for zone selection
    private func isZoneSelected(_ zone: String) -> Bool {
        guard let zoneStates = zones[zone] else { return false }
        return Set(zoneStates).isSubset(of: selectedStates)
    }
    
    private func selectZone(_ zone: String) {
        guard let zoneStates = zones[zone] else { return }
        let zoneStatesSet = Set(zoneStates)
        
        if zoneStatesSet.isSubset(of: selectedStates) {
            // Zone is selected, deselect all states in zone
            selectedStates.subtract(zoneStatesSet)
        } else {
            // Zone is not fully selected, select all states in zone
            selectedStates.formUnion(zoneStatesSet)
        }
    }
}

struct ZoneButton: View {
    let zone: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(zone)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blue, lineWidth: isSelected ? 0 : 1.5)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StateButton: View {
    let state: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(state)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blue, lineWidth: isSelected ? 0 : 1.5)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StateFlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(ProposedViewSize(width: nil, height: nil))
            
            if currentX + subviewSize.width > containerWidth && currentX > 0 {
                currentY += maxHeight + spacing
                currentX = 0
                maxHeight = 0
            }
            
            maxHeight = max(maxHeight, subviewSize.height)
            currentX += subviewSize.width + spacing
        }
        
        return CGSize(width: containerWidth, height: currentY + maxHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(ProposedViewSize(width: nil, height: nil))
            
            if currentX + subviewSize.width > bounds.maxX && currentX > bounds.minX {
                currentY += maxHeight + spacing
                currentX = bounds.minX
                maxHeight = 0
            }
            
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(subviewSize))
            maxHeight = max(maxHeight, subviewSize.height)
            currentX += subviewSize.width + spacing
        }
    }
}

struct StatePicker_Previews: PreviewProvider {
    @State static var selectedStates = Set<String>()
    
    static var previews: some View {
        StatePicker(selectedStates: $selectedStates)
    }
}