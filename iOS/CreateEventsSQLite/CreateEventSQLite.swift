import Foundation
import SQLite3
import SwiftCSV

class SQLiteGenerator {
    static func generateDatabase(from csvPath: String, to dbPath: String) {
        guard let csv = try? CSV(url: URL(fileURLWithPath: csvPath)) else {
            print("Failed to read or parse CSV file at path: \(csvPath)")
            return
        }

        var db: OpaquePointer?
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Unable to open database.")
            return
        }

        defer {
            sqlite3_close(db)
        }

        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS Events (
            id INTEGER PRIMARY KEY,
            name TEXT,
            type TEXT,
            startDate TEXT,
            endDate TEXT,
            club TEXT,
            address1 TEXT,
            address2 TEXT,
            city TEXT,
            state TEXT,
            zip TEXT,
            country TEXT,
            zone TEXT,
            clubEmail TEXT,
            pocName TEXT,
            pocPhone TEXT,
            pocEmail TEXT,
            clubID INTEGER,
            eventType TEXT,
            region TEXT,
            fullAddress TEXT,
            latitude REAL,
            longitude REAL
        );
        """

        if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
            print("Failed to create table.")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for row in csv.namedRows {
            guard
                let id = Int(row["id"] ?? ""),
                let startDateString = row["startDate"],
                let endDateString = row["endDate"],
                let startDate = dateFormatter.date(from: startDateString),
                let endDate = dateFormatter.date(from: endDateString),
                let latitude = Double(row["latitude"] ?? ""),
                let longitude = Double(row["longitude"] ?? "")
            else {
                print("Skipping malformed row: \(row)")
                continue
            }

            let insertQuery = """
            INSERT INTO Events (
                id, name, type, startDate, endDate, club, address1, address2, city, state, zip,
                country, zone, clubEmail, pocName, pocPhone, pocEmail, clubID, eventType, region,
                fullAddress, latitude, longitude
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, Int32(id))
                sqlite3_bind_text(statement, 2, row["name"], -1, nil)
                sqlite3_bind_text(statement, 3, row["type"], -1, nil)
                sqlite3_bind_text(statement, 4, startDateString, -1, nil)
                sqlite3_bind_text(statement, 5, endDateString, -1, nil)
                sqlite3_bind_text(statement, 6, row["club"], -1, nil)
                sqlite3_bind_text(statement, 7, row["address1"], -1, nil)
                sqlite3_bind_text(statement, 8, row["address2"], -1, nil)
                sqlite3_bind_text(statement, 9, row["city"], -1, nil)
                sqlite3_bind_text(statement, 10, row["state"], -1, nil)
                sqlite3_bind_text(statement, 11, row["zip"], -1, nil)
                sqlite3_bind_text(statement, 12, row["country"], -1, nil)
                sqlite3_bind_text(statement, 13, row["zone"], -1, nil)
                sqlite3_bind_text(statement, 14, row["clubEmail"], -1, nil)
                sqlite3_bind_text(statement, 15, row["pocName"], -1, nil)
                sqlite3_bind_text(statement, 16, row["pocPhone"], -1, nil)
                sqlite3_bind_text(statement, 17, row["pocEmail"], -1, nil)
                sqlite3_bind_int(statement, 18, Int32(Int(row["clubID"] ?? "-1") ?? -1))
                sqlite3_bind_text(statement, 19, row["eventType"], -1, nil)
                sqlite3_bind_text(statement, 20, row["region"], -1, nil)
                sqlite3_bind_text(statement, 21, row["fullAddress"], -1, nil)
                sqlite3_bind_double(statement, 22, latitude)
                sqlite3_bind_double(statement, 23, longitude)

                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Failed to insert row: \(row)")
                }
            }
            sqlite3_finalize(statement)
        }

        print("Database generation complete.")
    }
}
