//
//  EventLoader.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/8/24.
//

import Foundation

class CSVParser {
    static func parseShootEvents(from path: String, encoding: String.Encoding = .utf8) -> [Event] {
        var shootEvents: [Event] = []
        
        do {
            // Load file content and parse it properly
            let content = try String(contentsOfFile: path, encoding: encoding)
            let rows = parseCSV(content)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for row in rows {
                guard let id = Int(row["id"] ?? ""),
                      let startDateString = row["startDate"],
                      let startDate = dateFormatter.date(from: startDateString),
                      let endDateString = row["endDate"],
                      let endDate = dateFormatter.date(from: endDateString),
                      let latitude = Double(row["latitude"] ?? ""),
                      let longitude = Double(row["longitude"] ?? "") else {
                    print("Skipping malformed row: \(row)")
                    continue
                }

                let shootEvent = Event(
                    id: id,
                    name: row["name"] ?? "",
                    type: row["type"],
                    startDate: startDate,
                    endDate: endDate,
                    club: row["club"] ?? "",
                    address1: row["address1"],
                    address2: row["address2"],
                    city: row["city"] ?? "",
                    state: row["state"] ?? "",
                    zip: row["zip"],
                    country: row["country"],
                    zone: row["zone"],
                    clubEmail: row["clubEmail"],
                    pocName: row["pocName"] ?? "",
                    pocPhone: row["pocPhone"] ?? "",
                    pocEmail: row["pocEmail"] ?? "",
                    clubID: Int(row["clubID"] ?? "") ?? -1,
                    eventType: row["eventType"],
                    region: row["region"],
                    fullAddress: row["fullAddress"],
                    latitude: latitude,
                    longitude: longitude
                )
                shootEvents.append(shootEvent)
            }
        } catch {
            print("Error reading CSV file: \(error)")
        }

        return shootEvents
    }

    // Helper function to parse CSV content
    private static func parseCSV(_ content: String) -> [[String: String]] {
        var result: [[String: String]] = []
        let rows = content.components(separatedBy: "\n").dropFirst() // Skip the header row

        // Extract header keys
        guard let headerLine = content.components(separatedBy: "\n").first else {
            return result
        }
        let headers = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        for row in rows {
            let columns = parseCSVRow(row)
            if columns.count == headers.count {
                var rowDict: [String: String] = [:]
                for (index, header) in headers.enumerated() {
                    rowDict[header] = columns[index]
                }
                result.append(rowDict)
            }
        }
        return result
    }

    // Helper function to parse individual CSV row, accounting for quoted fields
    private static func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in row {
            switch char {
            case "\"":
                inQuotes.toggle()
            case ",":
                if inQuotes {
                    currentField.append(char)
                } else {
                    result.append(currentField)
                    currentField = ""
                }
            default:
                currentField.append(char)
            }
        }
        result.append(currentField) // Add the last field
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}



