//
//  CalendarManager.swift
//  ShootSchedule
//
//  Created on 1/25/25.
//

import Foundation
import EventKit
import Combine

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    private let calendarTitle = "ShootSchedule Events"
    private let calendarIdentifier = "com.postflight.shootschedule.calendar"
    
    @Published var hasCalendarPermission: Bool = false
    @Published var isCalendarSyncEnabled: Bool = false
    
    private var shootScheduleCalendar: EKCalendar?
    
    private init() {
        checkCalendarPermission()
        loadCalendarSyncPreference()
    }
    
    // MARK: - Permission Management
    
    func checkCalendarPermission() {
        let status = EKEventStore.authorizationStatus(for: .event)
        hasCalendarPermission = (status == .authorized)
    }
    
    func requestCalendarPermission() async -> Bool {
        do {
            let granted = try await eventStore.requestAccess(to: .event)
            await MainActor.run {
                hasCalendarPermission = granted
                if granted {
                    Task {
                        await setupShootScheduleCalendar()
                    }
                }
            }
            return granted
        } catch {
            print("❌ Calendar permission error: \(error)")
            await MainActor.run {
                hasCalendarPermission = false
            }
            return false
        }
    }
    
    // MARK: - Calendar Setup
    
    @MainActor
    private func setupShootScheduleCalendar() async {
        guard hasCalendarPermission else { return }
        
        // Try to find existing calendar
        if let existingCalendar = findShootScheduleCalendar() {
            shootScheduleCalendar = existingCalendar
            DebugLogger.calendar("Found existing ShootSchedule calendar")
            return
        }
        
        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle
        calendar.cgColor = UIColor.systemBlue.cgColor
        
        // Find the best source (iCloud, Local, etc.)
        if let source = eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first {
            calendar.source = source
        }
        
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            shootScheduleCalendar = calendar
            
            // Store calendar identifier for future use
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: "shootScheduleCalendarId")
            
            DebugLogger.calendar("Created ShootSchedule calendar successfully")
        } catch {
            print("❌ Failed to create calendar: \(error)")
        }
    }
    
    private func findShootScheduleCalendar() -> EKCalendar? {
        // Try to find by stored identifier first
        if let savedId = UserDefaults.standard.string(forKey: "shootScheduleCalendarId"),
           let calendar = eventStore.calendar(withIdentifier: savedId) {
            return calendar
        }
        
        // Fall back to searching by title
        return eventStore.calendars(for: .event).first { $0.title == calendarTitle }
    }
    
    // MARK: - Calendar Sync Preferences
    
    private func loadCalendarSyncPreference() {
        isCalendarSyncEnabled = UserDefaults.standard.bool(forKey: "calendarSyncEnabled")
    }
    
    func setCalendarSyncEnabled(_ enabled: Bool) {
        isCalendarSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "calendarSyncEnabled")
        UserDefaults.standard.synchronize()
        
        if enabled && hasCalendarPermission {
            Task {
                await setupShootScheduleCalendar()
            }
        }
    }
    
    // MARK: - Shoot Event Management
    
    func syncMarkedShoot(_ shoot: Shoot) async {
        guard isCalendarSyncEnabled, hasCalendarPermission else { return }
        
        await ensureCalendarSetup()
        guard let calendar = shootScheduleCalendar else { return }
        
        // Check if event already exists
        if let existingEvent = await findEventForShoot(shoot) {
            // Update existing event
            await updateEvent(existingEvent, with: shoot)
        } else {
            // Create new event
            await createEventForShoot(shoot, in: calendar)
        }
    }
    
    func removeMarkedShoot(_ shoot: Shoot) async {
        guard hasCalendarPermission else { return }
        
        if let event = await findEventForShoot(shoot) {
            do {
                try eventStore.remove(event, span: .thisEvent)
                DebugLogger.calendar("Removed shoot event: \(shoot.shootName)")
            } catch {
                print("❌ Failed to remove event: \(error)")
            }
        }
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
        return events.first { event in
            event.notes?.contains("ShootID:\(shoot.id)") == true
        }
    }
    
    @MainActor
    private func createEventForShoot(_ shoot: Shoot, in calendar: EKCalendar) async {
        let event = EKEvent(eventStore: eventStore)
        configureEvent(event, with: shoot, in: calendar)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            DebugLogger.calendar("Created calendar event for: \(shoot.shootName)")
        } catch {
            print("❌ Failed to create event: \(error)")
        }
    }
    
    @MainActor
    private func updateEvent(_ event: EKEvent, with shoot: Shoot) async {
        configureEvent(event, with: shoot, in: event.calendar)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            DebugLogger.calendar("Updated calendar event for: \(shoot.shootName)")
        } catch {
            print("❌ Failed to update event: \(error)")
        }
    }
    
    private func configureEvent(_ event: EKEvent, with shoot: Shoot, in calendar: EKCalendar) {
        event.title = shoot.displayLabel
        event.calendar = calendar
        
        // Set all-day event
        event.isAllDay = true
        event.startDate = shoot.startDate
        event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: shoot.endDate ?? shoot.startDate) ?? shoot.startDate
        
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
    
    // MARK: - Bulk Sync Operations
    
    func syncAllMarkedShoots(_ shoots: [Shoot]) async {
        guard isCalendarSyncEnabled, hasCalendarPermission else { return }
        
        await ensureCalendarSetup()
        
        for shoot in shoots where shoot.isMarked {
            await syncMarkedShoot(shoot)
        }
    }
    
    func removeAllShootEvents() async {
        guard let calendar = shootScheduleCalendar else { return }
        
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .year, value: 2, to: now) ?? now
        
        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            do {
                try eventStore.remove(event, span: .thisEvent)
            } catch {
                print("❌ Failed to remove event: \(error)")
            }
        }
        
        DebugLogger.calendar("Removed \(events.count) shoot events from calendar")
    }
}