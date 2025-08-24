//
//  MainView.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/7/24.
//

import SwiftUI
import MapKit

struct MainView: View {
    @StateObject private var filterOptions = FilterOptions()
    @State private var isShowingFilter = false
    @State private var searchText = ""
    @State private var selectedView: ViewType = .list

    let allNSCAOptions = ["NSCA", "NSSA"]
    let allMonths = Calendar.current.monthSymbols
    
    let events: [Event]

    // Enum to manage selected view type
    enum ViewType {
        case list
        case map
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 4) {
                // Header with title and profile icon
                HStack {
                    Text("ShootsDB")
                        .font(.title3)
                        .bold()
                    Spacer()
                    Button {
                        // Profile or Account Action
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title)
                    }
                }
                .padding(.horizontal)

                // Search and Filter Bar
                HStack {
                    TextField("Search Events", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button {
                        isShowingFilter = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                    }
                    .padding(.leading, 8)
                }
                .padding(8)

                // Segmented Control
                Picker("View Type", selection: $selectedView) {
                    Text("List").tag(ViewType.list)
                    Text("Map").tag(ViewType.map)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                Divider()

                // Conditional content
                if selectedView == .list {
                    // change this to "events" to load events from CSV
                    EventTableView(events: sampleEvents)
                } else {
                    EventMapView(events: sampleEvents)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingFilter) {
                FilterView(
                    filterOptions: filterOptions,
                    allNSCAOptions: allNSCAOptions,
                    allMonths: allMonths,
                    isPresented: $isShowingFilter
                )
            }
        }
    }
}

//#Preview {
//    MainView()
//}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
//        MainView(events: loadPreviewEvents())
        MainView(events: sampleEvents)
    }

    static func loadPreviewEvents() -> [Event] {
        // Path to the CSV file in the project directory
        let previewFilePath = Bundle.main.path(forResource: "Geocoded_Combined_Shoot_Schedule_2024", ofType: "csv") ?? ""

        guard !previewFilePath.isEmpty else {
            print("Preview CSV file not found.")
            return []
        }

        return CSVParser.parseShootEvents(from: previewFilePath)
    }
}
