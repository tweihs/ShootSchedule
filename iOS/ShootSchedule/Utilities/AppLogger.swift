//
//  AppLogger.swift
//  ShootSchedule
//
//  Created on 1/29/25.
//
//  Centralized logging using Apple's unified logging system (OSLog)
//  Provides categorized, performant, and privacy-preserving logging

import Foundation
import os

// MARK: - Logger Categories
extension Logger {
    /// Bundle identifier for the app's logging subsystem
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.shootschedule.app"
    
    // MARK: Core Categories
    
    /// Authentication and user account logging
    static let auth = Logger(subsystem: subsystem, category: "auth")
    
    /// Calendar synchronization and event management
    static let calendar = Logger(subsystem: subsystem, category: "calendar")
    
    /// Database operations and SQLite management
    static let database = Logger(subsystem: subsystem, category: "database")
    
    /// Network requests and API communication
    static let network = Logger(subsystem: subsystem, category: "network")
    
    /// User preference and settings synchronization
    static let preferences = Logger(subsystem: subsystem, category: "preferences")
    
    /// UI events and view lifecycle
    static let ui = Logger(subsystem: subsystem, category: "ui")
    
    /// Data synchronization with backend
    static let sync = Logger(subsystem: subsystem, category: "sync")
    
    /// General app lifecycle and system events
    static let app = Logger(subsystem: subsystem, category: "app")
    
    /// Error tracking across all categories
    static let error = Logger(subsystem: subsystem, category: "error")
}

// MARK: - Debug Configuration
struct LogConfig {
    /// Master switch for verbose logging
    #if DEBUG
    static let verboseLogging = true
    #else
    static let verboseLogging = false
    #endif
    
    /// Category-specific verbose flags (only apply in DEBUG builds)
    struct Verbose {
        static let calendar = true
        static let sync = true
        static let database = true
        static let network = true
        static let preferences = true
        static let auth = true
    }
}

// MARK: - Helper Extensions
extension Logger {
    /// Log with emoji prefix for better visual scanning in console
    func logWithEmoji(_ emoji: String, _ message: String, level: OSLogType = .default) {
        switch level {
        case .debug:
            self.debug("\(emoji) \(message)")
        case .info:
            self.info("\(emoji) \(message)")
        case .error:
            self.error("\(emoji) \(message)")
        case .fault:
            self.fault("\(emoji) \(message)")
        default:
            self.notice("\(emoji) \(message)")
        }
    }
}

// MARK: - Legacy Support
/// Temporary wrapper to help migrate from print statements to OSLog
/// Can be removed once migration is complete
struct DebugLogger {
    static func calendar(_ message: String) {
        #if DEBUG
        if LogConfig.Verbose.calendar {
            Logger.calendar.debug("\(message)")
        }
        #endif
    }
    
    static func sync(_ message: String) {
        #if DEBUG
        if LogConfig.Verbose.sync {
            Logger.sync.debug("\(message)")
        }
        #endif
    }
    
    static func database(_ message: String) {
        #if DEBUG
        if LogConfig.Verbose.database {
            Logger.database.debug("\(message)")
        }
        #endif
    }
}