//
//  DataManager.swift
//  ShootSchedule
//
//  Created on 1/24/25.
//

import Foundation
import Combine
import EventKit
import UIKit

class DataManager: ObservableObject {
    @Published var shoots: [Shoot] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasCalendarPermission: Bool = false
    @Published var isCalendarSyncEnabled: Bool = false
    
    // Reference to filter optionssho for auto-disabling marked filter
    weak var filterOptions: FilterOptions?
    
    // Reference to authentication manager for sync operations
    weak var authManager: AuthenticationManager?
    
    var markedShootIds: Set<Int> = [] // Made public for UserPreferencesService access
    private let markedShootsKey = "markedShoots"
    let sqliteService = SQLiteService()
    
    // Serial queue for preference syncing to prevent race conditions
    private let preferenceSyncQueue = DispatchQueue(label: "com.shootschedule.preference-sync", qos: .background)
    private var syncWorkItem: DispatchWorkItem?
    private var filterObservers: [AnyCancellable] = []
    
    // Calendar integration
    private let eventStore = EKEventStore()
    private let calendarTitle = "ShootSchedule Events"
    private var shootScheduleCalendar: EKCalendar?
    
    // URL where SQLite database can be downloaded from
    // Production database URL - update this when deploying to cloud storage
    // For S3: https://shootschedule-mobile.s3.amazonaws.com/databases/shoots.sqlite
    // For Firebase: https://storage.googleapis.com/{bucket}/databases/shoots.sqlite
    private let databaseURL = "https://shootschedule-mobile.s3.amazonaws.com/databases/shoots.sqlite"
    
    init() {
        loadMarkedShoots()
        loadShootsFromDatabase()
        // Defer calendar operations until after authentication
        // checkCalendarPermission() - will be called when authenticated
        // loadCalendarSyncPreference() - will be called when authenticated
        setupUserPreferenceSync()
    }
    
    func setupAuthenticatedFeatures() {
        // Call this after user authenticates
        checkCalendarPermission()
        loadCalendarSyncPreference()
        
        // Fetch user preferences from server on initial authentication
        Task {
            // Small delay to ensure shoots are loaded first
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await fetchAndApplyUserPreferences()
        }
        
        // Debug available calendars if we have permission
        if hasCalendarPermission {
            debugAvailableCalendars()
        }
        
        // Also debug after a brief delay in case EventKit needs initialization time
        // Use background queue to avoid blocking UI
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
            if self.hasCalendarPermission {
                print("📅 🔍 DELAYED STARTUP DEBUG:")
                self.debugAvailableCalendars()
            } else {
                print("📅 🔍 DELAYED STARTUP: No calendar permission available")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("userPreferencesLoaded"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("newUserNeedsPreferenceSync"), object: nil)
    }
    
    func loadCachedData() {
        // Load from cache if available
        if let cachedData = UserDefaults.standard.data(forKey: "cachedShoots"),
           let cachedShoots = try? JSONDecoder().decode([Shoot].self, from: cachedData) {
            self.shoots = cachedShoots
        }
    }
    
    func fetchShoots() async {
        isLoading = true
        
        // Try to download latest database
        let success = await sqliteService.downloadLatestDatabase(from: databaseURL)
        
        if success {
            loadShootsFromDatabase()
        } else {
            // Fall back to cached data if download fails
            loadShootsFromDatabase()
        }
        
        isLoading = false
    }
    
    private func loadShootsFromDatabase() {
        let loadedShoots = sqliteService.loadShoots()
        
        // If no shoots loaded from database, fall back to test data
        if loadedShoots.isEmpty {
            loadSampleData()
        } else {
            shoots = loadedShoots
            applyMarkedStatus()
        }
    }
    
    func applyMarkedStatus() {
        // Apply marked status to all shoots
        shoots = shoots.map { shoot in
            var updatedShoot = shoot
            updatedShoot.isMarked = markedShootIds.contains(shoot.id)
            return updatedShoot
        }
        
        let actualMarkedShoots = shoots.filter { $0.isMarked }
        let futureMarkedShoots = actualMarkedShoots.filter { $0.startDate > Date() }
        let pastMarkedShoots = actualMarkedShoots.filter { $0.startDate <= Date() }
        
        print("📊 SHOOTS PROCESSED: Total=\(shoots.count), Marked=\(actualMarkedShoots.count)")
        print("📊 MARKED SHOOTS: \(actualMarkedShoots.count) total (\(futureMarkedShoots.count) future, \(pastMarkedShoots.count) past)")
        print("📊 MARKED SHOOT IDs IN DATA: \(actualMarkedShoots.map { $0.id }.sorted())")
        print("📊 MARKED SHOOT IDs IN STORAGE: \(Array(markedShootIds).sorted())")
        print("📊 With 'Future' filter on, only \(futureMarkedShoots.count) marked shoots will be visible")
        
        // Ensure UI updates with correct count
        objectWillChange.send()
    }
    
    func markShoot(_ shoot: Shoot) {
        markedShootIds.insert(shoot.id)
        saveMarkedShoots()
        
        // Debug: Print marked shoot info
        print("🎯 MARKED SHOOT: ID=\(shoot.id), Name='\(shoot.shootName)', Club='\(shoot.clubName)'")
        print("📋 ALL MARKED SHOOTS: \(Array(markedShootIds).sorted()) (Total: \(markedShootIds.count))")
        
        // Update the shoot in the array
        if let index = shoots.firstIndex(where: { $0.id == shoot.id }) {
            shoots[index].isMarked = true
            
            // Sync to calendar
            if isCalendarSyncEnabled && hasCalendarPermission {
                Task {
                    await syncMarkedShoot(shoots[index])
                }
            }
        }
        
        // Trigger UI update for marked count
        objectWillChange.send()
        
        // Only sync preferences if user is authenticated
        if authManager?.isAuthenticated == true {
            syncPreferencesIfAuthenticated()
        }
    }
    
    func unmarkShoot(_ shoot: Shoot) {
        markedShootIds.remove(shoot.id)
        saveMarkedShoots()
        
        // Debug: Print unmarked shoot info
        print("❌ UNMARKED SHOOT: ID=\(shoot.id), Name='\(shoot.shootName)', Club='\(shoot.clubName)'")
        print("📋 ALL MARKED SHOOTS: \(Array(markedShootIds).sorted()) (Total: \(markedShootIds.count))")
        
        // Update the shoot in the array
        if let index = shoots.firstIndex(where: { $0.id == shoot.id }) {
            shoots[index].isMarked = false
            
            // Remove from calendar
            if hasCalendarPermission {
                Task {
                    await removeMarkedShoot(shoots[index])
                }
            }
        }
        
        // Auto-disable marked filter if no marked shoots remain
        if markedShootIds.isEmpty && filterOptions?.showMarkedOnly == true {
            print("📋 All shoots unmarked, disabling marked filter")
            filterOptions?.showMarkedOnly = false
        }
        
        // Trigger UI update for marked count
        objectWillChange.send()
        
        // Only sync preferences if user is authenticated
        if authManager?.isAuthenticated == true {
            syncPreferencesIfAuthenticated()
        }
    }
    
    func isShootMarked(_ shoot: Shoot) -> Bool {
        return markedShootIds.contains(shoot.id)
    }
    
    var markedShootsCount: Int {
        return markedShootIds.count
    }
    
    private func loadMarkedShoots() {
        let iCloudStore = NSUbiquitousKeyValueStore.default
        var loadedFromPrimary = false
        
        // Try to load from iCloud first
        if let data = iCloudStore.data(forKey: markedShootsKey),
           let ids = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            markedShootIds = ids
            print("☁️ LOADED MARKED SHOOTS FROM ICLOUD: \(Array(markedShootIds).sorted()) (Total: \(markedShootIds.count))")
            loadedFromPrimary = true
        }
        
        // If iCloud failed, try backup UserDefaults
        if !loadedFromPrimary {
            if let data = UserDefaults.standard.data(forKey: "\(markedShootsKey)_backup"),
               let ids = try? JSONDecoder().decode(Set<Int>.self, from: data) {
                markedShootIds = ids
                print("💾 LOADED MARKED SHOOTS FROM BACKUP: \(Array(markedShootIds).sorted()) (Total: \(markedShootIds.count))")
                loadedFromPrimary = true
            }
        }
        
        // If still no data, try legacy UserDefaults for migration
        if !loadedFromPrimary {
            if let data = UserDefaults.standard.data(forKey: markedShootsKey),
               let ids = try? JSONDecoder().decode(Set<Int>.self, from: data) {
                markedShootIds = ids
                print("📱 MIGRATED MARKED SHOOTS FROM LEGACY STORAGE: \(Array(markedShootIds).sorted()) (Total: \(markedShootIds.count))")
                // Save to new format and remove old format
                saveMarkedShoots()
                UserDefaults.standard.removeObject(forKey: markedShootsKey)
                loadedFromPrimary = true
            }
        }
        
        if !loadedFromPrimary {
            print("📱 NO MARKED SHOOTS FOUND IN ANY STORAGE")
        }
        
        // Listen for iCloud sync notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
    }
    
    func saveUserData() {
        print("💾 SAVING ALL USER DATA...")
        saveMarkedShoots()
        
        // Force iCloud synchronization
        NSUbiquitousKeyValueStore.default.synchronize()
        UserDefaults.standard.synchronize()
        print("💾 USER DATA SAVE COMPLETE")
    }
    
    func saveMarkedShoots() {
        if let data = try? JSONEncoder().encode(markedShootIds) {
            // Save to iCloud
            let iCloudStore = NSUbiquitousKeyValueStore.default
            iCloudStore.set(data, forKey: markedShootsKey)
            iCloudStore.synchronize()
            print("☁️ SAVED MARKED SHOOTS TO ICLOUD: \(Array(markedShootIds).sorted()) (Total: \(markedShootIds.count))")
            
            // Also save to UserDefaults as backup
            UserDefaults.standard.set(data, forKey: "\(markedShootsKey)_backup")
            UserDefaults.standard.synchronize()
            print("💾 BACKUP SAVED TO USERDEFAULTS: \(markedShootIds.count) shoots")
            
            // Sync to database if authenticated
            syncPreferencesIfAuthenticated()
        }
    }
    
    @objc private func iCloudStoreDidChange(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        // Check if our key was updated
        if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
           changedKeys.contains(markedShootsKey) {
            
            // Reload marked shoots from iCloud
            let iCloudStore = NSUbiquitousKeyValueStore.default
            if let data = iCloudStore.data(forKey: markedShootsKey),
               let ids = try? JSONDecoder().decode(Set<Int>.self, from: data) {
                
                DispatchQueue.main.async {
                    self.markedShootIds = ids
                    print("☁️ SYNCED MARKED SHOOTS FROM ICLOUD: \(Array(ids).sorted()) (Total: \(ids.count))")
                    
                    // Apply the synced marked status to current shoots
                    self.applyMarkedStatus()
                    
                    // Trigger UI update
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    private func loadSampleData() {
        // Create comprehensive test data for all filters
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let states = [
            "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
            "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
            "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
            "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
            "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
        ]
        
        let clubNames = [
            "ROCK CREEK RANCH",
            "BERETTA SHOOTING GROUNDS",
            "BLACKMORE SHOOTING SPORTS",
            "BIRCHWOOD RECREATION",
            "THE GALT SPORTSMEN'S CLUB",
            "PIEDMONT SPORTSMAN CLUB",
            "DESOTO RIFLE AND PISTOL CLUB",
            "OAKWOOD GUN CLUB",
            "RIVERSIDE SHOOTING CENTER",
            "MOUNTAIN VIEW TRAP CLUB",
            "PRAIRIE WIND SPORTING CLAYS",
            "COASTAL CLAY SPORTS"
        ]
        
        let shootNames = [
            "SPRING CLASSIC",
            "SUMMER CHAMPIONSHIP",
            "FALL FESTIVAL",
            "WINTER WARMUP",
            "STATE CHAMPIONSHIP",
            "REGIONAL QUALIFIER",
            "CLUB CHAMPIONSHIP",
            "MEMORIAL SHOOT",
            "LABOR DAY OPEN",
            "HOLIDAY CLASSIC",
            "NEW YEAR KICKOFF",
            "MARCH MADNESS",
            "APRIL SHOWERS",
            "MAY FLOWERS",
            "JUNE JUBILEE",
            "JULY FIRECRACKER",
            "AUGUST HEAT",
            "SEPTEMBER SHOWDOWN",
            "OCTOBER FEST",
            "NOVEMBER TURKEY",
            "DECEMBER FINALE"
        ]
        
        let eventTypes = ["NSCA", "NSSA", "ATA"]
        let shootTypes = ["State Championship", "Regional", "National", nil, nil, nil]
        
        var allShoots: [Shoot] = []
        var shootId = 1
        
        // Generate shoots for each month (past and future)
        for month in 1...12 {
            // Past year shoot
            let pastDate = formatter.date(from: "2024-\(String(format: "%02d", month))-15")!
            let pastShoot = Shoot(
                id: shootId,
                shootName: shootNames[month - 1],
                shootType: shootTypes.randomElement()!,
                startDate: pastDate,
                endDate: Calendar.current.date(byAdding: .day, value: Int.random(in: 0...3), to: pastDate),
                clubName: clubNames[month % clubNames.count],
                address1: "\(Int.random(in: 100...9999)) Main Street",
                address2: nil,
                city: "City\(month)",
                state: states[(shootId - 1) % states.count],
                zip: String(format: "%05d", Int.random(in: 10000...99999)),
                country: "USA",
                zone: Int.random(in: 1...8),
                clubEmail: "contact@club\(month).com",
                pocName: "John Doe",
                pocPhone: "(555) 555-\(String(format: "%04d", 1000 + month))",
                pocEmail: "john@club\(month).com",
                clubID: month,
                eventType: eventTypes[(shootId - 1) % 3],
                region: ["North", "South", "East", "West"].randomElement(),
                fullAddress: nil,
                latitude: Double.random(in: 25...49),
                longitude: Double.random(in: -125...(-70)),
                notabilityLevelRaw: nil, // Will fallback to computed logic
                morningTempF: nil,
                afternoonTempF: nil,
                morningTempC: nil,
                afternoonTempC: nil,
                durationDays: nil,
                morningTempBand: nil,
                afternoonTempBand: nil,
                estimationMethod: nil,
                isMarked: false
            )
            allShoots.append(pastShoot)
            shootId += 1
            
            // Future year shoot
            let futureDate = formatter.date(from: "2025-\(String(format: "%02d", month))-20")!
            let futureShoot = Shoot(
                id: shootId,
                shootName: shootNames[(month + 11) % shootNames.count],
                shootType: shootTypes.randomElement()!,
                startDate: futureDate,
                endDate: Calendar.current.date(byAdding: .day, value: Int.random(in: 0...3), to: futureDate),
                clubName: clubNames[(month + 6) % clubNames.count],
                address1: "\(Int.random(in: 100...9999)) Oak Avenue",
                address2: nil,
                city: "Town\(month)",
                state: states[(shootId - 1) % states.count],
                zip: String(format: "%05d", Int.random(in: 10000...99999)),
                country: "USA",
                zone: Int.random(in: 1...8),
                clubEmail: "info@club\(month).com",
                pocName: "Jane Smith",
                pocPhone: "(555) 555-\(String(format: "%04d", 2000 + month))",
                pocEmail: "jane@club\(month).com",
                clubID: month + 100,
                eventType: eventTypes[(shootId - 1) % 3],
                region: ["North", "South", "East", "West"].randomElement(),
                fullAddress: nil,
                latitude: Double.random(in: 25...49),
                longitude: Double.random(in: -125...(-70)),
                notabilityLevelRaw: nil, // Will fallback to computed logic
                morningTempF: nil,
                afternoonTempF: nil,
                morningTempC: nil,
                afternoonTempC: nil,
                durationDays: nil,
                morningTempBand: nil,
                afternoonTempBand: nil,
                estimationMethod: nil,
                isMarked: false
            )
            allShoots.append(futureShoot)
            shootId += 1
        }
        
        // Add more shoots to ensure all states are covered
        for i in 24..<states.count {
            let extraDate = formatter.date(from: "2025-\(String(format: "%02d", (i % 12) + 1))-10")!
            let extraShoot = Shoot(
                id: shootId,
                shootName: "EXTRA \(shootNames[i % shootNames.count])",
                shootType: shootTypes.randomElement()!,
                startDate: extraDate,
                endDate: nil,
                clubName: clubNames[i % clubNames.count],
                address1: nil,
                address2: nil,
                city: "City\(i)",
                state: states[i],
                zip: nil,
                country: "USA",
                zone: nil,
                clubEmail: nil,
                pocName: nil,
                pocPhone: nil,
                pocEmail: nil,
                clubID: nil,
                eventType: eventTypes[i % 3],
                region: nil,
                fullAddress: nil,
                latitude: nil,
                longitude: nil,
                notabilityLevelRaw: nil, // Will fallback to computed logic
                morningTempF: nil,
                afternoonTempF: nil,
                morningTempC: nil,
                afternoonTempC: nil,
                durationDays: nil,
                morningTempBand: nil,
                afternoonTempBand: nil,
                estimationMethod: nil,
                isMarked: false
            )
            allShoots.append(extraShoot)
            shootId += 1
        }
        
        shoots = allShoots.sorted { $0.startDate < $1.startDate }
        
        // Apply marked status
        applyMarkedStatus()
    }
    
    // MARK: - Calendar Integration Methods
    
    func checkCalendarPermission() {
        let previousPermission = hasCalendarPermission
        
        if #available(iOS 17.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            // Since we're requesting full access, require fullAccess status
            hasCalendarPermission = (status == .fullAccess)
            print("📅 Calendar permission check (iOS 17+): status=\(status.rawValue), hasPermission=\(hasCalendarPermission)")
        } else {
            let status = EKEventStore.authorizationStatus(for: .event)
            hasCalendarPermission = (status == .authorized)
            print("📅 Calendar permission check: status=\(status.rawValue), hasPermission=\(hasCalendarPermission)")
        }
        
        // If permission was revoked, automatically disable sync
        if previousPermission && !hasCalendarPermission && isCalendarSyncEnabled {
            print("📅 Calendar permission was revoked, disabling sync")
            setCalendarSyncEnabled(false)
        }
        
        // If permission was granted (from Settings), automatically enable sync
        if !previousPermission && hasCalendarPermission && !isCalendarSyncEnabled {
            print("📅 Calendar permission was granted, auto-enabling sync")
            
            // Debug: Show available calendars now that we have permission
            debugAvailableCalendars()
            
            setCalendarSyncEnabled(true)
            
            // Sync existing marked shoots
            Task {
                let markedShoots = shoots.filter { $0.isMarked }
                await syncAllMarkedShoots(markedShoots)
            }
        }
        
        // Also show calendars if permission status changed
        if previousPermission != hasCalendarPermission {
            debugAvailableCalendars()
        }
        
        // Store permission state for analytics
        UserDefaults.standard.set(hasCalendarPermission, forKey: "hasCalendarPermission")
    }
    
    func debugAvailableCalendars() {
        guard hasCalendarPermission else {
            print("📅 🔍 CALENDAR DEBUG: No permission to access calendars")
            return
        }
        
        let allCalendars = eventStore.calendars(for: .event)
        let writableCalendars = allCalendars.filter { $0.allowsContentModifications && !$0.isImmutable }
        let sources = eventStore.sources
        
        print("📅 🔍 STARTUP CALENDAR DEBUG:")
        print("📅 Permission status: \(hasCalendarPermission)")
        print("📅 Total sources: \(sources.count)")
        print("📅 Total calendars: \(allCalendars.count)")
        print("📅 Writable calendars: \(writableCalendars.count)")
        
        print("📅 📋 SOURCES:")
        for source in sources {
            let sourceTypeDesc = getSourceTypeDescription(source.sourceType)
            let calendarsInSource = allCalendars.filter { $0.source == source }
            print("📅   • \(source.title) (\(sourceTypeDesc)) - \(calendarsInSource.count) calendars - ID: \(source.sourceIdentifier)")
        }
        
        print("📅 📋 ALL CALENDARS:")
        for calendar in allCalendars {
            let writable = calendar.allowsContentModifications && !calendar.isImmutable
            let sourceName = calendar.source?.title ?? "Unknown"
            let sourceType = calendar.source?.sourceType.rawValue ?? -1
            let sourceTypeDesc = getSourceTypeDescription(calendar.source?.sourceType ?? .local)
            let hasPersonalName = hasPersonalNameInTitle(calendar.title)
            let hasDomain = hasDomainInTitle(calendar.title)
            
            let marker = writable ? "✅" : "❌"
            let personalMarker = hasPersonalName ? "👤" : "  "
            let domainMarker = hasDomain ? "🌐" : "  "
            print("📅   \(marker)\(personalMarker)\(domainMarker) '\(calendar.title)' - Source: \(sourceName) (type:\(sourceType)/\(sourceTypeDesc))")
            print("📅     - ID: \(calendar.calendarIdentifier)")
            print("📅     - Allows modifications: \(calendar.allowsContentModifications)")
            print("📅     - Is immutable: \(calendar.isImmutable)")
            if hasPersonalName {
                print("📅     - 👤 Contains personal name (highest priority)")
            }
            if hasDomain {
                print("📅     - 🌐 Contains domain name (high priority)")
            }
        }
        
        if let currentCalendar = shootScheduleCalendar {
            print("📅 📌 CURRENTLY SELECTED: '\(currentCalendar.title)' in \(currentCalendar.source?.title ?? "Unknown")")
        } else {
            print("📅 📌 NO CALENDAR CURRENTLY SELECTED")
        }
    }
    
    func requestCalendarPermission() async -> Bool {
        print("📅 Requesting full calendar permission...")
        // Always request full access to read existing calendars and write to them
        // This is necessary for CalDAV sources (Google Calendar, etc.) that don't allow
        // creating new calendars but do allow writing to existing ones
        let granted: Bool
        do {
            granted = try await eventStore.requestAccess(to: .event)
            print("📅 Calendar permission result (full access): \(granted)")
        } catch {
            print("📅 Calendar permission error: \(error)")
            granted = false
        }
        
        await MainActor.run {
            hasCalendarPermission = granted
            // Store permission state
            UserDefaults.standard.set(granted, forKey: "hasCalendarPermission")
            UserDefaults.standard.synchronize()
            
            if granted {
                print("📅 Permission granted, auto-enabling sync and setting up calendar...")
                // Auto-enable sync when permission is granted
                setCalendarSyncEnabled(true)
                
                Task {
                    await setupShootScheduleCalendar()
                    
                    // Sync existing marked shoots after calendar is set up
                    let markedShoots = shoots.filter { $0.isMarked }
                    print("📅 Found \(markedShoots.count) marked shoots to sync: \(markedShoots.map { "\($0.id): \($0.shootName)" })")
                    
                    if !markedShoots.isEmpty {
                        await syncAllMarkedShoots(markedShoots)
                        print("📅 Completed syncing \(markedShoots.count) marked shoots")
                    } else {
                        print("📅 No marked shoots to sync")
                    }
                }
            }
        }
        return granted
    }
    
    private func loadCalendarSyncPreference() {
        isCalendarSyncEnabled = UserDefaults.standard.bool(forKey: "calendarSyncEnabled")
    }
    
    func setCalendarSyncEnabled(_ enabled: Bool) {
        print("📅 Setting calendar sync enabled: \(enabled), hasPermission: \(hasCalendarPermission)")
        isCalendarSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "calendarSyncEnabled")
        UserDefaults.standard.synchronize()
        
        // Sync preference change to backend
        syncPreferencesIfAuthenticated()
        
        if enabled && hasCalendarPermission {
            print("📅 📝 Calendar sync ENABLED - will set up calendar")
            Task {
                await setupShootScheduleCalendar()
            }
        } else if !enabled {
            print("📅 🗑️ Calendar sync DISABLED - calendar and events will be removed via removeAllShootEvents()")
        }
    }
    
    @MainActor
    private func setupShootScheduleCalendar() async {
        guard hasCalendarPermission else { return }
        
        // Try to find existing calendar
        if let existingCalendar = findShootScheduleCalendar() {
            shootScheduleCalendar = existingCalendar
            print("📅 Found existing ShootSchedule calendar")
            return
        }
        
        // Try to create calendar with different sources until one works
        await tryCreateCalendar()
    }
    
    private func tryCreateCalendar() async {
        let allSources = getSortedCalendarSources()
        let availableSources = getAvailableCalendarSources()
        
        print("📅 All sources: \(allSources.count), Available sources: \(availableSources.count)")
        
        // If user has already selected a preferred source, use it
        if let savedSourceId = UserDefaults.standard.string(forKey: "preferredCalendarSourceId"),
           let preferredSource = allSources.first(where: { $0.sourceIdentifier == savedSourceId }) {
            print("📅 Using previously selected calendar source: \(preferredSource.title)")
            await createCalendar(in: preferredSource)
            return
        }
        
        // With full calendar access, we can now see all calendars and let user choose
        let allCalendars = eventStore.calendars(for: .event)
        let writableCalendars = allCalendars.filter { $0.allowsContentModifications && !$0.isImmutable }
        
        print("📅 🔍 CALENDAR SETUP DEBUG:")
        print("📅 Found \(allCalendars.count) total calendars, \(writableCalendars.count) writable")
        
        // Log detailed calendar information
        for calendar in allCalendars {
            let writable = calendar.allowsContentModifications && !calendar.isImmutable
            let sourceName = calendar.source?.title ?? "Unknown"
            let sourceType = calendar.source?.sourceType.rawValue ?? -1
            let sourceTypeDesc = getSourceTypeDescription(calendar.source?.sourceType ?? .local)
            
            let marker = writable ? "✅" : "❌"
            print("📅   \(marker) '\(calendar.title)' - Source: \(sourceName) (type:\(sourceType)/\(sourceTypeDesc)) - ID: \(calendar.calendarIdentifier)")
        }
        
        // If we have multiple calendar options, offer user selection
        if allCalendars.count > 1 {
            print("📅 Multiple calendars available, user selection needed")
            UserDefaults.standard.set(true, forKey: "needsCalendarSourceSelection")
            
            // Try to use the best available calendar as a default
            if let bestCalendar = writableCalendars.first {
                print("📅 Using best available writable calendar as default: \(bestCalendar.title)")
                shootScheduleCalendar = bestCalendar
                UserDefaults.standard.set(bestCalendar.calendarIdentifier, forKey: "shootScheduleCalendarId")
            }
        }
        // Only one calendar available, use it
        else if let onlyCalendar = allCalendars.first {
            print("📅 Only one calendar available, using: \(onlyCalendar.title)")
            shootScheduleCalendar = onlyCalendar
            UserDefaults.standard.set(onlyCalendar.calendarIdentifier, forKey: "shootScheduleCalendarId")
        } else {
            print("📅 ❌ No calendars found at all")
        }
    }
    
    private func getAvailableCalendarSources() -> [EKSource] {
        let allSources = getSortedCalendarSources()
        
        // First, check if we can test calendar creation capability
        return allSources.filter { source in
            // Always include local sources as they typically allow calendar creation
            if source.sourceType == .local {
                return true
            }
            
            // For non-local sources, check if they have writable calendars
            let calendarsInSource = eventStore.calendars(for: .event).filter { $0.source == source }
            let writableCalendars = calendarsInSource.filter { !$0.isImmutable }
            
            print("📅 Source '\(source.title)' has \(calendarsInSource.count) calendars, \(writableCalendars.count) writable")
            
            // If source has writable calendars, it might allow calendar creation
            return !writableCalendars.isEmpty
        }
    }
    
    private func createCalendar(in source: EKSource) async {
        print("📅 Creating calendar in source: \(source.title) (type: \(source.sourceType.rawValue))")
        
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle
        // Clay target orange color (RGB: 255, 140, 56)
        calendar.cgColor = UIColor(red: 1.0, green: 0.55, blue: 0.22, alpha: 1.0).cgColor
        calendar.source = source
        
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            shootScheduleCalendar = calendar
            
            // Store calendar identifier and source preference for future use
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: "shootScheduleCalendarId")
            UserDefaults.standard.set(source.sourceIdentifier, forKey: "preferredCalendarSourceId")
            
            print("📅 ✅ Created ShootSchedule calendar successfully with ID: \(calendar.calendarIdentifier)")
            print("📅 ✅ Calendar source: \(source.title) (type: \(source.sourceType.rawValue))")
            
        } catch let error as NSError {
            print("📅 ❌ Failed to create calendar in source '\(source.title)': \(error.localizedDescription)")
            
            if error.domain == "EKErrorDomain" && error.code == 17 {
                print("📅 Source '\(source.title)' doesn't allow calendar creation, trying fallback approach...")
                
                // Fallback: Try to use an existing writable calendar in this source
                await tryUseExistingCalendar(in: source)
                
                // If fallback failed, try next available source
                if shootScheduleCalendar == nil {
                    let availableSources = getAvailableCalendarSources()
                    if let nextSource = availableSources.first(where: { $0 != source }) {
                        await createCalendar(in: nextSource)
                    }
                }
            }
        }
    }
    
    private func tryUseExistingCalendar(in source: EKSource) async {
        let calendarsInSource = eventStore.calendars(for: .event).filter { $0.source == source }
        let writableCalendars = calendarsInSource.filter { !$0.isImmutable && $0.allowsContentModifications }
        
        print("📅 Looking for existing writable calendars in '\(source.title)': found \(writableCalendars.count)")
        
        // Try to find a suitable existing calendar
        if let suitableCalendar = writableCalendars.first(where: { $0.title.lowercased().contains("personal") || $0.title.lowercased().contains("default") }) ?? writableCalendars.first {
            
            print("📅 Using existing calendar: '\(suitableCalendar.title)' as fallback")
            
            // Create a dedicated calendar within this source if possible, otherwise use the existing one directly
            let dedicatedCalendar = EKCalendar(for: .event, eventStore: eventStore)
            dedicatedCalendar.title = calendarTitle
            dedicatedCalendar.cgColor = UIColor(red: 1.0, green: 0.55, blue: 0.22, alpha: 1.0).cgColor
            dedicatedCalendar.source = source
            
            do {
                try eventStore.saveCalendar(dedicatedCalendar, commit: true)
                shootScheduleCalendar = dedicatedCalendar
                UserDefaults.standard.set(dedicatedCalendar.calendarIdentifier, forKey: "shootScheduleCalendarId")
                print("📅 ✅ Created dedicated calendar in existing source successfully")
            } catch {
                // If we still can't create a dedicated calendar, we'll need to use a different approach
                print("📅 Still can't create dedicated calendar, source is too restrictive")
            }
        } else {
            print("📅 No suitable writable calendars found in source '\(source.title)'")
        }
    }
    
    private func getSortedCalendarSources() -> [EKSource] {
        let sources = eventStore.sources
        print("📅 Available calendar sources: \(sources.map { "\($0.title): \($0.sourceType.rawValue)" })")
        
        // Sort sources by preference: Local > CalDAV > iCloud > Exchange > Others
        return sources.sorted { source1, source2 in
            let priority1 = getSourcePriority(source1.sourceType)
            let priority2 = getSourcePriority(source2.sourceType)
            return priority1 < priority2 // Lower number = higher priority
        }
    }
    
    private func getSourcePriority(_ sourceType: EKSourceType) -> Int {
        switch sourceType {
        case .calDAV: return 1    // Google Calendar, Yahoo, etc. - preferred for user choice
        case .exchange: return 2  // Work/corporate calendars
        case .local: return 3     // Device local calendar
        case .mobileMe: return 4  // Legacy iCloud/MobileMe - may have restrictions
        default: return 5
        }
    }
    
    // MARK: - Calendar Source Selection
    
    func getCalendarSourcesForUserSelection() -> [(id: String, title: String, type: String)] {
        // Return individual calendars instead of sources, prioritizing writable ones
        let allCalendars = eventStore.calendars(for: .event)
        
        // Filter to only writable calendars - no point showing read-only ones like birthdays/holidays
        let writableCalendars = allCalendars.filter { calendar in
            calendar.allowsContentModifications && !calendar.isImmutable
        }
        
        print("📅 🔍 CALENDAR SELECTION DEBUG:")
        print("📅 Total calendars found: \(allCalendars.count)")
        print("📅 Writable calendars (shown to user): \(writableCalendars.count)")
        
        // Log all calendars for debugging, but mark which ones are filtered out
        for calendar in allCalendars {
            let writable = calendar.allowsContentModifications && !calendar.isImmutable
            let sourceName = calendar.source?.title ?? "Unknown"
            let sourceType = calendar.source?.sourceType.rawValue ?? -1
            let sourceTypeDesc = getSourceTypeDescription(calendar.source?.sourceType ?? .local)
            
            let hasPersonalName = hasPersonalNameInTitle(calendar.title)
            let hasDomain = hasDomainInTitle(calendar.title)
            
            let status = writable ? "✅ SHOWN" : "❌ FILTERED OUT"
            let personalMarker = hasPersonalName ? "👤" : "  "
            let domainMarker = hasDomain ? "🌐" : "  "
            
            print("📅   \(status)\(personalMarker)\(domainMarker) '\(calendar.title)' - Source: \(sourceName) (type:\(sourceType)/\(sourceTypeDesc))")
        }
        
        // Sort writable calendars: personal names first, domain names next, then by source priority, then by name
        let sortedCalendars = writableCalendars.sorted { calendar1, calendar2 in
            // First priority: calendars with personal names (e.g., "John Smith", "Jane Doe")
            let hasPersonalName1 = hasPersonalNameInTitle(calendar1.title)
            let hasPersonalName2 = hasPersonalNameInTitle(calendar2.title)
            
            if hasPersonalName1 != hasPersonalName2 {
                return hasPersonalName1 // personal name calendars first
            }
            
            // Second priority: calendars with domain names (e.g., "weihs.com") come next
            let hasDomain1 = hasDomainInTitle(calendar1.title)
            let hasDomain2 = hasDomainInTitle(calendar2.title)
            
            if hasDomain1 != hasDomain2 {
                return hasDomain1 // domain calendars next
            }
            
            // Third priority: source type priority (CalDAV > Exchange > Local > MobileMe)
            let priority1 = getSourcePriority(calendar1.source?.sourceType ?? .local)
            let priority2 = getSourcePriority(calendar2.source?.sourceType ?? .local)
            
            if priority1 != priority2 {
                return priority1 < priority2 // lower number = higher priority
            }
            
            // Fourth priority: alphabetical by title
            return calendar1.title < calendar2.title
        }
        
        return sortedCalendars.map { calendar in
            let sourceName = calendar.source?.title ?? "Unknown"
            let sourceType = getSourceTypeDescription(calendar.source?.sourceType ?? .local)
            let typeDescription = "\(sourceName) • \(sourceType)"
            
            return (
                id: calendar.calendarIdentifier,
                title: calendar.title,
                type: typeDescription
            )
        }
    }
    
    private func hasPersonalNameInTitle(_ title: String) -> Bool {
        // Look for personal name patterns (First Last, First Middle Last, etc.)
        // Clean title by removing common calendar words and parentheses content
        var cleanTitle = title
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression) // Remove (domain.com)
            .replacingOccurrences(of: "Calendar", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "'s Calendar", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip if empty or too short after cleaning
        guard !cleanTitle.isEmpty && cleanTitle.count >= 3 else { return false }
        
        // Skip common generic terms that aren't names
        let genericTerms = ["work", "home", "personal", "business", "family", "events", "tasks", "reminders", "default", "main", "primary"]
        if genericTerms.contains(where: { cleanTitle.lowercased().contains($0) }) {
            return false
        }
        
        // Look for name patterns:
        // 1. Two or more capitalized words (First Last, First Middle Last)
        let namePattern = #"^[A-Z][a-z]+(\s+[A-Z][a-z]+)+$"#
        
        do {
            let regex = try NSRegularExpression(pattern: namePattern, options: [])
            let range = NSRange(location: 0, length: cleanTitle.utf16.count)
            let hasNamePattern = !regex.matches(in: cleanTitle, options: [], range: range).isEmpty
            
            if hasNamePattern {
                print("📅 👤 Found personal name in calendar title: '\(title)' -> '\(cleanTitle)'")
                return true
            }
        } catch {
            print("📅 ❌ Regex error in hasPersonalNameInTitle: \(error)")
        }
        
        // Fallback: Check for common name indicators
        // Split into words and check if we have 2+ capitalized words that look like names
        let words = cleanTitle.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.first?.isUppercase == true }
        
        let hasPersonalName = words.count >= 2 && words.count <= 4 && words.allSatisfy { word in
            // Each word should be 2+ characters, start with capital, rest lowercase, no numbers
            word.count >= 2 && 
            word.first?.isUppercase == true && 
            word.dropFirst().allSatisfy { $0.isLowercase } &&
            !word.contains { $0.isNumber }
        }
        
        if hasPersonalName {
            print("📅 👤 Found personal name in calendar title (fallback): '\(title)' -> '\(cleanTitle)'")
        }
        
        return hasPersonalName
    }
    
    private func hasDomainInTitle(_ title: String) -> Bool {
        // Look for domain patterns like "weihs.com", "company.org", etc.
        // Pattern: word followed by dot followed by 2-4 letter extension, often in parentheses
        let domainPattern = #"(\()?[a-zA-Z0-9-]+\.[a-zA-Z]{2,4}(\))?"#
        
        do {
            let regex = try NSRegularExpression(pattern: domainPattern, options: [])
            let range = NSRange(location: 0, length: title.utf16.count)
            let matches = regex.matches(in: title, options: [], range: range)
            
            let hasDomain = !matches.isEmpty
            if hasDomain {
                print("📅 🔍 Found domain in calendar title: '\(title)'")
            }
            return hasDomain
        } catch {
            print("📅 ❌ Regex error in hasDomainInTitle: \(error)")
            // Fallback: simple check for common patterns
            return title.contains(".com") || title.contains(".org") || title.contains(".net") || 
                   title.contains(".edu") || title.contains(".gov") || title.contains(".co")
        }
    }
    
    func getCurrentCalendarInfo() -> (name: String, source: String)? {
        guard let calendar = shootScheduleCalendar else { return nil }
        let sourceName = calendar.source?.title ?? "Unknown Source"
        let sourceType = calendar.source?.sourceType.rawValue ?? 0
        let typeDescription = getSourceTypeDescription(calendar.source?.sourceType ?? .local)
        return (name: calendar.title, source: "\(sourceName) (\(typeDescription))")
    }
    
    func selectCalendarSource(sourceId: String) async -> Bool {
        // sourceId is now a calendar identifier, not a source identifier
        let allCalendars = eventStore.calendars(for: .event)
        guard let selectedCalendar = allCalendars.first(where: { $0.calendarIdentifier == sourceId }) else {
            print("📅 ❌ Selected calendar not found: \(sourceId)")
            return false
        }
        
        print("📅 User selected calendar: \(selectedCalendar.title) in source: \(selectedCalendar.source?.title ?? "Unknown")")
        
        // Check if the selected calendar is writable
        let isWritable = selectedCalendar.allowsContentModifications && !selectedCalendar.isImmutable
        
        if !isWritable {
            print("📅 ⚠️ Selected calendar is read-only, this may not work for event creation")
        }
        
        // Remove existing ShootSchedule calendar if it exists (tear down old calendar)
        if shootScheduleCalendar != nil {
            print("📅 🗑️ Tearing down existing ShootSchedule calendar before switching")
            await removeShootScheduleCalendar()
        }
        
        // Use the selected existing calendar directly
        shootScheduleCalendar = selectedCalendar
        
        // Store the selected calendar identifier
        UserDefaults.standard.set(selectedCalendar.calendarIdentifier, forKey: "shootScheduleCalendarId")
        UserDefaults.standard.set(selectedCalendar.source?.sourceIdentifier, forKey: "preferredCalendarSourceId")
        
        print("📅 ✅ Using existing calendar: \(selectedCalendar.title)")
        
        // Clear the need for selection flag
        UserDefaults.standard.removeObject(forKey: "needsCalendarSourceSelection")
        
        return true
    }
    
    var needsCalendarSourceSelection: Bool {
        return UserDefaults.standard.bool(forKey: "needsCalendarSourceSelection")
    }
    
    // MARK: - Duplicate Event Detection
    
    func detectAndLogDuplicateEvents() async {
        guard let calendar = shootScheduleCalendar else {
            print("📅 🔍 DUPLICATE CHECK: No calendar selected")
            return
        }
        
        print("📅 🔍 DUPLICATE EVENT DETECTION:")
        print("📅 Checking calendar: '\(calendar.title)'")
        
        // Get all events in the calendar for a wide date range
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )
        
        let allEvents = eventStore.events(matching: predicate)
        print("📅 Total events in calendar: \(allEvents.count)")
        
        // Group events by ShootID (extracted from notes)
        var eventsByShootID: [Int: [EKEvent]] = [:]
        var eventsWithoutShootID: [EKEvent] = []
        
        for event in allEvents {
            if let shootID = extractShootIDFromNotes(event.notes) {
                if eventsByShootID[shootID] == nil {
                    eventsByShootID[shootID] = []
                }
                eventsByShootID[shootID]?.append(event)
            } else {
                eventsWithoutShootID.append(event)
            }
        }
        
        print("📅 Events with ShootID: \(eventsByShootID.values.flatMap { $0 }.count)")
        print("📅 Events without ShootID: \(eventsWithoutShootID.count)")
        
        // Find and log duplicates
        let duplicateGroups = eventsByShootID.filter { $0.value.count > 1 }
        
        print("📅 🚨 DUPLICATE ANALYSIS:")
        print("📅 Found \(duplicateGroups.count) shoot(s) with duplicate events")
        
        for (shootID, events) in duplicateGroups {
            print("📅   🚨 ShootID \(shootID): \(events.count) duplicate events")
            for (index, event) in events.enumerated() {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                
                print("📅     [\(index + 1)] '\(event.title ?? "No Title")'")
                print("📅         - Event ID: \(event.eventIdentifier ?? "nil")")
                print("📅         - Created: \(dateFormatter.string(from: event.creationDate ?? Date()))")
                print("📅         - Start: \(dateFormatter.string(from: event.startDate))")
                print("📅         - End: \(dateFormatter.string(from: event.endDate))")
                print("📅         - All Day: \(event.isAllDay)")
            }
        }
        
        // Also check for potential duplicates by title (in case ShootID is missing)
        var eventsByTitle: [String: [EKEvent]] = [:]
        for event in allEvents {
            let title = event.title ?? "Untitled"
            if eventsByTitle[title] == nil {
                eventsByTitle[title] = []
            }
            eventsByTitle[title]?.append(event)
        }
        
        let titleDuplicates = eventsByTitle.filter { $0.value.count > 1 }
        if !titleDuplicates.isEmpty {
            print("📅 🔍 TITLE-BASED DUPLICATES (may include legitimate recurring events):")
            for (title, events) in titleDuplicates {
                print("📅   Title '\(title)': \(events.count) events")
            }
        }
        
        print("📅 🔍 DUPLICATE DETECTION COMPLETE")
    }
    
    func deduplicateEvents() async {
        guard let calendar = shootScheduleCalendar else {
            print("📅 🧹 DEDUPLICATION: No calendar selected")
            return
        }
        
        print("📅 🧹 STARTING EVENT DEDUPLICATION:")
        print("📅 Target calendar: '\(calendar.title)'")
        
        // Get all events in the calendar for a very wide date range for comprehensive deduplication
        let startDate = Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .year, value: 3, to: Date()) ?? Date()
        
        print("📅 🧹 DEDUPLICATION DATE RANGE: \(DateFormatter.localizedString(from: startDate, dateStyle: .short, timeStyle: .none)) to \(DateFormatter.localizedString(from: endDate, dateStyle: .short, timeStyle: .none))")
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )
        
        let allEvents = eventStore.events(matching: predicate)
        print("📅 Total events before deduplication: \(allEvents.count)")
        
        // Group events by ShootID
        var eventsByShootID: [Int: [EKEvent]] = [:]
        var eventsWithoutShootID: [EKEvent] = []
        
        for event in allEvents {
            if let shootID = extractShootIDFromNotes(event.notes) {
                if eventsByShootID[shootID] == nil {
                    eventsByShootID[shootID] = []
                }
                eventsByShootID[shootID]?.append(event)
            } else {
                eventsWithoutShootID.append(event)
            }
        }
        
        // Find duplicates and remove all but the most recent one
        let duplicateGroups = eventsByShootID.filter { $0.value.count > 1 }
        var totalRemoved = 0
        
        print("📅 Found \(duplicateGroups.count) shoot(s) with duplicate events")
        
        for (shootID, events) in duplicateGroups {
            print("📅   🧹 Processing ShootID \(shootID): \(events.count) duplicate events")
            
            // Sort events by creation date (most recent first)
            let sortedEvents = events.sorted { event1, event2 in
                let date1 = event1.creationDate ?? Date.distantPast
                let date2 = event2.creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            // Keep the most recent event (first in sorted array)
            let eventToKeep = sortedEvents.first!
            let eventsToRemove = Array(sortedEvents.dropFirst())
            
            print("📅     ✅ KEEPING: '\(eventToKeep.title ?? "No Title")' (Created: \(eventToKeep.creationDate ?? Date()))")
            
            // Remove all other events
            for eventToRemove in eventsToRemove {
                do {
                    try eventStore.remove(eventToRemove, span: .thisEvent)
                    totalRemoved += 1
                    print("📅     🗑️ REMOVED: '\(eventToRemove.title ?? "No Title")' (Created: \(eventToRemove.creationDate ?? Date()))")
                } catch {
                    print("📅     ❌ FAILED TO REMOVE: '\(eventToRemove.title ?? "No Title")' - Error: \(error)")
                }
            }
        }
        
        // Final verification
        let finalEvents = eventStore.events(matching: predicate)
        print("📅 🧹 DEDUPLICATION COMPLETE:")
        print("📅 Events before: \(allEvents.count)")
        print("📅 Events removed: \(totalRemoved)")
        print("📅 Events after: \(finalEvents.count)")
        print("📅 Expected after: \(allEvents.count - totalRemoved)")
        
        if finalEvents.count == allEvents.count - totalRemoved {
            print("📅 ✅ Deduplication successful!")
        } else {
            print("📅 ⚠️ Event count mismatch - some removals may have failed")
        }
    }
    
    private func extractShootIDFromNotes(_ notes: String?) -> Int? {
        guard let notes = notes else { return nil }
        
        // Look for "ShootID:123" pattern in notes
        let pattern = #"ShootID:(\d+)"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: notes.utf16.count)
            
            if let match = regex.firstMatch(in: notes, options: [], range: range) {
                let shootIDRange = match.range(at: 1)
                if let swiftRange = Range(shootIDRange, in: notes) {
                    return Int(String(notes[swiftRange]))
                }
            }
        } catch {
            print("📅 ❌ Regex error in extractShootIDFromNotes: \(error)")
        }
        
        return nil
    }
    
    // Deduplicate events for a specific shoot by ShootID
    private func deduplicateEventsForShoot(_ shootID: Int) async {
        guard let calendar = shootScheduleCalendar else { return }
        
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )
        
        let allEvents = eventStore.events(matching: predicate)
        let shootEvents = allEvents.filter { event in
            extractShootIDFromNotes(event.notes) == shootID
        }
        
        if shootEvents.count > 1 {
            print("📅 🧹 Found \(shootEvents.count) duplicate events for ShootID \(shootID)")
            
            // Sort by creation date (most recent first)
            let sortedEvents = shootEvents.sorted { event1, event2 in
                let date1 = event1.creationDate ?? Date.distantPast
                let date2 = event2.creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            // Remove all but the most recent
            let eventsToRemove = Array(sortedEvents.dropFirst())
            for eventToRemove in eventsToRemove {
                do {
                    try eventStore.remove(eventToRemove, span: .thisEvent)
                    print("📅 🗑️ REMOVED duplicate: '\(eventToRemove.title ?? "No Title")'")
                } catch {
                    print("📅 ❌ Failed to remove duplicate: \(error)")
                }
            }
        }
    }
    
    // Remove all events for a specific shoot by ShootID
    private func removeAllEventsForShoot(_ shootID: Int) async {
        guard let calendar = shootScheduleCalendar else { return }
        
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )
        
        let allEvents = eventStore.events(matching: predicate)
        let shootEvents = allEvents.filter { event in
            extractShootIDFromNotes(event.notes) == shootID
        }
        
        print("📅 🗑️ Removing \(shootEvents.count) events for ShootID \(shootID)")
        for event in shootEvents {
            do {
                try eventStore.remove(event, span: .thisEvent)
                print("📅 🗑️ REMOVED: '\(event.title ?? "No Title")'")
            } catch {
                print("📅 ❌ Failed to remove event: \(error)")
            }
        }
    }
    
    private func getSourceTypeDescription(_ sourceType: EKSourceType) -> String {
        switch sourceType {
        case .local: return "Local Calendar"
        case .calDAV: return "Google/Yahoo Calendar"
        case .exchange: return "Exchange"
        case .mobileMe: return "MobileMe"
        case .subscribed: return "Subscribed"
        case .birthdays: return "Birthdays"
        @unknown default: return "Other"
        }
    }
    
    private func findShootScheduleCalendar() -> EKCalendar? {
        // Try to find by stored identifier first (could be any existing calendar now)
        if let savedId = UserDefaults.standard.string(forKey: "shootScheduleCalendarId"),
           let calendar = eventStore.calendar(withIdentifier: savedId) {
            return calendar
        }
        
        // Fall back to searching by title for legacy ShootSchedule calendars
        return eventStore.calendars(for: .event).first { $0.title == calendarTitle }
    }
    
    private func syncMarkedShoot(_ shoot: Shoot) async {
        guard isCalendarSyncEnabled, hasCalendarPermission else { 
            print("📅 Skipping sync - syncEnabled: \(isCalendarSyncEnabled), hasPermission: \(hasCalendarPermission)")
            return 
        }
        
        print("📅 Syncing shoot: \(shoot.shootName) (ID: \(shoot.id))")
        
        await ensureCalendarSetup()
        guard let calendar = shootScheduleCalendar else { 
            print("📅 ❌ No calendar available for sync")
            return 
        }
        
        // First, deduplicate any existing events for this shoot
        await deduplicateEventsForShoot(shoot.id)
        
        // Check if event already exists (after deduplication)
        if let existingEvent = await findEventForShoot(shoot) {
            print("📅 Updating existing event for shoot: \(shoot.shootName)")
            // Update existing event
            await updateEvent(existingEvent, with: shoot)
        } else {
            print("📅 Creating new event for shoot: \(shoot.shootName)")
            // Create new event
            await createEventForShoot(shoot, in: calendar)
        }
    }
    
    private func removeMarkedShoot(_ shoot: Shoot) async {
        guard hasCalendarPermission else { return }
        
        print("📅 🗑️ Removing all events for shoot: \(shoot.shootName) (ID: \(shoot.id))")
        // Remove ALL events for this shoot, including any duplicates
        await removeAllEventsForShoot(shoot.id)
    }
    
    @MainActor
    private func ensureCalendarSetup() async {
        if shootScheduleCalendar == nil {
            await setupShootScheduleCalendar()
        }
    }
    
    private func findEventForShoot(_ shoot: Shoot) async -> EKEvent? {
        guard let calendar = shootScheduleCalendar else { return nil }
        
        // Search for event by unique identifier stored in notes
        let predicate = eventStore.predicateForEvents(
            withStart: Calendar.current.date(byAdding: .day, value: -1, to: shoot.startDate) ?? shoot.startDate,
            end: Calendar.current.date(byAdding: .day, value: 1, to: shoot.endDate ?? shoot.startDate) ?? shoot.startDate,
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate)
        let matchingEvents = events.filter { event in
            event.notes?.contains("ShootID:\(shoot.id)") == true
        }
        
        // If we find multiple events for the same ShootID, log warning and return the most recent
        if matchingEvents.count > 1 {
            print("📅 ⚠️ Found \(matchingEvents.count) events for ShootID \(shoot.id), using most recent")
            return matchingEvents.sorted { 
                ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast)
            }.first
        }
        
        return matchingEvents.first
    }
    
    @MainActor
    private func createEventForShoot(_ shoot: Shoot, in calendar: EKCalendar) async {
        let event = EKEvent(eventStore: eventStore)
        configureEvent(event, with: shoot, in: calendar)
        
        print("📅 Creating event: title='\(event.title ?? "nil")', calendar='\(event.calendar?.title ?? "nil")', startDate=\(event.startDate), endDate=\(event.endDate)")
        
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            print("📅 ✅ Created calendar event for: \(shoot.shootName) with eventIdentifier: \(event.eventIdentifier ?? "nil")")
        } catch {
            print("❌ Failed to create event: \(error)")
            print("❌ Event details: calendar=\(event.calendar?.title ?? "nil"), hasPermission=\(hasCalendarPermission)")
        }
    }
    
    @MainActor
    private func updateEvent(_ event: EKEvent, with shoot: Shoot) async {
        configureEvent(event, with: shoot, in: event.calendar)
        
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            print("📅 ✅ Updated calendar event for: \(shoot.shootName)")
        } catch {
            print("❌ Failed to update event: \(error)")
        }
    }
    
    private func configureEvent(_ event: EKEvent, with shoot: Shoot, in calendar: EKCalendar) {
        event.title = shoot.displayLabel
        event.calendar = calendar
        
        // Set all-day event with proper timezone handling
        event.isAllDay = true
        
        // Determine the appropriate timezone for the shoot location
        let shootTimeZone = timeZoneForShoot(shoot)
        
        // Use the shoot's exact dates in the event's timezone
        var calendar = Calendar.current
        calendar.timeZone = shootTimeZone
        
        let shootStartDate = shoot.startDate
        let shootEndDate = shoot.endDate ?? shoot.startDate
        
        // For all-day events in EventKit, the end date should be the day AFTER the last day
        // So if shoot runs Jan 1-3, EventKit needs startDate=Jan 1, endDate=Jan 4
        let calendarEndDate = calendar.date(byAdding: .day, value: 1, to: shootEndDate) ?? shootEndDate
        
        // Set the timezone for the event
        event.timeZone = shootTimeZone
        event.startDate = shootStartDate
        event.endDate = calendarEndDate
        
        print("📅 Event dates: shoot=\(shootStartDate) to \(shootEndDate), calendar=\(shootStartDate) to \(calendarEndDate), timezone=\(shootTimeZone.identifier)")
        
        // Create detailed description
        var description = "🎯 \(shoot.shootName)\n"
        description += "🏢 Club: \(shoot.clubName)\n"
        
        if !shoot.locationString.isEmpty && shoot.locationString != "Unknown Location" {
            description += "📍 Location: \(shoot.locationString)\n"
        }
        
        if let eventType = shoot.eventType {
            description += "🏆 Type: \(eventType)"
            if let shootType = shoot.shootType, !shootType.isEmpty {
                description += " \(shootType)"
            }
            description += "\n"
        }
        
        if let pocName = shoot.pocName, !pocName.isEmpty, pocName.lowercased() != "none" {
            description += "👤 Contact: \(pocName)\n"
        }
        
        if let pocPhone = shoot.pocPhone, !pocPhone.isEmpty, pocPhone.lowercased() != "none" {
            description += "📞 Phone: \(pocPhone)\n"
        }
        
        if let email = shoot.pocEmail ?? shoot.clubEmail, !email.isEmpty, email.lowercased() != "none" {
            description += "✉️ Email: \(email)\n"
        }
        
        description += "\n📱 Added by ShootSchedule App"
        
        event.notes = description + "\nShootID:\(shoot.id)" // Hidden identifier
        
        // Set location if available
        if let address = shoot.address1, !address.isEmpty {
            var locationString = address
            if !shoot.locationString.isEmpty && shoot.locationString != "Unknown Location" {
                locationString += ", \(shoot.locationString)"
            }
            event.location = locationString
        } else if !shoot.locationString.isEmpty && shoot.locationString != "Unknown Location" {
            event.location = shoot.locationString
        }
        
        // Set URL if club has email
        if let email = shoot.clubEmail, !email.isEmpty, email.lowercased() != "none" {
            event.url = URL(string: "mailto:\(email)")
        }
        
        // Add reminder (1 day before)
        let alarm = EKAlarm(relativeOffset: -86400) // 24 hours before
        event.addAlarm(alarm)
    }
    
    func syncAllMarkedShoots(_ shoots: [Shoot]) async {
        guard isCalendarSyncEnabled, hasCalendarPermission else { return }
        
        await ensureCalendarSetup()
        
        for shoot in shoots where shoot.isMarked {
            await syncMarkedShoot(shoot)
        }
    }
    
    func removeShootScheduleCalendar() async {
        print("📅 🗑️ Starting calendar removal process...")
        print("📅 🔍 Calendar permission status: \(hasCalendarPermission ? "GRANTED" : "DENIED")")
        
        // List all calendars first for debugging
        let allCalendars = eventStore.calendars(for: .event)
        print("📅 🔍 Found \(allCalendars.count) total calendars in system:")
        for cal in allCalendars {
            print("📅   - '\(cal.title)' (ID: \(cal.calendarIdentifier), Source: \(cal.source?.title ?? "Unknown"))")
        }
        
        guard let calendar = shootScheduleCalendar else { 
            print("📅 ⚠️ No ShootSchedule calendar reference stored - searching for calendar by name...")
            
            // Try to find calendar by name as fallback
            let shootCalendars = allCalendars.filter { $0.title == calendarTitle }
            print("📅 🔍 Found \(shootCalendars.count) calendars with title '\(calendarTitle)':")
            
            for cal in shootCalendars {
                print("📅   - Calendar '\(cal.title)' (ID: \(cal.calendarIdentifier))")
                // Try to remove each one
                do {
                    let predicate = eventStore.predicateForEvents(
                        withStart: Date().addingTimeInterval(-365 * 24 * 3600),
                        end: Date().addingTimeInterval(365 * 24 * 3600),
                        calendars: [cal]
                    )
                    let events = eventStore.events(matching: predicate)
                    print("📅 🗑️ Removing calendar '\(cal.title)' with \(events.count) events...")
                    
                    try eventStore.removeCalendar(cal, commit: true)
                    print("📅 ✅ Successfully removed calendar '\(cal.title)'")
                } catch {
                    print("❌ Failed to remove calendar '\(cal.title)': \(error)")
                }
            }
            
            if shootCalendars.isEmpty {
                print("📅 ✅ No ShootSchedule calendars found to remove")
            }
            return 
        }
        
        print("📅 🗑️ Found calendar to remove: '\(calendar.title)' (ID: \(calendar.calendarIdentifier))")
        
        // Count existing events before deletion for debugging
        let predicate = eventStore.predicateForEvents(
            withStart: Date().addingTimeInterval(-365 * 24 * 3600), // 1 year ago
            end: Date().addingTimeInterval(365 * 24 * 3600),        // 1 year from now
            calendars: [calendar]
        )
        let existingEvents = eventStore.events(matching: predicate)
        print("📅 🗑️ Calendar contains \(existingEvents.count) events that will be removed")
        
        // Show some sample events
        if existingEvents.count > 0 {
            print("📅 🔍 Sample events to be removed:")
            for (index, event) in existingEvents.prefix(3).enumerated() {
                print("📅   \(index + 1). '\(event.title ?? "No Title")' on \(event.startDate)")
            }
            if existingEvents.count > 3 {
                print("📅   ... and \(existingEvents.count - 3) more events")
            }
        }
        
        do {
            try eventStore.removeCalendar(calendar, commit: true)
            shootScheduleCalendar = nil
            
            // Clear stored calendar ID
            UserDefaults.standard.removeObject(forKey: "shootScheduleCalendarId")
            UserDefaults.standard.removeObject(forKey: "hasSelectedCalendarSource")
            
            print("📅 ✅ Successfully removed ShootSchedule calendar '\(calendar.title)' and all \(existingEvents.count) events")
            print("📅 ✅ Cleared calendar reference and UserDefaults storage")
            
            // Double-check that calendar was actually removed
            let updatedCalendars = eventStore.calendars(for: .event)
            let remainingShootCalendars = updatedCalendars.filter { $0.title == calendarTitle }
            if remainingShootCalendars.isEmpty {
                print("📅 ✅ Confirmed: No '\(calendarTitle)' calendars remain in system")
            } else {
                print("📅 ⚠️ Warning: Found \(remainingShootCalendars.count) remaining '\(calendarTitle)' calendars:")
                for cal in remainingShootCalendars {
                    print("📅 ⚠️   - '\(cal.title)' (ID: \(cal.calendarIdentifier))")
                }
            }
            
        } catch {
            print("❌ Failed to remove ShootSchedule calendar: \(error)")
            print("❌ Calendar ID: \(calendar.calendarIdentifier), Title: '\(calendar.title)'")
            print("❌ Error type: \(type(of: error))")
        }
    }
    
    func removeAllShootEvents() async {
        print("📅 🗑️ removeAllShootEvents() called - will remove all synced shoot events")
        
        guard hasCalendarPermission else { 
            print("📅 ⚠️ No calendar permission - cannot remove events")
            return 
        }
        
        guard let calendar = shootScheduleCalendar else { 
            print("📅 ⚠️ No ShootSchedule calendar reference - searching for events to remove...")
            
            // Try to find all ShootSchedule events even without calendar reference
            let allCalendars = eventStore.calendars(for: .event)
            for cal in allCalendars {
                await removeAllEventsFromCalendar(cal)
            }
            return
        }
        
        print("📅 🔍 Removing events from calendar: '\(calendar.title)'")
        
        // Method 1: Remove all events that have ShootID in notes
        await removeAllEventsFromCalendar(calendar)
        
        // Method 2: Also iterate through marked shoots and remove them individually
        // This ensures we catch any events that might not have proper ShootID notes
        let markedShootsToRemove = shoots.filter { markedShootIds.contains($0.id) }
        print("📅 🔍 Found \(markedShootsToRemove.count) marked shoots to remove from calendar")
        
        for shoot in markedShootsToRemove {
            print("📅 🗑️ Removing events for shoot: \(shoot.shootName) (ID: \(shoot.id))")
            await removeAllEventsForShoot(shoot.id)
        }
        
        print("📅 ✅ removeAllShootEvents() completed - removed all shoot events")
    }
    
    private func removeAllEventsFromCalendar(_ calendar: EKCalendar) async {
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )
        
        let allEvents = eventStore.events(matching: predicate)
        
        // Filter for events that have ShootID in notes (our events)
        let shootEvents = allEvents.filter { event in
            event.notes?.contains("ShootID:") == true
        }
        
        if shootEvents.count > 0 {
            print("📅 🗑️ Found \(shootEvents.count) shoot events to remove from calendar '\(calendar.title)'")
            
            // Show sample events
            for (index, event) in shootEvents.prefix(3).enumerated() {
                let shootId = extractShootIDFromNotes(event.notes)
                print("📅   \(index + 1). '\(event.title ?? "No Title")' (ShootID: \(shootId ?? -1))")
            }
            if shootEvents.count > 3 {
                print("📅   ... and \(shootEvents.count - 3) more events")
            }
            
            // Remove each event
            var removedCount = 0
            var failedCount = 0
            
            for event in shootEvents {
                do {
                    try eventStore.remove(event, span: .thisEvent)
                    removedCount += 1
                } catch {
                    print("📅 ❌ Failed to remove event '\(event.title ?? "Unknown")': \(error)")
                    failedCount += 1
                }
            }
            
            // Commit all changes
            if removedCount > 0 {
                do {
                    try eventStore.commit()
                    print("📅 ✅ Successfully removed \(removedCount) events from calendar '\(calendar.title)'")
                } catch {
                    print("📅 ❌ Failed to commit calendar changes: \(error)")
                }
            }
            
            if failedCount > 0 {
                print("📅 ⚠️ Failed to remove \(failedCount) events")
            }
        } else {
            print("📅 ℹ️ No shoot events found in calendar '\(calendar.title)'")
        }
    }
    
    // MARK: - User Preference Synchronization
    
    private let userPreferencesService = UserPreferencesService()
    
    private func setupUserPreferenceSync() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserPreferencesLoaded(_:)),
            name: .userPreferencesLoaded,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewUserNeedsPreferenceSync(_:)),
            name: .newUserNeedsPreferenceSync,
            object: nil
        )
    }
    
    @objc private func handleUserPreferencesLoaded(_ notification: Notification) {
        guard let preferences = notification.object as? UserPreferences else { 
            print("⚠️ Received userPreferencesLoaded notification but couldn't cast to UserPreferences")
            return 
        }
        
        DispatchQueue.main.async {
            print("📥 Applying user preferences from server")
            self.userPreferencesService.applyUserPreferences(preferences, to: self)
        }
    }
    
    @objc private func handleNewUserNeedsPreferenceSync(_ notification: Notification) {
        guard let user = notification.object as? User else { return }
        
        Task {
            await syncCurrentPreferencesToServer(for: user)
        }
    }
    
    func syncCurrentPreferencesToServer(for user: User) async {
        let preferences = userPreferencesService.createUserPreferences(from: user, dataManager: self)
        
        do {
            // Sync both preferences and marked shoots in a single call
            try await userPreferencesService.syncUserPreferences(user: user, preferences: preferences)
            print("📤 Successfully synced current preferences and marked shoots to server")
            
        } catch {
            print("❌ Failed to sync preferences to server: \(error)")
        }
    }
    
    // Fetch preferences from server and apply to local state
    func fetchAndApplyUserPreferences() async {
        guard let authManager = authManager,
              authManager.isAuthenticated,
              let currentUser = authManager.currentUser else {
            print("📥 Cannot fetch preferences - user not authenticated")
            return
        }
        
        do {
            let userPreferencesService = UserPreferencesService()
            if let serverPreferences = try await userPreferencesService.fetchUserPreferences(for: currentUser) {
                print("📥 Fetched user preferences from server, applying to local state...")
                
                // Apply preferences using the existing mechanism
                await MainActor.run {
                    self.userPreferencesService.applyUserPreferences(serverPreferences, to: self)
                    print("✅ Successfully applied server preferences to local state")
                }
            } else {
                print("📥 No preferences found on server for user")
            }
        } catch {
            print("❌ Failed to fetch preferences from server: \(error)")
        }
    }
    
    // Call this whenever user preferences change locally
    func syncPreferencesIfAuthenticated() {
        guard let authManager = authManager, 
              authManager.isAuthenticated,
              let currentUser = authManager.currentUser else {
            print("📤 Local preferences changed - sync deferred (user not authenticated)")
            return
        }
        
        // Cancel any pending sync work
        syncWorkItem?.cancel()
        
        // Create new sync work item with a small delay to debounce rapid changes
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            Task {
                do {
                    let userPreferencesService = UserPreferencesService()
                    let preferences = userPreferencesService.createUserPreferences(from: currentUser, dataManager: self)
                    try await userPreferencesService.syncUserPreferences(user: currentUser, preferences: preferences)
                    print("✅ Successfully synced preferences to server")
                } catch {
                    print("❌ Failed to sync local preferences: \(error)")
                }
            }
        }
        
        syncWorkItem = workItem
        
        // Execute on serial queue with 1 second debounce delay
        preferenceSyncQueue.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    // Set up observers for FilterOptions changes
    func setupFilterOptionsObservers(_ filterOptions: FilterOptions) {
        self.filterOptions = filterOptions
        
        // Clear any existing observers
        filterObservers.forEach { $0.cancel() }
        filterObservers.removeAll()
        
        // Create publishers for all filter properties
        let searchPublisher = filterOptions.$searchText
            .dropFirst() // Skip initial value
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .removeDuplicates()
        
        let affiliationsPublisher = filterOptions.$selectedAffiliations
            .dropFirst()
            .removeDuplicates()
        
        let monthsPublisher = filterOptions.$selectedMonths
            .dropFirst()
            .removeDuplicates()
        
        let statesPublisher = filterOptions.$selectedStates
            .dropFirst()
            .removeDuplicates()
        
        let futureOnlyPublisher = filterOptions.$showFutureOnly
            .dropFirst()
            .removeDuplicates()
        
        let notableOnlyPublisher = filterOptions.$showNotableOnly
            .dropFirst()
            .removeDuplicates()
        
        // Note: showMarkedOnly is not synced - it's just a view filter
        
        // Combine all publishers and trigger sync when any changes
        let combinedPublisher = Publishers.CombineLatest(
            searchPublisher,
            Publishers.CombineLatest(affiliationsPublisher, monthsPublisher)
        )
        .combineLatest(
            Publishers.CombineLatest(statesPublisher, futureOnlyPublisher),
            notableOnlyPublisher
        )
        .map { _ in () }
        
        // Subscribe to combined changes
        let observer = combinedPublisher
            .sink { [weak self] _ in
                print("📝 Filter preferences changed, triggering sync...")
                self?.syncPreferencesIfAuthenticated()
            }
        
        filterObservers.append(observer)
        
        print("✅ Set up observers for FilterOptions changes")
    }
    
    
    // MARK: - Timezone Handling
    
    private func timeZoneForShoot(_ shoot: Shoot) -> TimeZone {
        // First try to use coordinates if available (most accurate)
        if let latitude = shoot.latitude, let longitude = shoot.longitude {
            // For US coordinates, determine timezone based on rough longitude boundaries
            if latitude >= 25.0 && latitude <= 49.0 && longitude >= -125.0 && longitude <= -66.0 {
                switch longitude {
                case -125.0 ..< -120.0: return TimeZone(identifier: "America/Los_Angeles") ?? TimeZone.current
                case -120.0 ..< -104.0: return TimeZone(identifier: "America/Denver") ?? TimeZone.current
                case -104.0 ..< -87.0: return TimeZone(identifier: "America/Chicago") ?? TimeZone.current
                case -87.0 ..< -66.0: return TimeZone(identifier: "America/New_York") ?? TimeZone.current
                default: break
                }
            }
        }
        
        // Fall back to state-based timezone mapping for US states
        guard let state = shoot.state?.uppercased() else {
            return TimeZone.current
        }
        
        switch state {
        // Pacific Time
        case "CA", "NV", "OR", "WA":
            return TimeZone(identifier: "America/Los_Angeles") ?? TimeZone.current
        // Mountain Time
        case "AZ", "CO", "ID", "MT", "NM", "UT", "WY":
            return TimeZone(identifier: "America/Denver") ?? TimeZone.current
        // Central Time
        case "AL", "AR", "IA", "IL", "IN", "KS", "KY", "LA", "MN", "MO", "MS", "ND", "NE", "OK", "SD", "TN", "TX", "WI":
            return TimeZone(identifier: "America/Chicago") ?? TimeZone.current
        // Eastern Time
        case "CT", "DE", "FL", "GA", "MA", "MD", "ME", "MI", "NC", "NH", "NJ", "NY", "OH", "PA", "RI", "SC", "VA", "VT", "WV":
            return TimeZone(identifier: "America/New_York") ?? TimeZone.current
        // Alaska Time
        case "AK":
            return TimeZone(identifier: "America/Anchorage") ?? TimeZone.current
        // Hawaii Time
        case "HI":
            return TimeZone(identifier: "Pacific/Honolulu") ?? TimeZone.current
        default:
            // For international or unknown locations, use user's current timezone
            return TimeZone.current
        }
    }
}
