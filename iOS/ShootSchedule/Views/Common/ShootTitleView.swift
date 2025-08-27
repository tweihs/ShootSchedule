//
//  ShootTitleView.swift
//  ShootSchedule
//
//  Created on 1/25/25.
//

import SwiftUI

struct ShootTitleView: View {
    let shoot: Shoot
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let textCase: TextCase
    let starSize: CGFloat
    
    enum TextCase {
        case normal
        case uppercase
    }
    
    init(
        shoot: Shoot, 
        fontSize: CGFloat = 15, 
        fontWeight: Font.Weight = .medium,
        textCase: TextCase = .normal,
        starSize: CGFloat? = nil
    ) {
        self.shoot = shoot
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.textCase = textCase
        self.starSize = starSize ?? fontSize * 0.8
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Star icon for notable shoots
            if shoot.notabilityLevel != .none {
                Image(systemName: shoot.notabilityLevel.starIcon)
                    .font(.system(size: starSize))
                    .foregroundColor(shoot.notabilityLevel.starColor)
            }
            
            // Event type and shoot name
            if let eventType = shoot.eventType, !eventType.isEmpty {
                Text(formatText(eventType))
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundColor(.primary)
                
                Text(formatText(shoot.shootName))
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundColor(.primary)
            } else {
                Text(formatText(shoot.shootName))
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundColor(.primary)
            }
        }
    }
    
    private func formatText(_ text: String) -> String {
        switch textCase {
        case .normal:
            return text
        case .uppercase:
            return text.uppercased()
        }
    }
}

// MARK: - Convenience initializers
extension ShootTitleView {
    static func forList(shoot: Shoot) -> ShootTitleView {
        ShootTitleView(
            shoot: shoot,
            fontSize: 15,
            fontWeight: .medium,
            textCase: .normal,
            starSize: 12
        )
    }
    
    static func forDetail(shoot: Shoot) -> ShootTitleView {
        ShootTitleView(
            shoot: shoot,
            fontSize: 16,
            fontWeight: .bold,
            textCase: .uppercase,
            starSize: 14
        )
    }
}

// MARK: - Previews
struct ShootTitleView_Previews: PreviewProvider {
    static let worldShoot = Shoot(
        id: 1, shootName: "World Championship", shootType: "World Championship",
        startDate: Date(), endDate: nil, clubName: "Test Club", address1: nil, address2: nil,
        city: "Test City", state: "TX", zip: nil, country: "USA", zone: nil,
        clubEmail: nil, pocName: nil, pocPhone: nil, pocEmail: nil, clubID: nil,
        eventType: "NSCA", region: nil, fullAddress: nil, latitude: nil, longitude: nil,
        notabilityLevelRaw: nil, morningTempF: nil, afternoonTempF: nil, morningTempC: nil,
        afternoonTempC: nil, durationDays: nil, morningTempBand: nil, afternoonTempBand: nil,
        estimationMethod: nil, isMarked: false
    )
    
    static let stateShoot = Shoot(
        id: 2, shootName: "Championship", shootType: "State Championship",
        startDate: Date(), endDate: nil, clubName: "Test Club", address1: nil, address2: nil,
        city: "Test City", state: "TX", zip: nil, country: "USA", zone: nil,
        clubEmail: nil, pocName: nil, pocPhone: nil, pocEmail: nil, clubID: nil,
        eventType: "NSSA", region: nil, fullAddress: nil, latitude: nil, longitude: nil,
        notabilityLevelRaw: nil, morningTempF: nil, afternoonTempF: nil, morningTempC: nil,
        afternoonTempC: nil, durationDays: nil, morningTempBand: nil, afternoonTempBand: nil,
        estimationMethod: nil, isMarked: false
    )
    
    static let regularShoot = Shoot(
        id: 3, shootName: "Monthly Shoot", shootType: nil,
        startDate: Date(), endDate: nil, clubName: "Test Club", address1: nil, address2: nil,
        city: "Test City", state: "TX", zip: nil, country: "USA", zone: nil,
        clubEmail: nil, pocName: nil, pocPhone: nil, pocEmail: nil, clubID: nil,
        eventType: "ATA", region: nil, fullAddress: nil, latitude: nil, longitude: nil,
        notabilityLevelRaw: nil, morningTempF: nil, afternoonTempF: nil, morningTempC: nil,
        afternoonTempC: nil, durationDays: nil, morningTempBand: nil, afternoonTempBand: nil,
        estimationMethod: nil, isMarked: false
    )
    
    static var previews: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShootTitleView.forList(shoot: worldShoot)
            ShootTitleView.forList(shoot: stateShoot) 
            ShootTitleView.forList(shoot: regularShoot)
            
            Divider()
            
            ShootTitleView.forDetail(shoot: worldShoot)
            ShootTitleView.forDetail(shoot: stateShoot)
            ShootTitleView.forDetail(shoot: regularShoot)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}