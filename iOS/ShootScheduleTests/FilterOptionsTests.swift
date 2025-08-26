//
//  FilterOptionsTests.swift
//  ShootScheduleTests
//
//  Created on 1/25/25.
//

import XCTest
@testable import ShootSchedule

final class FilterOptionsTests: XCTestCase {
    var filterOptions: FilterOptions!
    var testShoots: [Shoot]!
    
    override func setUpWithError() throws {
        filterOptions = FilterOptions()
        testShoots = createTestShoots()
    }
    
    override func tearDownWithError() throws {
        filterOptions = nil
        testShoots = nil
    }
    
    private func createTestShoots() -> [Shoot] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return [
            // Future NSCA shoot in CA
            Shoot(id: 1, shootName: "Test NSCA Shoot", shootType: "State Championship", 
                  startDate: formatter.date(from: "2025-06-15")!, endDate: nil,
                  clubName: "Test Club", address1: nil, address2: nil, city: "Los Angeles", 
                  state: "CA", zip: nil, country: "USA", zone: nil, clubEmail: nil,
                  pocName: nil, pocPhone: nil, pocEmail: nil, clubID: nil,
                  eventType: "NSCA", region: nil, fullAddress: nil,
                  latitude: 34.0522, longitude: -118.2437, isMarked: false),
            
            // Past NSSA shoot in TX
            Shoot(id: 2, shootName: "Past Texas Shoot", shootType: nil,
                  startDate: formatter.date(from: "2024-03-10")!, endDate: nil,
                  clubName: "Texas Club", address1: nil, address2: nil, city: "Dallas",
                  state: "TX", zip: nil, country: "USA", zone: nil, clubEmail: nil,
                  pocName: nil, pocPhone: nil, pocEmail: nil, clubID: nil,
                  eventType: "NSSA", region: nil, fullAddress: nil,
                  latitude: 32.7767, longitude: -96.7970, notabilityLevelRaw: nil, isMarked: true),
            
            // Future ATA shoot in FL
            Shoot(id: 3, shootName: "Florida Championship", shootType: "State Championship",
                  startDate: formatter.date(from: "2025-09-20")!, endDate: nil,
                  clubName: "Florida Club", address1: nil, address2: nil, city: "Miami",
                  state: "FL", zip: nil, country: "USA", zone: nil, clubEmail: nil,
                  pocName: nil, pocPhone: nil, pocEmail: nil, clubID: nil,
                  eventType: "ATA", region: nil, fullAddress: nil,
                  latitude: 25.7617, longitude: -80.1918, notabilityLevelRaw: nil, isMarked: false),
            
            // Future NSCA shoot in NY (no coordinates)
            Shoot(id: 4, shootName: "New York Open", shootType: nil,
                  startDate: formatter.date(from: "2025-12-05")!, endDate: nil,
                  clubName: "NYC Club", address1: nil, address2: nil, city: "New York",
                  state: "NY", zip: nil, country: "USA", zone: nil, clubEmail: nil,
                  pocName: nil, pocPhone: nil, pocEmail: nil, clubID: nil,
                  eventType: "NSCA", region: nil, fullAddress: nil,
                  latitude: nil, longitude: nil, isMarked: true)
        ]
    }
    
    func testDefaultFilterState() throws {
        let filtered = filterOptions.apply(to: testShoots)
        XCTAssertEqual(filtered.count, testShoots.count, "Default filter should return all shoots")
    }
    
    func testSearchTextFilter() throws {
        filterOptions.searchText = "california"
        let filtered = filterOptions.apply(to: testShoots)
        XCTAssertEqual(filtered.count, 0, "Case-insensitive search should work for city names")
        
        filterOptions.searchText = "Test"
        let filtered2 = filterOptions.apply(to: testShoots)
        XCTAssertEqual(filtered2.count, 2, "Search should match shoot names and club names")
    }
    
    func testEventTypeFilter() throws {
        filterOptions.selectedAffiliations = [.NSCA]
        let filtered = filterOptions.apply(to: testShoots)
        
        XCTAssertEqual(filtered.count, 2, "Should filter to only NSCA shoots")
        XCTAssertTrue(filtered.allSatisfy { $0.eventType == "NSCA" }, "All filtered shoots should be NSCA")
    }
    
    func testMultipleEventTypeFilter() throws {
        filterOptions.selectedAffiliations = [.NSCA, .ATA]
        let filtered = filterOptions.apply(to: testShoots)
        
        XCTAssertEqual(filtered.count, 3, "Should include both NSCA and ATA shoots")
        XCTAssertTrue(filtered.allSatisfy { $0.eventType == "NSCA" || $0.eventType == "ATA" })
    }
    
    func testStateFilter() throws {
        filterOptions.selectedStates = ["CA", "TX"]
        let filtered = filterOptions.apply(to: testShoots)
        
        XCTAssertEqual(filtered.count, 2, "Should filter to CA and TX shoots")
        XCTAssertTrue(filtered.allSatisfy { $0.state == "CA" || $0.state == "TX" })
    }
    
    func testMonthFilter() throws {
        filterOptions.selectedMonths = [6, 9] // June and September
        let filtered = filterOptions.apply(to: testShoots)
        
        XCTAssertEqual(filtered.count, 2, "Should filter to June and September shoots")
        
        let calendar = Calendar.current
        for shoot in filtered {
            let month = calendar.component(.month, from: shoot.startDate)
            XCTAssertTrue(month == 6 || month == 9, "Filtered shoots should be in June or September")
        }
    }
    
    func testFutureOnlyFilter() throws {
        filterOptions.futureOnly = true
        let filtered = filterOptions.apply(to: testShoots)
        
        XCTAssertEqual(filtered.count, 3, "Should filter to future shoots only")
        XCTAssertTrue(filtered.allSatisfy { $0.startDate >= Date() }, "All filtered shoots should be in the future")
    }
    
    func testMarkedOnlyFilter() throws {
        filterOptions.markedOnly = true
        let filtered = filterOptions.apply(to: testShoots)
        
        XCTAssertEqual(filtered.count, 2, "Should filter to marked shoots only")
        XCTAssertTrue(filtered.allSatisfy { $0.isMarked }, "All filtered shoots should be marked")
    }
    
    func testNotableOnlyFilter() throws {
        filterOptions.notableOnly = true
        let filtered = filterOptions.apply(to: testShoots)
        
        // Notable shoots are those with coordinates and shoot type
        let expected = testShoots.filter { 
            $0.latitude != nil && $0.longitude != nil && $0.shootType != nil 
        }
        
        XCTAssertEqual(filtered.count, expected.count, "Should filter to notable shoots only")
    }
    
    func testCombinedFilters() throws {
        // Test combination: Future NSCA shoots in CA
        filterOptions.selectedAffiliations = [.NSCA]
        filterOptions.selectedStates = ["CA"]
        filterOptions.futureOnly = true
        
        let filtered = filterOptions.apply(to: testShoots)
        
        XCTAssertEqual(filtered.count, 1, "Should find exactly one future NSCA shoot in CA")
        let shoot = filtered.first!
        XCTAssertEqual(shoot.eventType, "NSCA")
        XCTAssertEqual(shoot.state, "CA")
        XCTAssertTrue(shoot.startDate >= Date())
    }
    
    func testResetFilters() throws {
        // Set some filters
        filterOptions.searchText = "test"
        filterOptions.selectedAffiliations = [.NSCA]
        filterOptions.selectedStates = ["CA"]
        filterOptions.selectedMonths = [6]
        filterOptions.futureOnly = true
        filterOptions.markedOnly = true
        filterOptions.notableOnly = true
        
        // Reset
        filterOptions.reset()
        
        // Verify all filters are cleared
        XCTAssertTrue(filterOptions.searchText.isEmpty)
        XCTAssertTrue(filterOptions.selectedAffiliations.isEmpty)
        XCTAssertTrue(filterOptions.selectedStates.isEmpty)
        XCTAssertTrue(filterOptions.selectedMonths.isEmpty)
        XCTAssertFalse(filterOptions.futureOnly)
        XCTAssertFalse(filterOptions.markedOnly)
        XCTAssertFalse(filterOptions.notableOnly)
        
        // Should return all shoots again
        let filtered = filterOptions.apply(to: testShoots)
        XCTAssertEqual(filtered.count, testShoots.count)
    }
}