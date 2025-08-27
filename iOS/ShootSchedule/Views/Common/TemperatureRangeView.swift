//
//  TemperatureRangeView.swift
//  ShootSchedule
//
//  Created on 1/25/25.
//

import SwiftUI

struct TemperatureRangeView: View {
    let shoot: Shoot
    let style: Style
    
    enum Style {
        case detail // Shows "3 Days (53°F - 75°F)"
        case compact // Shows "53° - 75°F"
    }
    
    var body: some View {
        switch style {
        case .detail:
            Text(buildDetailText())
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        case .compact:
            HStack(spacing: 2) {
                let temps = getHistoricalTemperatures()
                Text("\(temps.morning)°")
                    .font(.system(size: 12))
                    .foregroundColor(getTemperatureColor(for: temps.morning))
                Text("-")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("\(temps.afternoon)°F")
                    .font(.system(size: 12))
                    .foregroundColor(getTemperatureColor(for: temps.afternoon))
            }
        }
    }
    
    private func buildDetailText() -> String {
        let duration = calculateShootDuration()
        let temps = getHistoricalTemperatures()
        
        let dayText = duration == 1 ? "Day" : "Days"
        return "\(duration) \(dayText) (\(temps.morning)°F - \(temps.afternoon)°F)"
    }
    
    private func calculateShootDuration() -> Int {
        guard let endDate = shoot.endDate else { return 1 }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: shoot.startDate, to: endDate)
        return max(1, (components.day ?? 0) + 1)
    }
    
    private func getHistoricalTemperatures() -> (morning: Int, afternoon: Int) {
        // For now, return mock temperatures based on month and location
        // In a real implementation, this would call a weather API with historical data
        let month = Calendar.current.component(.month, from: shoot.startDate)
        
        // Base afternoon high temperatures by month (rough averages for US at 3 PM)
        let baseHighTemps = [1: 50, 2: 55, 3: 65, 4: 75, 5: 83, 6: 90, 
                            7: 93, 8: 92, 9: 85, 10: 75, 11: 63, 12: 53]
        
        // Morning lows are typically 15-25°F cooler than afternoon highs
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
        
        // Morning temperature is typically 15-25°F cooler
        // The difference is smaller in winter and larger in summer
        let tempDifference: Int
        switch month {
        case 12, 1, 2: // Winter - smaller difference
            tempDifference = 12
        case 3, 4, 11: // Spring/Fall - medium difference  
            tempDifference = 18
        case 5, 6, 7, 8, 9, 10: // Summer - larger difference
            tempDifference = 22
        default:
            tempDifference = 18
        }
        
        let morningLow = max(afternoonHigh - tempDifference, 20) // Don't go below 20°F
        
        return (morning: morningLow, afternoon: afternoonHigh)
    }
    
    private func getTemperatureColor(for temperature: Int) -> Color {
        if temperature < 15 {
            return Color(red: 0.29, green: 0.56, blue: 0.89) // #4a90e2 - Frigid
        } else if temperature < 32 {
            return Color(red: 0.69, green: 0.88, blue: 0.96) // #b0e0f6 - Freezing
        } else if temperature < 45 {
            return Color(red: 0.36, green: 0.64, blue: 0.33) // #5ba354 - Very Cold
        } else if temperature < 55 {
            return Color(red: 0.55, green: 0.76, blue: 0.29) // #8bc34a - Cold
        } else if temperature < 65 {
            return Color(red: 0.80, green: 0.86, blue: 0.22) // #cddc39 - Cool
        } else if temperature < 75 {
            return Color(red: 0.98, green: 0.75, blue: 0.18) // #fbc02d - Comfortable
        } else if temperature < 85 {
            return Color(red: 0.96, green: 0.49, blue: 0.39) // #f57c63 - Warm
        } else if temperature < 95 {
            return Color(red: 0.90, green: 0.29, blue: 0.10) // #e64a19 - Hot
        } else {
            return Color(red: 0.75, green: 0.21, blue: 0.05) // #bf360c - Sweltering
        }
    }
}

// MARK: - Previews
struct TemperatureRangeView_Previews: PreviewProvider {
    static var sampleShootSummer: Shoot {
        Shoot(
            id: 1,
            shootName: "Summer Championship",
            shootType: "State Championship",
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 15))!,
            endDate: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 17))!,
            clubName: "Desert Shooting Club",
            address1: "123 Desert Rd",
            address2: nil,
            city: "Phoenix",
            state: "AZ",
            zip: "85001",
            country: "USA",
            zone: 1,
            clubEmail: "info@desertclub.com",
            pocName: "John Smith",
            pocPhone: "(555) 123-4567",
            pocEmail: "john@desertclub.com",
            clubID: 1,
            eventType: "NSCA",
            region: "Southwest",
            fullAddress: nil,
            latitude: 33.4484,
            longitude: -112.0740,
            notabilityLevelRaw: 2,
            morningTempF: 75,
            afternoonTempF: 105,
            morningTempC: 24,
            afternoonTempC: 41,
            durationDays: 3,
            morningTempBand: "Warm",
            afternoonTempBand: "Very Hot",
            estimationMethod: "forecast",
            isMarked: false
        )
    }
    
    static var sampleShootWinter: Shoot {
        Shoot(
            id: 2,
            shootName: "Winter Classic",
            shootType: nil,
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 20))!,
            endDate: nil,
            clubName: "Northern Gun Club",
            address1: "456 Snow Lane",
            address2: nil,
            city: "Minneapolis",
            state: "MN",
            zip: "55401",
            country: "USA",
            zone: 3,
            clubEmail: "contact@northernclub.com",
            pocName: "Jane Doe",
            pocPhone: "(555) 987-6543",
            pocEmail: "jane@northernclub.com",
            clubID: 2,
            eventType: "ATA",
            region: "Midwest",
            fullAddress: nil,
            latitude: 44.9778,
            longitude: -93.2650,
            notabilityLevelRaw: nil,
            morningTempF: 15,
            afternoonTempF: 28,
            morningTempC: -9,
            afternoonTempC: -2,
            durationDays: 1,
            morningTempBand: "Very Cold",
            afternoonTempBand: "Cold",
            estimationMethod: "historical",
            isMarked: true
        )
    }
    
    static var previews: some View {
        VStack(spacing: 20) {
            Group {
                Text("Detail Style Examples")
                    .font(.headline)
                
                TemperatureRangeView(shoot: sampleShootSummer, style: .detail)
                TemperatureRangeView(shoot: sampleShootWinter, style: .detail)
            }
            
            Divider()
            
            Group {
                Text("Compact Style Examples")
                    .font(.headline)
                
                TemperatureRangeView(shoot: sampleShootSummer, style: .compact)
                TemperatureRangeView(shoot: sampleShootWinter, style: .compact)
            }
            
            Divider()
            
            Group {
                Text("In Context Examples")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .trailing) {
                        Text("Jul 15, 2025")
                            .font(.system(size: 14))
                        TemperatureRangeView(shoot: sampleShootSummer, style: .compact)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(red: 1.0, green: 0.992, blue: 0.973))
                .cornerRadius(8)
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Jan 20, 2025")
                        .font(.system(size: 15, weight: .semibold))
                    TemperatureRangeView(shoot: sampleShootWinter, style: .detail)
                }
                .padding()
                .background(Color(red: 1.0, green: 0.992, blue: 0.973))
                .cornerRadius(8)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Temperature Range Component")
    }
}