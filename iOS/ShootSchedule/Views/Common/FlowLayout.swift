//
//  FlowLayout.swift
//  ShootSchedule
//
//  Created on 1/25/25.
//

import SwiftUI

struct FlowLayout: Layout {
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