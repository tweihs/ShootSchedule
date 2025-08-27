//
//  ShootTagsView.swift
//  ShootSchedule
//
//  Created on 8/26/25.
//

import SwiftUI

struct ShootTagsView: View {
    let shoot: Shoot
    let style: TagStyle
    
    enum TagStyle {
        case compact  // For list view
        case detailed // For detail view
        
        var fontSize: CGFloat {
            switch self {
            case .compact: return 10
            case .detailed: return 11
            }
        }
        
        var paddingHorizontal: CGFloat {
            switch self {
            case .compact: return 6
            case .detailed: return 8
            }
        }
        
        var paddingVertical: CGFloat {
            switch self {
            case .compact: return 2
            case .detailed: return 3
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .compact: return 8
            case .detailed: return 10
            }
        }
        
        var spacing: CGFloat {
            switch self {
            case .compact: return 4
            case .detailed: return 6
            }
        }
    }
    
    var body: some View {
        HStack(spacing: style.spacing) {
            // Notability Tag
            if shoot.notabilityLevel != .none {
                TagPill(
                    text: notabilityDisplayText(for: shoot.notabilityLevel),
                    style: style,
                    color: .secondary
                )
            }
            
            // Duration Tag
            TagPill(
                text: shoot.durationText,
                style: style,
                color: .secondary
            )
            
            // Weather Tag (if available)
            if let temperatureDisplay = shoot.temperatureDisplay {
                TagPill(
                    text: temperatureDisplay,
                    style: style,
                    color: .blue
                )
            }
            
            Spacer()
        }
    }
    
    private func notabilityDisplayText(for level: ShootNotabilityLevel) -> String {
        switch level {
        case .world:
            return "World"
        case .state:
            return "State"
        case .other:
            return "Regional"
        case .none:
            return ""
        }
    }
    
}

struct TagPill: View {
    let text: String
    let style: ShootTagsView.TagStyle
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: style.fontSize, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, style.paddingHorizontal)
            .padding(.vertical, style.paddingVertical)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Previews
struct ShootTagsView_Previews: PreviewProvider {
    static let sampleShoot = Shoot(
        id: 1,
        shootName: "WESTERN REGIONAL 2025",
        shootType: "State",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 2), // 3 days
        clubName: "ROCK CREEK RANCH",
        address1: nil,
        address2: nil,
        city: "EMMETT",
        state: "ID",
        zip: nil,
        country: "USA",
        zone: nil,
        clubEmail: nil,
        pocName: nil,
        pocPhone: nil,
        pocEmail: nil,
        clubID: nil,
        eventType: "NSCA",
        region: "Western",
        fullAddress: "EMMETT, ID, USA",
        latitude: 43.8735,
        longitude: -116.5012,
        notabilityLevelRaw: 2, // State level
        morningTempF: 45,
        afternoonTempF: 72,
        morningTempC: 7,
        afternoonTempC: 22,
        durationDays: 3,
        morningTempBand: "Cool",
        afternoonTempBand: "Comfortable", 
        estimationMethod: "historical",
        isMarked: false
    )
    
    static var previews: some View {
        VStack(spacing: 20) {
            ShootTagsView(shoot: sampleShoot, style: .compact)
                .padding()
                .background(Color.gray.opacity(0.1))
            
            ShootTagsView(shoot: sampleShoot, style: .detailed)
                .padding()
                .background(Color.gray.opacity(0.1))
        }
        .previewLayout(.sizeThatFits)
    }
}