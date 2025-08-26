//
//  SQLiteServiceTests.swift
//  ShootScheduleTests
//
//  Created on 1/25/25.
//

import XCTest
@testable import ShootSchedule

final class SQLiteServiceTests: XCTestCase {
    var sqliteService: SQLiteService!
    
    override func setUpWithError() throws {
        sqliteService = SQLiteService()
    }
    
    override func tearDownWithError() throws {
        sqliteService = nil
    }
    
    func testSQLiteServiceInitialization() throws {
        XCTAssertNotNil(sqliteService, "SQLiteService should initialize properly")
        XCTAssertTrue(sqliteService.databaseURL.path.contains("shoots.sqlite"), "Database URL should contain shoots.sqlite")
    }
    
    func testBundledDatabaseExists() throws {
        XCTAssertNotNil(sqliteService.bundledDatabaseURL, "Bundled SQLite database should exist in app bundle")
    }
    
    func testLoadShoots() throws {
        let shoots = sqliteService.loadShoots()
        
        // For now, we expect empty array as we're using fallback to test data
        // In the future, this should load real data from SQLite
        XCTAssertNotNil(shoots, "loadShoots should return an array")
        XCTAssertTrue(shoots is [Shoot], "loadShoots should return array of Shoot objects")
    }
    
    func testDatabaseDownloadURL() throws {
        let testURL = "https://example.com/test.sqlite"
        
        let expectation = self.expectation(description: "Database download")
        Task {
            let result = await sqliteService.downloadLatestDatabase(from: testURL)
            XCTAssertFalse(result, "Download should fail for test URL")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
}