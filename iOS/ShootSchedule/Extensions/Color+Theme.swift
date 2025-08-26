//
//  Color+Theme.swift
//  ShootSchedule
//
//  Created on 8/26/25.
//

import SwiftUI

extension Color {
    // App theme colors
    static let appBackground = Color("AppBackground")
    static let warmOffWhite = Color(red: 1.0, green: 0.992, blue: 0.973) // #FFFDF8
    
    // Convenience accessor for the main background color
    static var primaryBackground: Color {
        return warmOffWhite
    }
}