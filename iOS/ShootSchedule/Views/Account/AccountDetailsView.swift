//
//  AccountDetailsView.swift
//  ShootSchedule
//
//  Created on 1/24/25.
//

import SwiftUI
import CoreLocation
import EventKit
import UIKit

struct AccountDetailsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @State private var calendarPermissionStatus: EKAuthorizationStatus = .notDetermined
    @State private var useFahrenheit: Bool = true
    @State private var isCalendarSyncEnabled: Bool = false
    @State private var permissionCheckTimer: Timer?
    @State private var showingPermissionAlert = false
    @State private var permissionAlertType: PermissionType = .calendar
    @State private var showingCalendarSourceSelection = false
    @State private var availableCalendarSources: [(id: String, title: String, type: String)] = []
    @State private var currentCalendarInfo: (name: String, source: String)? = nil
    private let locationManager = CLLocationManager()
    private let eventStore = EKEventStore()
    
    enum PermissionType {
        case location, calendar
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // User Avatar Section
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("User Preferences")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Settings and permissions")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Preferences")
                        
                        VStack(spacing: 12) {
                            // Temperature Unit Setting
                            HStack {
                                Image(systemName: "thermometer")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Temperature Unit")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text("Display temperatures in Fahrenheit or Celsius")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Text("°F")
                                        .font(.system(size: 14, weight: useFahrenheit ? .semibold : .regular))
                                        .foregroundColor(useFahrenheit ? .blue : .secondary)
                                    
                                    Toggle("", isOn: Binding(
                                        get: { !useFahrenheit },
                                        set: { useFahrenheit = !$0 }
                                    ))
                                    .labelsHidden()
                                    .scaleEffect(0.8)
                                    
                                    Text("°C")
                                        .font(.system(size: 14, weight: !useFahrenheit ? .semibold : .regular))
                                        .foregroundColor(!useFahrenheit ? .blue : .secondary)
                                }
                            }
                            
                            Divider()
                            
                            // Calendar Sync Setting
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Calendar Sync")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text("Sync marked shoots to your calendar")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $isCalendarSyncEnabled)
                                    .labelsHidden()
                                    .scaleEffect(0.8)
                                    .onChange(of: isCalendarSyncEnabled) { newValue in
                                        handleCalendarSyncToggle(newValue)
                                    }
                            }
                            
                            // Calendar destination row (only show when sync is enabled)
                            if isCalendarSyncEnabled {
                                Divider()
                                
                                Button(action: {
                                    availableCalendarSources = dataManager.getCalendarSourcesForUserSelection()
                                    showingCalendarSourceSelection = true
                                }) {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 16))
                                            .foregroundColor(.blue)
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Sync Destination")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.primary)
                                            
                                            if let calendarInfo = currentCalendarInfo {
                                                Text("Events saved to: \(calendarInfo.source)")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            } else {
                                                Text("Choose which calendar to use")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Calendar cleanup button
                                Divider()
                                
                                Button(action: {
                                    Task {
                                        print("📅 🧹 Manual deduplication initiated by user")
                                        await dataManager.deduplicateEvents()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.2.squarepath")
                                            .font(.system(size: 16))
                                            .foregroundColor(.orange)
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Clean Up Duplicates")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.primary)
                                            
                                            Text("Remove duplicate calendar events")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Permissions Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Permissions")
                        
                        VStack(spacing: 12) {
                            PermissionRow(
                                icon: "location",
                                label: "Location",
                                status: locationPermissionStatus,
                                description: "Used to find nearby shooting events",
                                onRequestPermission: {
                                    requestLocationPermission()
                                }
                            )
                            
                            Divider()
                            
                            PermissionRow(
                                icon: "calendar",
                                label: "Calendar",
                                status: calendarPermissionStatus,
                                description: "Add shoot dates to your calendar",
                                onRequestPermission: {
                                    requestCalendarPermission()
                                }
                            )
                        }
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .onAppear {
                updatePermissionStatuses()
                loadTemperaturePreference()
                // Update calendar permission status in DataManager
                dataManager.checkCalendarPermission()
                // Load calendar sync preference
                isCalendarSyncEnabled = dataManager.isCalendarSyncEnabled
                // Load current calendar info
                currentCalendarInfo = dataManager.getCurrentCalendarInfo()
                
                // Debug available calendars when settings view appears
                // Use background queue to avoid blocking UI
                DispatchQueue.global(qos: .utility).async {
                    print("📅 🔍 AccountDetailsView appeared - debugging calendars...")
                    dataManager.debugAvailableCalendars()
                    
                    // Also check for duplicate events and deduplicate them
                    Task {
                        await dataManager.detectAndLogDuplicateEvents()
                    }
                }
                
                // Start periodic permission check
                permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    updatePermissionStatuses()
                    dataManager.checkCalendarPermission()
                    // Update calendar info periodically
                    currentCalendarInfo = dataManager.getCurrentCalendarInfo()
                }
            }
            .onDisappear {
                // Stop the timer when view disappears
                permissionCheckTimer?.invalidate()
                permissionCheckTimer = nil
            }
            .onChange(of: useFahrenheit) { newValue in
                saveTemperaturePreference(newValue)
            }
            .onChange(of: dataManager.isCalendarSyncEnabled) { newValue in
                isCalendarSyncEnabled = newValue
            }
            .onChange(of: dataManager.hasCalendarPermission) { _ in
                // Update permission status when it changes
                updatePermissionStatuses()
            }
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    if UIApplication.shared.canOpenURL(settingsUrl) {
                        UIApplication.shared.open(settingsUrl, completionHandler: { success in
                            print("Settings opened: \(success)")
                        })
                    }
                }
            } message: {
                switch permissionAlertType {
                case .calendar:
                    Text("Calendar access has been disabled for ShootSchedule. Please go to Settings > ShootSchedule and enable Calendar access to sync your marked shoots.")
                case .location:
                    Text("Location access has been disabled for ShootSchedule. Please go to Settings > ShootSchedule and enable Location access to find nearby shoots.")
                }
            }
            .sheet(isPresented: $showingCalendarSourceSelection) {
                CalendarSourceSelectionView(
                    availableSources: availableCalendarSources,
                    onSourceSelected: { sourceId in
                        handleCalendarSourceSelection(sourceId)
                    }
                )
            }
        }
    }
    
    private func updatePermissionStatuses() {
        // Update location permission status
        locationPermissionStatus = CLLocationManager().authorizationStatus
        
        // Update calendar permission status
        if #available(iOS 17.0, *) {
            calendarPermissionStatus = EKEventStore.authorizationStatus(for: .event)
            // Check if we have full access which is what we need
            if calendarPermissionStatus == .fullAccess {
                // Good - we have the permission we need
            }
        } else {
            calendarPermissionStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }
    
    private func requestLocationPermission() {
        let currentStatus = CLLocationManager().authorizationStatus
        
        if currentStatus == .denied || currentStatus == .restricted {
            // Permission was previously denied, need to go to Settings
            permissionAlertType = .location
            showingPermissionAlert = true
        } else {
            // Can request permission
            locationManager.requestWhenInUseAuthorization()
            // Update status after a brief delay to allow the system dialog to process
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                updatePermissionStatuses()
            }
        }
    }
    
    private func requestCalendarPermission() {
        // Check if permission is already denied
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        
        if currentStatus == .denied || currentStatus == .restricted {
            // Permission was previously denied, need to go to Settings
            permissionAlertType = .calendar
            showingPermissionAlert = true
        } else {
            // Can request permission
            Task {
                let granted = await dataManager.requestCalendarPermission()
                await MainActor.run {
                    updatePermissionStatuses()
                    // Also update DataManager's permission status
                    dataManager.checkCalendarPermission()
                    
                    // If permission was granted, automatically enable sync
                    if granted {
                        dataManager.setCalendarSyncEnabled(true)
                        isCalendarSyncEnabled = true
                        
                        // Sync existing marked shoots
                        let markedShoots = dataManager.shoots.filter { $0.isMarked }
                        Task {
                            await dataManager.syncAllMarkedShoots(markedShoots)
                        }
                    }
                }
            }
        }
    }
    
    private func loadTemperaturePreference() {
        useFahrenheit = UserDefaults.standard.object(forKey: "useFahrenheit") != nil 
            ? UserDefaults.standard.bool(forKey: "useFahrenheit")
            : true
    }
    
    private func saveTemperaturePreference(_ fahrenheit: Bool) {
        UserDefaults.standard.set(fahrenheit, forKey: "useFahrenheit")
        UserDefaults.standard.synchronize()
    }
    
    private func handleCalendarSyncToggle(_ newValue: Bool) {
        print("📅 Toggle changed to: \(newValue), hasPermission: \(dataManager.hasCalendarPermission)")
        
        if newValue {
            // Turning ON calendar sync
            if !dataManager.hasCalendarPermission {
                // Check if permission is denied
                let currentStatus = EKEventStore.authorizationStatus(for: .event)
                
                if currentStatus == .denied || currentStatus == .restricted {
                    // Permission was previously denied, need to go to Settings
                    permissionAlertType = .calendar
                    showingPermissionAlert = true
                    // Revert toggle
                    isCalendarSyncEnabled = false
                } else {
                    // Can request permission
                    Task {
                        let granted = await dataManager.requestCalendarPermission()
                        if granted {
                            await enableCalendarSync()
                        } else {
                            // Permission denied, revert toggle
                            await MainActor.run {
                                isCalendarSyncEnabled = false
                            }
                        }
                    }
                }
            } else {
                // Already have permission, enable sync (may need source selection)
                Task {
                    await enableCalendarSync()
                }
            }
        } else {
            // Turning OFF calendar sync
            dataManager.setCalendarSyncEnabled(false)
            // Remove all events
            Task {
                await dataManager.removeAllShootEvents()
            }
        }
    }
    
    private func enableCalendarSync() async {
        // Check if we need calendar source selection
        let availableSources = dataManager.getCalendarSourcesForUserSelection()
        
        if availableSources.count > 1 && !UserDefaults.standard.bool(forKey: "hasSelectedCalendarSource") {
            // Multiple sources available and user hasn't selected one yet
            await MainActor.run {
                availableCalendarSources = availableSources
                showingCalendarSourceSelection = true
                // Don't enable sync yet - wait for user selection
                isCalendarSyncEnabled = false
            }
        } else {
            // Single source or user has already selected - proceed with sync
            await MainActor.run {
                dataManager.setCalendarSyncEnabled(true)
                isCalendarSyncEnabled = true
            }
            
            // Sync existing marked shoots
            let markedShoots = dataManager.shoots.filter { $0.isMarked }
            await dataManager.syncAllMarkedShoots(markedShoots)
        }
    }
    
    private func handleCalendarSourceSelection(_ sourceId: String) {
        Task {
            let success = await dataManager.selectCalendarSource(sourceId: sourceId)
            
            await MainActor.run {
                showingCalendarSourceSelection = false
                
                if success {
                    // Mark that user has selected a source
                    UserDefaults.standard.set(true, forKey: "hasSelectedCalendarSource")
                    
                    // Enable sync now that source is selected (if it wasn't already)
                    if !isCalendarSyncEnabled {
                        dataManager.setCalendarSyncEnabled(true)
                        isCalendarSyncEnabled = true
                    }
                    
                    // Update calendar info display
                    currentCalendarInfo = dataManager.getCurrentCalendarInfo()
                    
                    // Sync existing marked shoots to the new calendar
                    Task {
                        let markedShoots = dataManager.shoots.filter { $0.isMarked }
                        await dataManager.syncAllMarkedShoots(markedShoots)
                    }
                } else {
                    // Failed to create calendar in selected source
                    if !dataManager.isCalendarSyncEnabled {
                        isCalendarSyncEnabled = false
                    }
                }
            }
        }
    }
    
}

// MARK: - Supporting Components
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
            .padding(.horizontal)
            .padding(.bottom, 8)
    }
}

struct PermissionRow: View {
    let icon: String
    let label: String
    let status: Any // Can be CLAuthorizationStatus or EKAuthorizationStatus
    let description: String
    let onRequestPermission: () -> Void
    
    var statusText: String {
        if let locationStatus = status as? CLAuthorizationStatus {
            switch locationStatus {
            case .notDetermined:
                return "Not requested"
            case .denied, .restricted:
                return "Disabled"
            case .authorizedWhenInUse, .authorizedAlways:
                return "Enabled"
            @unknown default:
                return "Unknown"
            }
        } else if let calendarStatus = status as? EKAuthorizationStatus {
            switch calendarStatus {
            case .notDetermined:
                return "Not requested"
            case .denied, .restricted:
                return "Disabled"
            case .authorized:
                return "Enabled"
            case .writeOnly:
                return "Write only"
            case .fullAccess:
                return "Enabled"
            @unknown default:
                return "Unknown"
            }
        }
        return "Unknown"
    }
    
    var statusColor: Color {
        if let locationStatus = status as? CLAuthorizationStatus {
            switch locationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                return .green
            case .denied, .restricted:
                return .red
            default:
                return .orange
            }
        } else if let calendarStatus = status as? EKAuthorizationStatus {
            switch calendarStatus {
            case .authorized, .writeOnly, .fullAccess:
                return .green
            case .denied, .restricted:
                return .red
            default:
                return .orange
            }
        }
        return .gray
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if shouldShowEnableButton {
                Button("Enable") {
                    onRequestPermission()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(6)
            } else {
                Text(statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusColor)
            }
        }
    }
    
    var shouldShowEnableButton: Bool {
        if let locationStatus = status as? CLAuthorizationStatus {
            return locationStatus == .notDetermined || locationStatus == .denied || locationStatus == .restricted
        } else if let calendarStatus = status as? EKAuthorizationStatus {
            return calendarStatus == .notDetermined || calendarStatus == .denied || calendarStatus == .restricted
        }
        return false
    }
    
    var isNotDetermined: Bool {
        if let locationStatus = status as? CLAuthorizationStatus {
            return locationStatus == .notDetermined
        } else if let calendarStatus = status as? EKAuthorizationStatus {
            return calendarStatus == .notDetermined
        }
        return false
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Calendar Source Selection View
struct CalendarSourceSelectionView: View {
    let availableSources: [(id: String, title: String, type: String)]
    let onSourceSelected: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose Calendar")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Select which calendar to use for your marked shoots. We'll add events to the calendar you choose. Writable calendars are shown first.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)
                .padding(.top)
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(availableSources, id: \.id) { source in
                            CalendarSourceRow(
                                title: source.title,
                                type: source.type,
                                onTap: {
                                    onSourceSelected(source.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
        .background(Color(red: 1.0, green: 0.992, blue: 0.973))
    }
}

struct CalendarSourceRow: View {
    let title: String
    let type: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(type)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(red: 1.0, green: 0.992, blue: 0.973))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews
struct AccountDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AccountDetailsView()
                .environmentObject({
                    let authManager = AuthenticationManager()
                    authManager.currentUser = User(
                        id: "123",
                        email: "john.doe@example.com",
                        displayName: "John Doe"
                    )
                    return authManager
                }())
                .previewDisplayName("With Full Name")
            
            AccountDetailsView()
                .environmentObject({
                    let authManager = AuthenticationManager()
                    authManager.currentUser = User(
                        id: "456",
                        email: "jane@example.com",
                        displayName: nil
                    )
                    return authManager
                }())
                .previewDisplayName("Email Only")
        }
    }
}