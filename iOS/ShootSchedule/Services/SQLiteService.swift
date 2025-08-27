//
//  SQLiteService.swift
//  ShootSchedule
//
//  Created on 1/25/25.
//

import Foundation
import SQLite3

// Database manifest structure for checking updates
struct DatabaseManifest: Codable {
    let lastModified: String
    let fileHash: String
    let fileSize: Int
    let fileSizeMB: Double?
    let databaseVersion: String?
    let shootCount: Int?
    let generatedAt: String?
    let includesWeather: Bool?
    let downloadUrl: String?
    let manifestUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case lastModified = "last_modified"
        case fileHash = "file_hash"
        case fileSize = "file_size"
        case fileSizeMB = "file_size_mb"
        case databaseVersion = "database_version"
        case shootCount = "shoot_count"
        case generatedAt = "generated_at"
        case includesWeather = "includes_weather"
        case downloadUrl = "download_url"
        case manifestUrl = "manifest_url"
    }
}

class SQLiteService: ObservableObject {
    private let dbFileName = "shoots.sqlite"
    private var db: OpaquePointer?
    
    var databaseURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(dbFileName)
    }
    
    var bundledDatabaseURL: URL? {
        Bundle.main.url(forResource: "shoots", withExtension: "sqlite")
    }
    
    init() {
        setupDatabase()
        openDatabase()
    }
    
    deinit {
        closeDatabase()
    }
    
    private func setupDatabase() {
        // Always use the bundled database if it exists (to get latest weather data)
        if let bundledURL = bundledDatabaseURL {
            do {
                // Remove existing database if it exists
                if FileManager.default.fileExists(atPath: databaseURL.path) {
                    try FileManager.default.removeItem(at: databaseURL)
                    print("Removed old SQLite database from Documents directory")
                }
                
                // Copy fresh bundled database to Documents directory
                try FileManager.default.copyItem(at: bundledURL, to: databaseURL)
                print("Copied fresh bundled SQLite database to Documents directory")
            } catch {
                print("Failed to copy bundled database: \(error)")
            }
        }
    }
    
    private func openDatabase() {
        let dbPath = FileManager.default.fileExists(atPath: databaseURL.path) ? databaseURL.path : bundledDatabaseURL?.path ?? ""
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Unable to open database at path: \(dbPath)")
            if let error = sqlite3_errmsg(db) {
                print("Error: \(String(cString: error))")
            }
        } else {
            print("Successfully opened SQLite database at: \(dbPath)")
        }
    }
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    func downloadLatestDatabase(from urlString: String) async -> Bool {
        // First check the manifest to see if we need to update
        let manifestURL = urlString.replacingOccurrences(of: ".sqlite", with: "_manifest.json")
        
        if let shouldUpdate = await shouldUpdateDatabase(manifestURL: manifestURL) {
            if !shouldUpdate {
                print("📱 Database is up to date, skipping download")
                return false
            }
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return false
        }
        
        do {
            print("📥 Downloading database from: \(urlString)")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check response headers for metadata
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Response status: \(httpResponse.statusCode)")
                if let lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
                    print("📅 Last modified: \(lastModified)")
                    UserDefaults.standard.set(lastModified, forKey: "DatabaseLastModified")
                }
                if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length") {
                    print("💾 Size: \(contentLength) bytes")
                }
            }
            
            // Write to temporary file first
            let tempURL = databaseURL.appendingPathExtension("tmp")
            try data.write(to: tempURL)
            
            // Verify the downloaded database
            if verifyDatabase(at: tempURL) {
                // Close current database
                closeDatabase()
                
                // Replace with new database
                try FileManager.default.removeItem(at: databaseURL)
                try FileManager.default.moveItem(at: tempURL, to: databaseURL)
                
                // Reopen database
                openDatabase()
                
                // Save metadata
                saveManifestData(from: manifestURL)
                
                print("✅ Database updated successfully")
                return true
            } else {
                // Remove invalid temp file
                try? FileManager.default.removeItem(at: tempURL)
                print("❌ Downloaded database failed verification")
                return false
            }
        } catch {
            print("❌ Failed to download database: \(error)")
            return false
        }
    }
    
    private func shouldUpdateDatabase(manifestURL: String) async -> Bool? {
        guard let url = URL(string: manifestURL) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let manifest = try JSONDecoder().decode(DatabaseManifest.self, from: data)
            
            // Check if we have a stored hash
            if let storedHash = UserDefaults.standard.string(forKey: "DatabaseFileHash") {
                if storedHash == manifest.fileHash {
                    print("📱 Database hash matches, no update needed")
                    return false
                }
            }
            
            // Check if we have a stored last modified date
            if let storedDate = UserDefaults.standard.string(forKey: "DatabaseLastModified") {
                if storedDate == manifest.lastModified {
                    print("📱 Database last modified matches, no update needed")
                    return false
                }
            }
            
            print("📥 New database available:")
            print("   Version: \(manifest.databaseVersion ?? "unknown")")
            print("   Shoots: \(manifest.shootCount ?? 0)")
            print("   Size: \(manifest.fileSizeMB ?? 0) MB")
            
            return true
        } catch {
            print("⚠️ Could not check manifest: \(error)")
            return nil
        }
    }
    
    private func saveManifestData(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let manifest = try JSONDecoder().decode(DatabaseManifest.self, from: data)
                
                UserDefaults.standard.set(manifest.fileHash, forKey: "DatabaseFileHash")
                UserDefaults.standard.set(manifest.lastModified, forKey: "DatabaseLastModified")
                UserDefaults.standard.set(manifest.databaseVersion, forKey: "DatabaseVersion")
                UserDefaults.standard.synchronize()
                
                print("📝 Saved manifest data")
            } catch {
                print("⚠️ Could not save manifest data: \(error)")
            }
        }
    }
    
    private func verifyDatabase(at url: URL) -> Bool {
        var tempDB: OpaquePointer?
        
        // Try to open the database
        if sqlite3_open(url.path, &tempDB) == SQLITE_OK {
            defer { sqlite3_close(tempDB) }
            
            // Try to query the shoots table
            let querySQL = "SELECT COUNT(*) FROM shoots LIMIT 1"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(tempDB, querySQL, -1, &statement, nil) == SQLITE_OK {
                defer { sqlite3_finalize(statement) }
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    let count = sqlite3_column_int(statement, 0)
                    print("✅ Database verification passed: \(count) shoots found")
                    return count > 0
                }
            }
        }
        
        print("❌ Database verification failed")
        return false
    }
    
    // Load shoots by specific IDs (for marked shoots that may be outside normal date range)
    func loadShootsByIds(_ ids: Set<Int>) -> [Shoot] {
        guard db != nil, !ids.isEmpty else {
            return []
        }
        
        var shoots: [Shoot] = []
        let idList = ids.map { String($0) }.joined(separator: ",")
        let querySQL = """
            SELECT "Shoot ID", 
                   TRIM("Shoot Name") as "Shoot Name", 
                   TRIM("Shoot Type") as "Shoot Type", 
                   "Start Date", "End Date",
                   TRIM("Club Name") as "Club Name", 
                   CASE 
                     WHEN TRIM(COALESCE("Address 1", '')) = '' AND TRIM(COALESCE("Address 2", '')) = '' THEN ''
                     WHEN TRIM(COALESCE("Address 1", '')) = '' THEN TRIM("Address 2")
                     WHEN TRIM(COALESCE("Address 2", '')) = '' THEN TRIM("Address 1")
                     ELSE TRIM("Address 1") || CHAR(10) || TRIM("Address 2")
                   END as "Address",
                   TRIM("City") as "City", 
                   TRIM("State") as "State", 
                   TRIM("Zip") as "Zip",
                   TRIM("Country") as "Country", 
                   "Zone", 
                   TRIM("Club E-Mail") as "Club E-Mail", 
                   TRIM("POC Name") as "POC Name", 
                   TRIM("POC Phone") as "POC Phone",
                   TRIM("POC E-Mail") as "POC E-Mail", 
                   "ClubID", 
                   TRIM("Event Type") as "Event Type", 
                   TRIM("Region") as "Region", 
                   TRIM("full_address") as "full_address",
                   "latitude", "longitude",
                   CASE 
                     WHEN LOWER(TRIM("Shoot Type")) LIKE '%world%' THEN 3
                     WHEN LOWER(TRIM("Shoot Type")) LIKE '%state%' THEN 2
                     WHEN TRIM("Shoot Type") IS NOT NULL AND LOWER(TRIM("Shoot Type")) != 'none' AND TRIM("Shoot Type") != '' THEN 1
                     ELSE 0
                   END as notability_level,
                   "morning_temp_f", "afternoon_temp_f", "morning_temp_c", "afternoon_temp_c", 
                   "duration_days", "morning_temp_band", "afternoon_temp_band", "estimation_method"
            FROM shoots
            WHERE "Shoot ID" IN (\(idList))
            ORDER BY "Start Date" ASC
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let shootId = Int(sqlite3_column_int(statement, 0))
                let shootName = String(cString: sqlite3_column_text(statement, 1))
                let shootType = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)) : nil
                let startDateStr = String(cString: sqlite3_column_text(statement, 3))
                let endDateStr = sqlite3_column_text(statement, 4) != nil ? String(cString: sqlite3_column_text(statement, 4)) : nil
                let clubName = String(cString: sqlite3_column_text(statement, 5))
                let address = sqlite3_column_text(statement, 6) != nil ? String(cString: sqlite3_column_text(statement, 6)) : nil
                let city = sqlite3_column_text(statement, 7) != nil ? String(cString: sqlite3_column_text(statement, 7)) : nil
                let state = sqlite3_column_text(statement, 8) != nil ? String(cString: sqlite3_column_text(statement, 8)) : nil
                let zip = sqlite3_column_text(statement, 9) != nil ? String(cString: sqlite3_column_text(statement, 9)) : nil
                let country = sqlite3_column_text(statement, 10) != nil ? String(cString: sqlite3_column_text(statement, 10)) : nil
                let zone = sqlite3_column_type(statement, 11) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 11)) : nil
                let clubEmail = sqlite3_column_text(statement, 12) != nil ? String(cString: sqlite3_column_text(statement, 12)) : nil
                let pocName = sqlite3_column_text(statement, 13) != nil ? String(cString: sqlite3_column_text(statement, 13)) : nil
                let pocPhone = sqlite3_column_text(statement, 14) != nil ? String(cString: sqlite3_column_text(statement, 14)) : nil
                let pocEmail = sqlite3_column_text(statement, 15) != nil ? String(cString: sqlite3_column_text(statement, 15)) : nil
                let clubID = sqlite3_column_type(statement, 16) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 16)) : nil
                let eventType = sqlite3_column_text(statement, 17) != nil ? String(cString: sqlite3_column_text(statement, 17)) : nil
                let region = sqlite3_column_text(statement, 18) != nil ? String(cString: sqlite3_column_text(statement, 18)) : nil
                let fullAddress = sqlite3_column_text(statement, 19) != nil ? String(cString: sqlite3_column_text(statement, 19)) : nil
                let latitude = sqlite3_column_type(statement, 20) != SQLITE_NULL ? sqlite3_column_double(statement, 20) : nil
                let longitude = sqlite3_column_type(statement, 21) != SQLITE_NULL ? sqlite3_column_double(statement, 21) : nil
                let notabilityLevel = Int(sqlite3_column_int(statement, 22))
                
                // Temperature data (columns 23-26)
                let morningTempF = sqlite3_column_type(statement, 23) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 23)) : nil
                let afternoonTempF = sqlite3_column_type(statement, 24) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 24)) : nil
                let morningTempC = sqlite3_column_type(statement, 25) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 25)) : nil
                let afternoonTempC = sqlite3_column_type(statement, 26) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 26)) : nil
                let durationDays = sqlite3_column_type(statement, 27) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 27)) : nil
                let morningTempBand = sqlite3_column_text(statement, 28) != nil ? String(cString: sqlite3_column_text(statement, 28)) : nil
                let afternoonTempBand = sqlite3_column_text(statement, 29) != nil ? String(cString: sqlite3_column_text(statement, 29)) : nil
                let estimationMethod = sqlite3_column_text(statement, 30) != nil ? String(cString: sqlite3_column_text(statement, 30)) : nil
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                guard let startDate = dateFormatter.date(from: startDateStr) else {
                    continue
                }
                
                let shoot = Shoot(
                    id: shootId,
                    shootName: shootName,
                    shootType: shootType,
                    startDate: startDate,
                    endDate: endDateStr != nil ? dateFormatter.date(from: endDateStr!) : nil,
                    clubName: clubName,
                    address1: address,
                    address2: nil,
                    city: city,
                    state: state,
                    zip: zip,
                    country: country,
                    zone: zone,
                    clubEmail: clubEmail,
                    pocName: pocName,
                    pocPhone: pocPhone,
                    pocEmail: pocEmail,
                    clubID: clubID,
                    eventType: eventType,
                    region: region,
                    fullAddress: fullAddress,
                    latitude: latitude,
                    longitude: longitude,
                    notabilityLevelRaw: notabilityLevel,
                    morningTempF: morningTempF,
                    afternoonTempF: afternoonTempF,
                    morningTempC: morningTempC,
                    afternoonTempC: afternoonTempC,
                    durationDays: durationDays,
                    morningTempBand: morningTempBand,
                    afternoonTempBand: afternoonTempBand,
                    estimationMethod: estimationMethod,
                    isMarked: true // These are marked shoots
                )
                shoots.append(shoot)
            }
        }
        
        sqlite3_finalize(statement)
        print("🗄️ Loaded \(shoots.count) marked shoots by IDs from SQLite")
        return shoots
    }
    
    func loadShoots() -> [Shoot] {
        guard db != nil else {
            print("Database not available, returning empty array")
            return []
        }
        
        var shoots: [Shoot] = []
        let currentYear = Calendar.current.component(.year, from: Date())
        let querySQL = """
            SELECT "Shoot ID", 
                   TRIM("Shoot Name") as "Shoot Name", 
                   TRIM("Shoot Type") as "Shoot Type", 
                   "Start Date", "End Date",
                   TRIM("Club Name") as "Club Name", 
                   CASE 
                     WHEN TRIM(COALESCE("Address 1", '')) = '' AND TRIM(COALESCE("Address 2", '')) = '' THEN ''
                     WHEN TRIM(COALESCE("Address 1", '')) = '' THEN TRIM("Address 2")
                     WHEN TRIM(COALESCE("Address 2", '')) = '' THEN TRIM("Address 1")
                     ELSE TRIM("Address 1") || CHAR(10) || TRIM("Address 2")
                   END as "Address",
                   TRIM("City") as "City", 
                   TRIM("State") as "State", 
                   TRIM("Zip") as "Zip",
                   TRIM("Country") as "Country", 
                   "Zone", 
                   TRIM("Club E-Mail") as "Club E-Mail", 
                   TRIM("POC Name") as "POC Name", 
                   TRIM("POC Phone") as "POC Phone",
                   TRIM("POC E-Mail") as "POC E-Mail", 
                   "ClubID", 
                   TRIM("Event Type") as "Event Type", 
                   TRIM("Region") as "Region", 
                   TRIM("full_address") as "full_address",
                   "latitude", "longitude",
                   CASE 
                     WHEN LOWER(TRIM("Shoot Type")) LIKE '%world%' THEN 3
                     WHEN LOWER(TRIM("Shoot Type")) LIKE '%state%' THEN 2
                     WHEN TRIM("Shoot Type") IS NOT NULL AND LOWER(TRIM("Shoot Type")) != 'none' AND TRIM("Shoot Type") != '' THEN 1
                     ELSE 0
                   END as notability_level,
                   "morning_temp_f", "afternoon_temp_f", "morning_temp_c", "afternoon_temp_c", 
                   "duration_days", "morning_temp_band", "afternoon_temp_band", "estimation_method"
            FROM shoots
            WHERE strftime('%Y', "Start Date") >= '\(currentYear)'
            ORDER BY "Start Date" ASC
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                // Safely extract values with null checks
                let shootId = Int(sqlite3_column_int(statement, 0))
                let shootName = sqlite3_column_text(statement, 1) != nil ? String(cString: sqlite3_column_text(statement, 1)!) : "Unknown Shoot"
                let shootType = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)!) : nil
                let startDateStr = sqlite3_column_text(statement, 3) != nil ? String(cString: sqlite3_column_text(statement, 3)!) : ""
                let endDateStr = sqlite3_column_text(statement, 4) != nil ? String(cString: sqlite3_column_text(statement, 4)!) : nil
                let clubName = sqlite3_column_text(statement, 5) != nil ? String(cString: sqlite3_column_text(statement, 5)!) : "Unknown Club"
                let address = sqlite3_column_text(statement, 6) != nil ? String(cString: sqlite3_column_text(statement, 6)!) : nil
                let city = sqlite3_column_text(statement, 7) != nil ? String(cString: sqlite3_column_text(statement, 7)!) : nil
                let state = sqlite3_column_text(statement, 8) != nil ? String(cString: sqlite3_column_text(statement, 8)!) : nil
                let zip = sqlite3_column_text(statement, 9) != nil ? String(cString: sqlite3_column_text(statement, 9)!) : nil
                let country = sqlite3_column_text(statement, 10) != nil ? String(cString: sqlite3_column_text(statement, 10)!) : nil
                let zone = sqlite3_column_type(statement, 11) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 11)) : nil
                let clubEmail = sqlite3_column_text(statement, 12) != nil ? String(cString: sqlite3_column_text(statement, 12)!) : nil
                let pocName = sqlite3_column_text(statement, 13) != nil ? String(cString: sqlite3_column_text(statement, 13)!) : nil
                let pocPhone = sqlite3_column_text(statement, 14) != nil ? String(cString: sqlite3_column_text(statement, 14)!) : nil
                let pocEmail = sqlite3_column_text(statement, 15) != nil ? String(cString: sqlite3_column_text(statement, 15)!) : nil
                let clubID = sqlite3_column_type(statement, 16) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 16)) : nil
                let eventType = sqlite3_column_text(statement, 17) != nil ? String(cString: sqlite3_column_text(statement, 17)!) : nil
                let region = sqlite3_column_text(statement, 18) != nil ? String(cString: sqlite3_column_text(statement, 18)!) : nil
                let fullAddress = sqlite3_column_text(statement, 19) != nil ? String(cString: sqlite3_column_text(statement, 19)!) : nil
                let latitude = sqlite3_column_type(statement, 20) != SQLITE_NULL ? sqlite3_column_double(statement, 20) : nil
                let longitude = sqlite3_column_type(statement, 21) != SQLITE_NULL ? sqlite3_column_double(statement, 21) : nil
                let notabilityLevel = Int(sqlite3_column_int(statement, 22))
                
                // Weather fields
                let morningTempF = sqlite3_column_type(statement, 23) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 23)) : nil
                let afternoonTempF = sqlite3_column_type(statement, 24) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 24)) : nil
                let morningTempC = sqlite3_column_type(statement, 25) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 25)) : nil
                let afternoonTempC = sqlite3_column_type(statement, 26) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 26)) : nil
                let durationDays = sqlite3_column_type(statement, 27) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 27)) : nil
                let morningTempBand = sqlite3_column_text(statement, 28) != nil ? String(cString: sqlite3_column_text(statement, 28)!) : nil
                let afternoonTempBand = sqlite3_column_text(statement, 29) != nil ? String(cString: sqlite3_column_text(statement, 29)!) : nil
                let estimationMethod = sqlite3_column_text(statement, 30) != nil ? String(cString: sqlite3_column_text(statement, 30)!) : nil
                
                let shoot = Shoot(
                    id: shootId,
                    shootName: shootName,
                    shootType: shootType,
                    startDate: dateFromString(startDateStr),
                    endDate: endDateStr != nil ? dateFromString(endDateStr!) : nil,
                    clubName: clubName,
                    address1: address,
                    address2: nil,
                    city: city,
                    state: state,
                    zip: zip,
                    country: country,
                    zone: zone,
                    clubEmail: clubEmail,
                    pocName: pocName,
                    pocPhone: pocPhone,
                    pocEmail: pocEmail,
                    clubID: clubID,
                    eventType: eventType,
                    region: region,
                    fullAddress: fullAddress,
                    latitude: latitude,
                    longitude: longitude,
                    notabilityLevelRaw: notabilityLevel,
                    morningTempF: morningTempF,
                    afternoonTempF: afternoonTempF,
                    morningTempC: morningTempC,
                    afternoonTempC: afternoonTempC,
                    durationDays: durationDays,
                    morningTempBand: morningTempBand,
                    afternoonTempBand: afternoonTempBand,
                    estimationMethod: estimationMethod,
                    isMarked: false
                )
                shoots.append(shoot)
            }
        } else {
            if let error = sqlite3_errmsg(db) {
                print("SELECT statement could not be prepared: \(String(cString: error))")
            }
        }
        
        sqlite3_finalize(statement)
        print("🗄️ Successfully loaded \(shoots.count) shoots from SQLite database (from \(currentYear) onwards)")
        
        if shoots.count > 0 {
            let yearCounts = Dictionary(grouping: shoots, by: { Calendar.current.component(.year, from: $0.startDate) })
                .mapValues { $0.count }
                .sorted { $0.key < $1.key }
            
            print("🗄️ Shoots by year:")
            for (year, count) in yearCounts {
                print("🗄️   \(year): \(count) shoots")
            }
            
            print("🗄️ Sample shoot dates:")
            for shoot in shoots.prefix(3) {
                print("🗄️   \(shoot.shootName): \(shoot.startDate)")
            }
        }
        
        return shoots
    }
    
    private func dateFromString(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }
}