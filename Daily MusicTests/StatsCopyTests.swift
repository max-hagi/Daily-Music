//
//  StatsCopyTests.swift
//  Daily MusicTests
//

import XCTest
@testable import Daily_Music

final class StatsCopyTests: XCTestCase {

    func test_highRate_fanQualifier() {
        let result = featuredLineString(likes: 7, total: 10, likeRate: 0.70)
        XCTAssertEqual(result, "7 of 10 kept. You're basically a fan.")
    }

    func test_exactSixtyPercent_fanQualifier() {
        let result = featuredLineString(likes: 6, total: 10, likeRate: 0.60)
        XCTAssertEqual(result, "6 of 10 kept. You're basically a fan.")
    }

    func test_midRate_halfQualifier() {
        let result = featuredLineString(likes: 5, total: 10, likeRate: 0.50)
        XCTAssertEqual(result, "5 of 10 kept. About half make the cut.")
    }

    func test_exactFortyPercent_halfQualifier() {
        let result = featuredLineString(likes: 4, total: 10, likeRate: 0.40)
        XCTAssertEqual(result, "4 of 10 kept. About half make the cut.")
    }

    func test_lowRate_notYourThing() {
        let result = featuredLineString(likes: 2, total: 10, likeRate: 0.20)
        XCTAssertEqual(result, "2 of 10 kept. Not really your thing.")
    }

    func test_noEmDashes() {
        let rates: [(Int, Int, Double)] = [
            (7, 10, 0.70), (5, 10, 0.50), (2, 10, 0.20)
        ]
        for (likes, total, rate) in rates {
            let result = featuredLineString(likes: likes, total: total, likeRate: rate)
            XCTAssertFalse(result.contains("\u{2014}"), "Em-dash found: \(result)")
        }
    }
}
