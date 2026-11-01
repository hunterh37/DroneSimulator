//
//  RaceLeagueTests.swift
//  DroneArenaTests
//

import XCTest
@testable import DroneArena

@MainActor
final class RaceLeagueTests: XCTestCase {

    func testTracksHaveRaceableLengthsAndGates() {
        for id in RaceTrackID.allCases {
            let t = RaceTrack(id)
            XCTAssertGreaterThan(t.length, 30, id.rawValue)
            XCTAssertLessThan(t.length, 110, id.rawValue)
            XCTAssertEqual(t.gates.count, id.gateCount)
            XCTAssertEqual(t.gates[0].s, 0)
            for g in t.gates { XCTAssertGreaterThan(g.position.y - g.halfSize, 0.1, "\(id.rawValue) gate \(g.index) clips floor") }
        }
    }

    func testGatesPassedCountsStartAndLaps() {
        let t = RaceTrack(.neonOval)
        let n = t.gates.count
        XCTAssertEqual(t.gatesPassed(at: -1), 0)
        XCTAssertEqual(t.gatesPassed(at: 0), 1)
        XCTAssertEqual(t.gatesPassed(at: t.length * 3), 3 * n + 1)
    }

    func testPointsTable() {
        XCTAssertEqual(RaceLeaguePoints.points(forPosition: 1), 25)
        XCTAssertEqual(RaceLeaguePoints.points(forPosition: 8), 4)
        XCTAssertEqual(RaceLeaguePoints.points(forPosition: 9), 0)
    }

    func testEveryLowPolyStyleBuildsGeometry() {
        for style in LowPolyDroneStyle.allCases {
            XCTAssertEqual(LowPolyDroneStyle.from(modelName: style.modelName), style)
            let e = LowPolyDroneFactory.make(style, livery: DroneLivery.presets[0])
            XCTAssertGreaterThan(e.children.count, 3, style.rawValue)
        }
    }
}
