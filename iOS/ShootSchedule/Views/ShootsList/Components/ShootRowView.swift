//
//  ShootRowView.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI
import Foundation

struct ShootRowView: View {
    let shoot: Shoot
    @EnvironmentObject var dataManager: DataManager
    @State private var isMarked: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Event Type and Name
                Text(shoot.displayLabel)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                
                
                // Club Name
                Text(shoot.clubName)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                // Location
                Text(shoot.locationString.uppercased())
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                
                // Tags Row
                HStack(spacing: 4) {
                    // Notability Tag
                    if shoot.notabilityLevel != .none {
                        Text(notabilityDisplayText(for: shoot.notabilityLevel))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                            )
                    }
                    
                    // Duration Tag
                    Text(shoot.durationText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                        )
                    
                    // Weather Tag (if available)
                    if let temperatureDisplay = shoot.temperatureDisplay {
                        Text(temperatureDisplay)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                            )
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                // Date
                VStack(alignment: .trailing, spacing: 2) {
                    Text(shoot.userFriendlyDate)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.trailing)
                }
                
                // Mark Button
                Button(action: {
                    toggleMark()
                }) {
                    if isMarked {
                        // Marked state - just checkmark with blue background
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                            )
                    } else {
                        // Unmarked state - "Mark" text with border
                        Text("Mark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 70, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue, lineWidth: 1.5)
                            )
                    }
                }
            }
        }
        .padding()
        .onAppear {
            isMarked = dataManager.isShootMarked(shoot)
        }
    }
    
    private func toggleMark() {
        if isMarked {
            dataManager.unmarkShoot(shoot)
        } else {
            dataManager.markShoot(shoot)
        }
        isMarked.toggle()
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


struct ShootRowView_Previews: PreviewProvider {
    static let sampleShoot = Shoot(
        id: 1,
        shootName: "WESTERN REGIONAL 2025",
        shootType: "Regional",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 3),
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
        fullAddress: nil,
        latitude: 43.8735,
        longitude: -116.4993,
        notabilityLevelRaw: nil,
        morningTempF: 48,
        afternoonTempF: 75,
        morningTempC: 9,
        afternoonTempC: 24,
        durationDays: 4,
        morningTempBand: nil,
        afternoonTempBand: nil,
        estimationMethod: nil,
        isMarked: false
    )
    
    static var previews: some View {
        ShootRowView(shoot: sampleShoot)
            .environmentObject(DataManager())
            .previewLayout(.sizeThatFits)
    }
}
