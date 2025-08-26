//
//  UserDataManagerTests.swift
//  ShootScheduleTests
//
//  Created on 1/25/25.
//

import XCTest
@testable import ShootSchedule

final class UserDataManagerTests: XCTestCase {
    var userDataManager: UserDataManager!
    
    override func setUpWithError() throws {
        userDataManager = UserDataManager()
        // Clear any existing test data
        userDataManager.clearAllData()
    }
    
    override func tearDownWithError() throws {
        // Clean up after tests
        userDataManager.clearAllData()
        userDataManager = nil
    }
    
    func testInitialUserData() throws {
        let userData = userDataManager.userData
        
        XCTAssertNotNil(userData.user.uuid, "User should have a UUID")
        XCTAssertFalse(userData.user.uuid.isEmpty, "UUID should not be empty")
        XCTAssertTrue(userData.user.temp, "User should be temp by default")
        XCTAssertTrue(userData.marked.isEmpty, "Marked array should be empty initially")
    }
    
    func testMarkShoot() throws {
        let testShootId = 12345
        
        userDataManager.markShoot(id: testShootId)
        
        let userData = userDataManager.userData
        XCTAssertTrue(userData.marked.contains(testShootId), "Marked array should contain the shoot ID")
        XCTAssertTrue(userDataManager.isShootMarked(id: testShootId), "isShootMarked should return true")
    }
    
    func testUnmarkShoot() throws {
        let testShootId = 12345
        
        // First mark it
        userDataManager.markShoot(id: testShootId)
        XCTAssertTrue(userDataManager.isShootMarked(id: testShootId), "Shoot should be marked")
        
        // Then unmark it
        userDataManager.unmarkShoot(id: testShootId)
        XCTAssertFalse(userDataManager.isShootMarked(id: testShootId), "Shoot should be unmarked")
        
        let userData = userDataManager.userData
        XCTAssertFalse(userData.marked.contains(testShootId), "Marked array should not contain the shoot ID")
    }
    
    func testMultipleMarkedShoots() throws {
        let shootIds = [1, 2, 3, 4, 5]
        
        // Mark multiple shoots
        for id in shootIds {
            userDataManager.markShoot(id: id)
        }
        
        // Verify all are marked
        for id in shootIds {
            XCTAssertTrue(userDataManager.isShootMarked(id: id), "Shoot \(id) should be marked")
        }
        
        let userData = userDataManager.userData
        XCTAssertEqual(userData.marked.count, shootIds.count, "Should have correct number of marked shoots")
        
        for id in shootIds {
            XCTAssertTrue(userData.marked.contains(id), "Marked array should contain shoot \(id)")
        }
    }
    
    func testFilterSettingsPersistence() throws {
        var userData = userDataManager.userData
        
        // Modify filter settings
        userData.filterSettings.search = "test search"
        userData.filterSettings.shootTypes = ["State Championship", "Regional"]
        userData.filterSettings.months = [6, 7, 8]
        userData.filterSettings.states = ["CA", "TX", "FL"]
        userData.filterSettings.notable = true
        userData.filterSettings.future = false
        userData.filterSettings.marked = true
        
        // Save changes
        userDataManager.userData = userData
        
        // Reload and verify persistence
        let reloadedData = userDataManager.userData
        XCTAssertEqual(reloadedData.filterSettings.search, "test search")
        XCTAssertEqual(reloadedData.filterSettings.shootTypes, ["State Championship", "Regional"])
        XCTAssertEqual(reloadedData.filterSettings.months, [6, 7, 8])
        XCTAssertEqual(reloadedData.filterSettings.states, ["CA", "TX", "FL"])
        XCTAssertTrue(reloadedData.filterSettings.notable)
        XCTAssertFalse(reloadedData.filterSettings.future)
        XCTAssertTrue(reloadedData.filterSettings.marked)
    }
    
    func testUserProfilePersistence() throws {
        var userData = userDataManager.userData
        
        // Modify user profile
        userData.user.temp = false
        
        // Save changes
        userDataManager.userData = userData
        
        // Reload and verify
        let reloadedData = userDataManager.userData
        XCTAssertFalse(reloadedData.user.temp, "User temp status should persist")
        XCTAssertEqual(reloadedData.user.uuid, userData.user.uuid, "UUID should remain the same")
    }
    
    func testDataPersistenceAcrossInstances() throws {
        let testShootId = 99999
        
        // Mark a shoot with first instance
        userDataManager.markShoot(id: testShootId)
        XCTAssertTrue(userDataManager.isShootMarked(id: testShootId))
        
        // Create new instance (simulating app restart)
        let newUserDataManager = UserDataManager()
        
        // Verify data persisted
        XCTAssertTrue(newUserDataManager.isShootMarked(id: testShootId), "Marked shoot should persist across instances")
        
        // Clean up
        newUserDataManager.clearAllData()
    }
    
    func testJSONSerialization() throws {
        // Mark some shoots and set filter preferences
        userDataManager.markShoot(id: 1)
        userDataManager.markShoot(id: 2)
        
        var userData = userDataManager.userData
        userData.filterSettings.search = "test"
        userData.filterSettings.notable = true
        userDataManager.userData = userData
        
        // Export to JSON
        let jsonData = try userDataManager.exportToJSON()
        XCTAssertNotNil(jsonData, "Should be able to export to JSON")
        
        // Verify JSON structure
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        XCTAssertTrue(jsonObject is [String: Any], "JSON should be a dictionary")
        
        if let json = jsonObject as? [String: Any] {
            XCTAssertNotNil(json["user"], "JSON should contain user object")
            XCTAssertNotNil(json["marked"], "JSON should contain marked array")
            XCTAssertNotNil(json["filterSettings"], "JSON should contain filterSettings object")
        }
    }
    
    func testImportFromJSON() throws {
        // Create test JSON data
        let testData = """
        {
            "user": {
                "uuid": "test-uuid-12345",
                "temp": false
            },
            "marked": [100, 200, 300],
            "filterSettings": {
                "search": "imported search",
                "shootTypes": ["Championship"],
                "months": [6, 7],
                "states": ["CA", "NY"],
                "notable": true,
                "future": false,
                "marked": true
            }
        }
        """.data(using: .utf8)!
        
        // Import the data
        try userDataManager.importFromJSON(testData)
        
        // Verify imported data
        let userData = userDataManager.userData
        XCTAssertEqual(userData.user.uuid, "test-uuid-12345")
        XCTAssertFalse(userData.user.temp)
        XCTAssertEqual(userData.marked, [100, 200, 300])
        XCTAssertEqual(userData.filterSettings.search, "imported search")
        XCTAssertEqual(userData.filterSettings.shootTypes, ["Championship"])
        XCTAssertEqual(userData.filterSettings.months, [6, 7])
        XCTAssertEqual(userData.filterSettings.states, ["CA", "NY"])
        XCTAssertTrue(userData.filterSettings.notable)
        XCTAssertFalse(userData.filterSettings.future)
        XCTAssertTrue(userData.filterSettings.marked)
    }
}