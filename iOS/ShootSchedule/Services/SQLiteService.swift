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
        // Only copy bundled database if no database exists in Documents directory
        // This ensures we don't overwrite a downloaded database with an older bundled one
        if !FileManager.default.fileExists(atPath: databaseURL.path) {
            // First time setup - copy bundled database if it exists
            if let bundledURL = bundledDatabaseURL {
                do {
                    // Copy bundled database to Documents directory for initial setup
                    try FileManager.default.copyItem(at: bundledURL, to: databaseURL)
                    print("📦 Initial setup: Copied bundled SQLite database to Documents directory")
                    
                    // Log the bundled database date for comparison
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path),
                       let modDate = attributes[.modificationDate] as? Date {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .medium
                        print("📦 Bundled database date: \(formatter.string(from: modDate))")
                    }
                } catch {
                    print("❌ Failed to copy bundled database: \(error)")
                }
            } else {
                print("⚠️ No bundled database found and no existing database in Documents")
            }
        } else {
            print("✅ Using existing SQLite database from Documents directory")
            
            // Log the existing database date
            if let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path),
               let modDate = attributes[.modificationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                print("📅 Existing database date: \(formatter.string(from: modDate))")
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
        // First check with HEAD request if we need to update
        print("\n🔍 Checking if database update is needed...")
        let headCheckResult = await shouldUpdateDatabaseUsingHeaders(urlString: urlString)
        
        if let shouldUpdate = headCheckResult {
            if !shouldUpdate {
                print("📱 Database is up to date (based on file timestamps), skipping download")
                return false
            }
            print("✅ Database update needed (local file is older), proceeding with download")
            // Clear the stored Last-Modified to force a fresh download
            // This ensures we don't get a 304 when we know the local file is stale
            UserDefaults.standard.removeObject(forKey: "DatabaseLastModified")
            UserDefaults.standard.removeObject(forKey: "DatabaseETag")
        } else {
            print("⚠️ Could not determine update status from HEAD request, proceeding with conditional download")
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return false
        }
        
        do {
            print("📥 Downloading database from: \(urlString)")
            
            // Create request - only use conditional headers if we're not sure about needing update
            var request = URLRequest(url: url)
            if headCheckResult == nil || headCheckResult == false {
                // Only use conditional headers if HEAD check was inconclusive or said no update
                // If HEAD check said we need update, we cleared the stored values above
                if let lastModified = UserDefaults.standard.string(forKey: "DatabaseLastModified") {
                    request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
                    print("📅 Using conditional download with If-Modified-Since: \(lastModified)")
                }
            } else {
                print("📥 Forcing fresh download (local file is stale)")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response headers
            var lastModifiedDate: Date?
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Response status: \(httpResponse.statusCode)")
                
                // If not modified, we're done
                if httpResponse.statusCode == 304 {
                    print("✅ Database not modified (304), keeping current version")
                    
                    // Still show the Last-Modified date from our stored value
                    if let lastModified = UserDefaults.standard.string(forKey: "DatabaseLastModified") {
                        print("📅 Server file last modified: \(lastModified)")
                        
                        // Parse and display in readable format
                        let dateFormatter = DateFormatter()
                        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                        if let serverDate = dateFormatter.date(from: lastModified) {
                            let displayFormatter = DateFormatter()
                            displayFormatter.dateStyle = .medium
                            displayFormatter.timeStyle = .medium
                            print("📅 Server file modification date: \(displayFormatter.string(from: serverDate))")
                            
                            // Show local file timestamp for comparison (diagnostic only)
                            if let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path),
                               let localModDate = attributes[.modificationDate] as? Date {
                                print("📅 Local file modification date: \(displayFormatter.string(from: localModDate))")
                                
                                // Just log the difference for diagnostics
                                let timeDiff = abs(serverDate.timeIntervalSince(localModDate))
                                if timeDiff > 60 { // More than 1 minute difference
                                    print("⚠️ Note: Local file timestamp differs from server by \(Int(timeDiff)) seconds")
                                    print("⚠️ This may indicate the file was downloaded before timestamp preservation was implemented")
                                }
                            }
                        }
                    }
                    return false
                }
                
                // Save new last modified date and etag
                if let lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
                    print("📅 New last modified header: \(lastModified)")
                    UserDefaults.standard.set(lastModified, forKey: "DatabaseLastModified")
                    
                    // Parse the Last-Modified header to get Date
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                    lastModifiedDate = dateFormatter.date(from: lastModified)
                    
                    if let date = lastModifiedDate {
                        let displayFormatter = DateFormatter()
                        displayFormatter.dateStyle = .medium
                        displayFormatter.timeStyle = .medium
                        print("📅 Parsed server modification date: \(displayFormatter.string(from: date))")
                        print("📅 Raw date: \(date)")
                    } else {
                        print("⚠️ Failed to parse Last-Modified date from: \(lastModified)")
                    }
                }
                if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                    print("🏷️ ETag: \(etag)")
                    UserDefaults.standard.set(etag, forKey: "DatabaseETag")
                }
                if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length") {
                    let sizeInMB = (Double(contentLength) ?? 0) / 1_048_576
                    print("💾 Size: \(String(format: "%.1f", sizeInMB)) MB (\(contentLength) bytes)")
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
                
                // Set the file's modification date to match the server's Last-Modified header
                if let lastModifiedDate = lastModifiedDate {
                    try FileManager.default.setAttributes([.modificationDate: lastModifiedDate], ofItemAtPath: databaseURL.path)
                    
                    let displayFormatter = DateFormatter()
                    displayFormatter.dateStyle = .medium
                    displayFormatter.timeStyle = .medium
                    print("📅 Set file modification date to: \(displayFormatter.string(from: lastModifiedDate))")
                    
                    // Verify it was set correctly
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path),
                       let fileModDate = attributes[.modificationDate] as? Date {
                        print("📅 Verified file modification date: \(displayFormatter.string(from: fileModDate))")
                    }
                }
                
                // Reopen database
                openDatabase()
                
                print("✅ Database updated successfully")
                
                // Post notification that database was updated
                NotificationCenter.default.post(name: Notification.Name("DatabaseUpdated"), object: nil)
                
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
    
    private func shouldUpdateDatabaseUsingHeaders(urlString: String) async -> Bool? {
        guard let url = URL(string: urlString) else {
            print("⚠️ Invalid URL")
            return nil
        }
        
        do {
            // Use HEAD request to check headers without downloading the file
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            
            // DON'T send If-Modified-Since or If-None-Match in HEAD request
            // We want to get the server's actual Last-Modified date to compare with our local file
            // Only send these headers when doing the actual download
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 HEAD request status: \(httpResponse.statusCode)")
                
                // Get the server's Last-Modified date
                if let serverLastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified") {
                    print("📅 Server Last-Modified header: \(serverLastModified)")
                    
                    // Parse server date
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                    
                    if let serverDate = dateFormatter.date(from: serverLastModified) {
                        let displayFormatter = DateFormatter()
                        displayFormatter.dateStyle = .medium
                        displayFormatter.timeStyle = .medium
                        print("📅 Server file modification date: \(displayFormatter.string(from: serverDate))")
                        
                        // Compare with local file's actual modification date
                        if let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path),
                           let localModDate = attributes[.modificationDate] as? Date {
                            print("📅 Local file modification date: \(displayFormatter.string(from: localModDate))")
                            
                            // If local file is older than server, we need to download
                            if localModDate < serverDate {
                                let timeDiff = Int(serverDate.timeIntervalSince(localModDate))
                                print("⚠️ Local file is \(timeDiff) seconds older than server")
                                print("📥 Need to download newer version from server")
                                
                                // DON'T update stored Last-Modified here - only after successful download
                                // UserDefaults.standard.set(serverLastModified, forKey: "DatabaseLastModified")
                                
                                return true // Need to download
                            } else if localModDate > serverDate {
                                // Local file is newer (shouldn't happen in normal flow)
                                let timeDiff = Int(localModDate.timeIntervalSince(serverDate))
                                print("⚠️ Local file is \(timeDiff) seconds newer than server")
                                print("✅ Keeping local version (newer than server)")
                                return false
                            } else {
                                // Same timestamp - need additional checks
                                print("📅 Local and server have same modification date")
                                
                                // Check file size
                                let localFileSize = (try? FileManager.default.attributesOfItem(atPath: databaseURL.path))?[.size] as? Int
                                if let serverSizeStr = httpResponse.value(forHTTPHeaderField: "Content-Length"),
                                   let serverFileSize = Int(serverSizeStr),
                                   let localSize = localFileSize {
                                    print("📊 Local file size: \(localSize) bytes")
                                    print("📊 Server file size: \(serverFileSize) bytes")
                                    
                                    if localSize != serverFileSize {
                                        print("⚠️ File sizes differ despite same timestamp!")
                                        print("📥 Need to download (size mismatch)")
                                        // DON'T update stored Last-Modified here - only after successful download
                                        return true
                                    }
                                }
                                
                                // Check ETag if available
                                if let serverETag = httpResponse.value(forHTTPHeaderField: "ETag") {
                                    print("🏷️ Server ETag: \(serverETag)")
                                    if let storedETag = UserDefaults.standard.string(forKey: "DatabaseETag") {
                                        print("🏷️ Stored ETag: \(storedETag)")
                                        if serverETag != storedETag {
                                            print("⚠️ ETags differ despite same timestamp!")
                                            print("📥 Need to download (ETag mismatch)")
                                            // DON'T update stored Last-Modified here - only after successful download
                                            return true
                                        }
                                    } else {
                                        // No stored ETag, can't compare
                                        print("⚠️ No stored ETag for comparison")
                                    }
                                }
                                
                                print("✅ Local file matches server (same date, size, and ETag)")
                                
                                // Don't update stored values here - they should match already
                                
                                return false // No need to download
                            }
                        } else {
                            // No local file or can't read attributes - need to download
                            print("⚠️ No local file or can't read attributes")
                            print("📥 Need to download from server")
                            
                            // DON'T store the server's Last-Modified here - only after successful download
                            
                            return true // Need to download
                        }
                    } else {
                        print("⚠️ Failed to parse server Last-Modified date")
                        // Can't compare dates, fall back to other checks
                    }
                } else {
                    print("⚠️ No Last-Modified header from server")
                }
                
                // Always check ETag as primary indicator if date check was inconclusive
                if let serverETag = httpResponse.value(forHTTPHeaderField: "ETag") {
                    print("🏷️ Server ETag: \(serverETag)")
                    
                    if let storedETag = UserDefaults.standard.string(forKey: "DatabaseETag") {
                        print("🏷️ Stored ETag: \(storedETag)")
                        
                        if serverETag == storedETag {
                            print("✅ ETag matches - database is current")
                            return false
                        } else {
                            print("⚠️ ETag changed - new database available!")
                            print("📥 Need to download (ETag mismatch)")
                            return true
                        }
                    } else {
                        print("⚠️ No stored ETag - assuming update needed")
                        return true
                    }
                }
                
                // Show file size if available
                if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length") {
                    let sizeInMB = (Double(contentLength) ?? 0) / 1_048_576
                    print("💾 Database size: \(String(format: "%.1f", sizeInMB)) MB")
                }
                
                return true // Should update
            }
            
            return nil // Couldn't determine
        } catch {
            print("⚠️ Could not check database headers: \(error)")
            return nil // On error, let the download proceed
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