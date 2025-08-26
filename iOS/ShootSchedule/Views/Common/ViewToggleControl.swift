//
//  ViewToggleControl.swift
//  ShootSchedule
//
//  Created on 1/24/25.
//

import SwiftUI

enum ViewMode: String, CaseIterable {
    case list = "List"
    case map = "Map"
    
    var iconName: String {
        switch self {
        case .list:
            return "list.bullet"
        case .map:
            return "map"
        }
    }
}

struct ViewToggleControl: View {
    @Binding var selectedMode: ViewMode
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    selectedMode = mode
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(mode.rawValue)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(selectedMode == mode ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedMode == mode ? Color.blue : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
    }
}

// MARK: - Previews
struct ViewToggleControl_Previews: PreviewProvider {
    @State static var selectedMode: ViewMode = .list
    
    static var previews: some View {
        ViewToggleControl(selectedMode: $selectedMode)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}