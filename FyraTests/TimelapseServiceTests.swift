//
//  TimelapseServiceTests.swift
//  FyraTests
//

import XCTest
@testable import Fyra

final class TimelapseServiceTests: XCTestCase {
    func testFramesSelectsPoseAndRange() {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        let before = calendar.date(byAdding: .day, value: -10, to: base)!
        let inRange1 = calendar.date(byAdding: .day, value: -4, to: base)!
        let inRange2 = calendar.date(byAdding: .day, value: -2, to: base)!
        let range = DateInterval(start: calendar.date(byAdding: .day, value: -5, to: base)!, end: base)

        let c1 = CheckIn(date: before, weight: 70, frontPhotoPath: "a.jpg")
        let c2 = CheckIn(date: inRange1, weight: 71, frontPhotoPath: "b.jpg")
        let c3 = CheckIn(date: inRange2, weight: 72, sidePhotoPath: "side.jpg")
        let c4 = CheckIn(date: inRange2, weight: 73, frontPhotoPath: "c.jpg")

        let frames = TimelapseService.frames(
            checkIns: [c1, c2, c3, c4],
            pose: .front,
            range: range,
            overlayWeight: false,
            unit: .lb
        )

        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].imagePath, "b.jpg")
        XCTAssertEqual(frames[1].imagePath, "c.jpg")
        XCTAssertTrue(frames[0].date <= frames[1].date)
    }
}
