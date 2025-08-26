//
//  ShootRowView.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI
import Foundation

struct ShootRowView: View {
    let shoot: Shoot
    @EnvironmentObject var dataManager: DataManager
    @State private var isMarked: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Event Type and Name
                Text(shoot.displayLabel)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                // Club Name
                Text(shoot.clubName)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                // Location
                Text(shoot.locationString.uppercased())
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                // Date and Temperature
                VStack(alignment: .trailing, spacing: 4) {
                    Text(shoot.userFriendlyDate)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.trailing)
                    
                    // Notability Tag
                    if shoot.notabilityLevel != .none {
                        Text(notabilityDisplayText(for: shoot.notabilityLevel))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                            )
                    }
                    
                    // TemperatureDisplayView(shoot: shoot) - Hidden for now
                }
                
                // Mark Button
                Button(action: {
                    toggleMark()
                }) {
                    if isMarked {
                        // Marked state - just checkmark with blue background
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                            )
                    } else {
                        // Unmarked state - "Mark" text with border
                        Text("Mark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 70, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue, lineWidth: 1.5)
                            )
                    }
                }
            }
        }
        .padding()
        .onAppear {
            isMarked = dataManager.isShootMarked(shoot)
        }
    }
    
    private func toggleMark() {
        if isMarked {
            dataManager.unmarkShoot(shoot)
        } else {
            dataManager.markShoot(shoot)
        }
        isMarked.toggle()
    }
    
    private func notabilityDisplayText(for level: ShootNotabilityLevel) -> String {
        switch level {
        case .world:
            return "World"
        case .state:
            return "State"
        case .other:
            return "Regional"
        case .none:
            return ""
        }
    }
    
}

// MARK: - Temperature Display Component
struct TemperatureDisplayView: View {
    let shoot: Shoot
    @State private var useFahrenheit: Bool = true
    
    var body: some View {
        Text(buildDurationAndTempText())
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.trailing)
            .onAppear {
                loadTemperaturePreference()
            }
    }
    
    private func buildDurationAndTempText() -> String {
        let duration = calculateShootDuration()
        let temps = getHistoricalTemperatures()
        
        let morningTemp = convertTemperature(temps.morning)
        let afternoonTemp = convertTemperature(temps.afternoon)
        let unit = temperatureUnit()
        
        let dayText = duration == 1 ? "Day" : "Days"
        return "\(duration) \(dayText) (\(morningTemp)° - \(afternoonTemp)\(unit))"
    }
    
    private func convertTemperature(_ fahrenheit: Int) -> Int {
        if useFahrenheit {
            return fahrenheit
        } else {
            // Convert F to C: (F - 32) * 5/9
            return Int((Double(fahrenheit) - 32.0) * 5.0 / 9.0)
        }
    }
    
    private func temperatureUnit() -> String {
        return useFahrenheit ? "°F" : "°C"
    }
    
    private func loadTemperaturePreference() {
        useFahrenheit = UserDefaults.standard.object(forKey: "useFahrenheit") != nil 
            ? UserDefaults.standard.bool(forKey: "useFahrenheit")
            : true
    }
    
    private func calculateShootDuration() -> Int {
        guard let endDate = shoot.endDate else { return 1 }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: shoot.startDate, to: endDate)
        return max(1, (components.day ?? 0) + 1)
    }
    
    private func getHistoricalTemperatures() -> (morning: Int, afternoon: Int) {
        let month = Calendar.current.component(.month, from: shoot.startDate)
        
        // Base afternoon high temperatures by month (rough averages for US at 3 PM)
        let baseHighTemps = [1: 50, 2: 55, 3: 65, 4: 75, 5: 83, 6: 90, 
                            7: 93, 8: 92, 9: 85, 10: 75, 11: 63, 12: 53]
        
        var afternoonHigh = baseHighTemps[month] ?? 75
        
        // Add regional variation based on state
        if let state = shoot.state {
            switch state {
            case "FL", "TX", "AZ", "CA", "NV":
                afternoonHigh += 8
            case "MT", "WY", "ND", "SD", "MN", "WI", "ME", "VT", "NH":
                afternoonHigh -= 8
            case "WA", "OR", "ID":
                afternoonHigh -= 3
            default:
                break
            }
        }
        
        // Morning temperature difference by season
        let tempDifference: Int
        switch month {
        case 12, 1, 2: tempDifference = 12
        case 3, 4, 11: tempDifference = 18
        case 5, 6, 7, 8, 9, 10: tempDifference = 22
        default: tempDifference = 18
        }
        
        let morningLow = max(afternoonHigh - tempDifference, 20)
        return (morning: morningLow, afternoon: afternoonHigh)
    }
    
    private func getTemperatureColor(for temperature: Int) -> Color {
        if temperature < 15 {
            return Color(red: 0.29, green: 0.56, blue: 0.89) // Frigid
        } else if temperature < 32 {
            return Color(red: 0.69, green: 0.88, blue: 0.96) // Freezing
        } else if temperature < 45 {
            return Color(red: 0.36, green: 0.64, blue: 0.33) // Very Cold
        } else if temperature < 55 {
            return Color(red: 0.55, green: 0.76, blue: 0.29) // Cold
        } else if temperature < 65 {
            return Color(red: 0.80, green: 0.86, blue: 0.22) // Cool
        } else if temperature < 75 {
            return Color(red: 0.98, green: 0.75, blue: 0.18) // Comfortable
        } else if temperature < 85 {
            return Color(red: 0.96, green: 0.49, blue: 0.39) // Warm
        } else if temperature < 95 {
            return Color(red: 0.90, green: 0.29, blue: 0.10) // Hot
        } else {
            return Color(red: 0.75, green: 0.21, blue: 0.05) // Sweltering
        }
    }
}

struct ShootRowView_Previews: PreviewProvider {
    static let sampleShoot = Shoot(
        id: 1,
        shootName: "WESTERN REGIONAL 2025",
        shootType: "Regional",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 3),
        clubName: "ROCK CREEK RANCH",
        address1: nil,
        address2: nil,
        city: "EMMETT",
        state: "ID",
        zip: nil,
        country: "USA",
        zone: nil,
        clubEmail: nil,
        pocName: nil,
        pocPhone: nil,
        pocEmail: nil,
        clubID: nil,
        eventType: "NSCA",
        region: "Western",
        fullAddress: nil,
        latitude: 43.8735,
        longitude: -116.4993,
        notabilityLevelRaw: nil,
        isMarked: false
    )
    
    static var previews: some View {
        ShootRowView(shoot: sampleShoot)
            .environmentObject(DataManager())
            .previewLayout(.sizeThatFits)
    }
}