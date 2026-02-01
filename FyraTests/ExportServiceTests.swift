//
//  ExportServiceTests.swift
//  FyraTests
//

import XCTest
@testable import Fyra

final class ExportServiceTests: XCTestCase {
    func testWeightCSVIncludesHeaderAndRows() {
        let calendar = Calendar.current
        let d1 = calendar.date(byAdding: .day, value: -2, to: Date())!
        let d2 = Date()
        let c1 = CheckIn(date: d1, weight: 70.5)
        let c2 = CheckIn(date: d2, weight: 71.0)
        let csv = ExportService.weightCSV(checkIns: [c1, c2], unit: .kg)
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.first, "date,weight,unit")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[1].hasPrefix("20"))
        XCTAssertTrue(lines[1].contains("70.5"))
        XCTAssertTrue(lines[1].contains("kg"))
    }

    func testWeightCSVExcludesCheckInsWithoutWeight() {
        let c1 = CheckIn(date: Date(), weight: nil)
        let c2 = CheckIn(date: Date().addingTimeInterval(86400), weight: 72)
        let csv = ExportService.weightCSV(checkIns: [c1, c2], unit: .lb)
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], "date,weight,unit")
        XCTAssertTrue(lines[1].contains("72"))
    }
}
