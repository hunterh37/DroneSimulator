//
//  DemoDirectorTests.swift
//  DroneArenaTests
//
//  Headless coverage for the demo capture surface: stick synthesis signs,
//  closed-loop convergence through the same math DualThumbControlledSystem
//  applies, and that every built-in script decodes.
//

import XCTest
import simd
@testable import DroneArena

@MainActor
final class DemoDirectorTests: XCTestCase {

    func testTargetAheadGivesForwardOnly() {
        let s = DemoAutopilot.sticks(local: [0, 0, -2], speed: 1)
        XCTAssertGreaterThan(s.fwd, 0.9)
        XCTAssertEqual(s.yaw, 0, accuracy: 1e-4)
        XCTAssertEqual(s.strafe, 0, accuracy: 1e-4)
    }

    func testTargetLeftYawsLeftAndStrafesLeft() {
        let s = DemoAutopilot.sticks(local: [-2, 0, -0.5], speed: 1)
        XCTAssertGreaterThan(s.yaw, 0, "positive yaw = CCW about +Y = left turn")
        XCTAssertLessThan(s.strafe, 0)
    }

    func testTargetAboveThrottlesUp() {
        XCTAssertGreaterThan(DemoAutopilot.sticks(local: [0, 0.5, 0], speed: 1).thr, 0.9)
        XCTAssertLessThan(DemoAutopilot.sticks(local: [0, -0.5, 0], speed: 1).thr, -0.9)
    }

    /// Integrates the Mode-2 mapping (fwd -> local -Z, strafe -> +X, yaw about +Y)
    /// at 90 Hz and checks the autopilot settles within claw tolerance (3 cm).
    func testClosedLoopConvergesToTarget() {
        var pos = SIMD3<Float>(0, 0.3, -1.3)
        var q = simd_quatf(angle: 0, axis: [0, 1, 0])
        let target = SIMD3<Float>(1.2, 1.1, -3.0)
        let dt: Float = 1.0 / 90.0
        for _ in 0..<(90 * 8) {
            let s = DemoAutopilot.sticks(local: q.inverse.act(target - pos), speed: 0.8)
            let local = SIMD3<Float>(s.strafe * 2, s.thr * 2, -s.fwd * 2) * dt
            pos += q.act(local)
            q = q * simd_quatf(angle: s.yaw * 1.5 * dt, axis: [0, 1, 0])
            XCTAssertFalse(pos.x.isNaN || pos.y.isNaN || pos.z.isNaN)
        }
        XCTAssertLessThan(simd_distance(pos, target), 0.03)
    }

    func testBuiltInScriptsDecode() {
        for name in DemoScript.builtIn.keys {
            let ops = DemoScript.load(name)
            XCTAssertFalse(ops.isEmpty, "\(name) decoded empty")
            for op in ops where op.op == "mode" {
                XCTAssertNotNil(DemoDirector.mode(named: op.value ?? ""), "\(name): bad mode \(op.value ?? "nil")")
            }
        }
    }
}
