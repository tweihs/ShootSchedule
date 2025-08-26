//
//  DataManagerTests.swift
//  ShootScheduleTests
//
//  Created on 1/25/25.
//

import XCTest
@testable import ShootSchedule

final class DataManagerTests: XCTestCase {
    var dataManager: DataManager!
    
    override func setUpWithError() throws {
        dataManager = DataManager()
    }
    
    override func tearDownWithError() throws {
        dataManager = nil
    }
    
    func testDataManagerInitialization() throws {
        XCTAssertNotNil(dataManager, "DataManager should initialize properly")
        XCTAssertGreaterThan(dataManager.shoots.count, 0, "DataManager should load shoots on initialization")
    }
    
    func testShootDataIntegrity() throws {
        let shoots = dataManager.shoots
        
        XCTAssertGreaterThan(shoots.count, 50, "Should have comprehensive test data with 50+ shoots")
        
        // Test that all shoots have required fields
        for shoot in shoots {
            XCTAssertGreaterThan(shoot.id, 0, "Shoot ID should be positive")
            XCTAssertFalse(shoot.shootName.isEmpty, "Shoot name should not be empty")
            XCTAssertFalse(shoot.clubName.isEmpty, "Club name should not be empty")
            XCTAssertNotNil(shoot.eventType, "Event type should not be nil")
        }
    }
    
    func testEventTypeVariety() throws {
        let shoots = dataManager.shoots
        let eventTypes = Set(shoots.compactMap { $0.eventType })
        
        XCTAssertTrue(eventTypes.contains("NSCA"), "Should contain NSCA events")
        XCTAssertTrue(eventTypes.contains("NSSA"), "Should contain NSSA events")  
        XCTAssertTrue(eventTypes.contains("ATA"), "Should contain ATA events")
        XCTAssertEqual(eventTypes.count, 3, "Should have exactly 3 event types")
    }
    
    func testStateVariety() throws {
        let shoots = dataManager.shoots
        let states = Set(shoots.compactMap { $0.state })
        
        XCTAssertGreaterThanOrEqual(states.count, 40, "Should have shoots from at least 40 states")
        XCTAssertTrue(states.contains("CA"), "Should contain California shoots")
        XCTAssertTrue(states.contains("TX"), "Should contain Texas shoots")
        XCTAssertTrue(states.contains("NY"), "Should contain New York shoots")
    }
    
    func testDateRange() throws {
        let shoots = dataManager.shoots
        let dates = shoots.map { $0.startDate }
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        // Check for past and future dates
        let pastDates = dates.filter { calendar.component(.year, from: $0) < currentYear }
        let futureDates = dates.filter { calendar.component(.year, from: $0) >= currentYear }
        
        XCTAssertGreaterThan(pastDates.count, 0, "Should have past dates for testing")
        XCTAssertGreaterThan(futureDates.count, 0, "Should have future dates for testing")
    }
    
    func testMonthVariety() throws {
        let shoots = dataManager.shoots
        let months = Set(shoots.map { Calendar.current.component(.month, from: $0.startDate) })
        
        XCTAssertEqual(months.count, 12, "Should have shoots in all 12 months")
    }
    
    func testCoordinateData() throws {
        let shoots = dataManager.shoots
        let shootsWithCoordinates = shoots.filter { $0.latitude != nil && $0.longitude != nil }
        
        XCTAssertGreaterThan(shootsWithCoordinates.count, 0, "Should have shoots with coordinate data for mapping")
        
        // Test coordinate validity
        for shoot in shootsWithCoordinates {
            if let lat = shoot.latitude, let lng = shoot.longitude {
                XCTAssertTrue(lat >= -90 && lat <= 90, "Latitude should be valid")
                XCTAssertTrue(lng >= -180 && lng <= 180, "Longitude should be valid")
            }
        }
    }
    
    func testMarkShootFunctionality() throws {
        let shoot = dataManager.shoots.first!
        let initialMarkedState = shoot.isMarked
        
        // Test marking
        dataManager.markShoot(shoot)
        XCTAssertTrue(dataManager.isShootMarked(shoot), "Shoot should be marked after marking")
        
        // Test unmarking
        dataManager.unmarkShoot(shoot)
        XCTAssertFalse(dataManager.isShootMarked(shoot), "Shoot should be unmarked after unmarking")
        
        // Restore original state
        if initialMarkedState {
            dataManager.markShoot(shoot)
        }
    }
}