//
//  ShootsDBApp.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/7/24.
//

import SwiftUI

@main
struct ShootsDBApp: App {
    @State private var shootEvents: [Event] = []

    var body: some Scene {
        WindowGroup {
            MainView(events: shootEvents)
                .onAppear {
                    loadData()
                }
        }
    }

    private func loadData() {
        shootEvents = CSVParser.parseShootEvents(from: "Geocoded_Combined_Shoot_Schedule_2024")
    }
}
