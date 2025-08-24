//
//  EventTableView.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/7/24.
//

import SwiftUI

struct EventTableView: View {
    var events: [Event]

    var body: some View {
        List {
            ForEach(groupedEvents, id: \.key) { group in
                Section(header: Text(group.key)) {
                    eventRows(for: group.value)
                }
            }
        }
        .listStyle(.plain)
    }

    // Break up the grouping logic
    private var groupedEvents: [(key: String, value: [Event])] {
        events.groupedByMonthArray()
    }

    // Helper to generate event rows
    @ViewBuilder
    private func eventRows(for events: [Event]) -> some View {
        ForEach(events) { event in
            NavigationLink(destination: ShootDetailView(event: event)) {
                EventRowView(
                    shootName: event.name ?? "No Name",
                    clubName: event.club ?? "No Club",
                    startDate: event.formattedStartDate,
                    endDate: event.formattedEndDate,
                    city: event.city ?? "No City",
                    state: event.state ?? "No State"
                )
            }
        }
    }
}

#Preview {
    EventTableView(events: sampleEvents)
}
