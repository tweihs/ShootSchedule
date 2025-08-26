//
//  TemperatureUtils.swift
//  ShootSchedule
//
//  Created on 1/25/25.
//

import SwiftUI

enum TemperatureBand: CaseIterable {
    case frigid
    case freezing
    case veryCold
    case cold
    case cool
    case comfortable
    case warm
    case hot
    case sweltering
    
    var threshold: Int {
        switch self {
        case .frigid: return 15
        case .freezing: return 32
        case .veryCold: return 45
        case .cold: return 55
        case .cool: return 65
        case .comfortable: return 75
        case .warm: return 85
        case .hot: return 95
        case .sweltering: return 96 // Above 95°F
        }
    }
    
    var color: Color {
        switch self {
        case .frigid: return Color(hex: "#4a90e2")
        case .freezing: return Color(hex: "#b0e0f6")
        case .veryCold: return Color(hex: "#5ba354")
        case .cold: return Color(hex: "#8bc34a")
        case .cool: return Color(hex: "#cddc39")
        case .comfortable: return Color(hex: "#fbc02d")
        case .warm: return Color(hex: "#f57c63")
        case .hot: return Color(hex: "#e64a19")
        case .sweltering: return Color(hex: "#bf360c")
        }
    }
}

struct TemperatureUtils {
    static func getTemperatureBand(for temperature: Int) -> TemperatureBand {
        if temperature < 15 {
            return .frigid
        } else if temperature < 32 {
            return .freezing
        } else if temperature < 45 {
            return .veryCold
        } else if temperature < 55 {
            return .cold
        } else if temperature < 65 {
            return .cool
        } else if temperature < 75 {
            return .comfortable
        } else if temperature < 85 {
            return .warm
        } else if temperature < 95 {
            return .hot
        } else {
            return .sweltering
        }
    }
    
    static func getColoredTemperatureText(for temperature: Int) -> some View {
        let band = getTemperatureBand(for: temperature)
        
        return Text("\(temperature)°F")
            .foregroundColor(band.color)
    }
}

// Color extension to support hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}