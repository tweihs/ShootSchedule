//
//  EventRowView.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/7/24.
//

import SwiftUI

struct EventRowView: View {
    var shootName: String
    var clubName: String
    var startDate: String
    var endDate: String
    var city: String
    var state: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) { // Left-aligned event details
                Text(shootName)
                Text(clubName)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            Spacer() // Push dates and location to the right
            VStack(alignment: .trailing) {
                Text("\(startDate) - \(endDate)")
                    .font(.subheadline)
                Text("\(city), \(state)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct EventRowView_Previews: PreviewProvider {
    static var previews: some View {
        EventRowView(shootName: "Winter Shootout", clubName: "Aspen Skeet Club", startDate: "Dec 10", endDate: "Dec 12", city: "Aspen", state: "CO")
    }
}

