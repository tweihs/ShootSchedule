//
//  main.swift
//  CreateEventsSQLite
//
//  Created by Tyson Weihs on 12/8/24.
//

import Foundation

let fileManager = FileManager.default
let currentDirectory = fileManager.currentDirectoryPath
let csvPath = "/Users/tweihs/Development/Personal/ShootsDB/ShootsDB/CreateEventsSQLite/Geocoded_Combined_Shoot_Schedule_2024.csv"

let dbPath = "/Users/tweihs/Development/Personal/ShootsDB/ShootsDB/CreateEventsSQLite/shootsDB.sqlite"

if fileManager.fileExists(atPath: csvPath) {
    SQLiteGenerator.generateDatabase(from: csvPath, to: dbPath)
    print("Database generated at \(dbPath)")
} else {
    print("CSV file not found at \(csvPath).")
}
