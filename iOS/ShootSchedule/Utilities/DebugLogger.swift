//
//  DebugLogger.swift
//  ShootSchedule
//
//  Created to manage debug logging groups
//

import Foundation

/// Debug logging categories that can be individually enabled/disabled
enum LogCategory: String, CaseIterable {
    case calendar = "📅"
    case database = "🗄️"
    case network = "🌐"
    case preferences = "⚙️"
    case marked = "📍"
    case auth = "🔐"
    case general = "📱"
    
    var isEnabled: Bool {
        switch self {
        case .calendar:
            return false  // Calendar logging is disabled
        case .database:
            return true
        case .network:
            return true
        case .preferences:
            return true
        case .marked:
            return true
        case .auth:
            return true
        case .general:
            return true
        }
    }
}

/// Debug logger with category-based filtering
struct DebugLogger {
    /// Log a message for a specific category
    static func log(_ message: String, category: LogCategory = .general) {
        guard category.isEnabled else { return }
        print("\(category.rawValue) \(message)")
    }
    
    /// Log calendar-related messages (currently disabled)
    static func calendar(_ message: String) {
        log(message, category: .calendar)
    }
    
    /// Log database-related messages
    static func database(_ message: String) {
        log(message, category: .database)
    }
    
    /// Log network-related messages
    static func network(_ message: String) {
        log(message, category: .network)
    }
    
    /// Log preference-related messages
    static func preferences(_ message: String) {
        log(message, category: .preferences)
    }
    
    /// Log marked shoots-related messages
    static func marked(_ message: String) {
        log(message, category: .marked)
    }
    
    /// Log auth-related messages
    static func auth(_ message: String) {
        log(message, category: .auth)
    }
    
    /// Check if a category is enabled
    static func isEnabled(_ category: LogCategory) -> Bool {
        return category.isEnabled
    }
    
    /// Log only if calendar debugging is enabled
    static func calendarDebug(_ closure: () -> String) {
        guard LogCategory.calendar.isEnabled else { return }
        print("\(LogCategory.calendar.rawValue) \(closure())")
    }
}