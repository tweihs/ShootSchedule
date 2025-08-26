//
//  AffiliationPicker.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct AffiliationPicker: View {
    @Binding var selectedAffiliations: Set<ShootAffiliation>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    AffiliationFlowLayout(spacing: 8) {
                        ForEach(ShootAffiliation.allCases, id: \.self) { affiliation in
                            AffiliationButton(
                                affiliation: affiliation.displayName,
                                isSelected: selectedAffiliations.contains(affiliation)
                            ) {
                                if selectedAffiliations.contains(affiliation) {
                                    selectedAffiliations.remove(affiliation)
                                } else {
                                    selectedAffiliations.insert(affiliation)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Type")
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
}

struct AffiliationButton: View {
    let affiliation: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(affiliation)
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

struct AffiliationFlowLayout: Layout {
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

struct AffiliationPicker_Previews: PreviewProvider {
    @State static var selectedAffiliations = Set<ShootAffiliation>()
    
    static var previews: some View {
        AffiliationPicker(selectedAffiliations: $selectedAffiliations)
    }
}