//
//  NotificationName.swift  
//  ShootSchedule
//
//  Created on 8/26/25.
//

import Foundation

extension Notification.Name {
    static let userPreferencesLoaded = Notification.Name("userPreferencesLoaded")
    static let newUserNeedsPreferenceSync = Notification.Name("newUserNeedsPreferenceSync")
    static let userPreferencesSynced = Notification.Name("userPreferencesSynced")
    static let userSignedOut = Notification.Name("userSignedOut")
}