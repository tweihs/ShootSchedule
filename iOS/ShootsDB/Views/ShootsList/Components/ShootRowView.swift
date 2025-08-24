//
//  ShootRowView.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct ShootRowView: View {
    let shoot: Shoot
    @EnvironmentObject var dataManager: DataManager
    @State private var isMarked: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Event Type and Name
                Text(shoot.eventType + " " + shoot.shootName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Club Name
                Text(shoot.clubName)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                // Location
                Text(shoot.locationString.uppercased())
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                // Date
                Text(shoot.displayDate)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                // Mark Button
                Button(action: {
                    toggleMark()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isMarked ? "checkmark" : "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Mark")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                    )
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
        isMarked: false
    )
    
    static var previews: some View {
        ShootRowView(shoot: sampleShoot)
            .environmentObject(DataManager())
            .previewLayout(.sizeThatFits)
    }
}