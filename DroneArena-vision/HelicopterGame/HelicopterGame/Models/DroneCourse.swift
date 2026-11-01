//
//  DroneCourse.swift
//  HelicopterGame
//
//  Handcrafted hoop-on-post obstacle courses for Time Trial mode.
//  Gate positions are expressed relative to the course origin (the player's
//  drone position at the moment the course is spawned), with the player
//  assumed to be facing -Z. `yawDegrees` banks the hoop around the world Y
//  axis so the player has to fly through at an angle, like a real FPV track.
//

import Foundation
import simd

public struct CourseGateSpec {
    /// Hoop-center position relative to the course origin (meters). The post
    /// drops straight down from the hoop toward the floor.
    public let position: SIMD3<Float>
    /// Rotation of the hoop around the world Y axis (degrees).
    public let yawDegrees: Float
    /// Hoop opening radius (meters).
    public let ringRadius: Float

    public init(position: SIMD3<Float>, yawDegrees: Float = 0, ringRadius: Float = 0.55) {
        self.position = position
        self.yawDegrees = yawDegrees
        self.ringRadius = ringRadius
    }
}

public struct DroneCourse {
    public let gates: [CourseGateSpec]
    public let timeLimit: TimeInterval

    public init(gates: [CourseGateSpec], timeLimit: TimeInterval) {
        self.gates = gates
        self.timeLimit = timeLimit
    }

    /// A designed, flowing slalom course. Higher levels append extra gates and
    /// tighten the time budget so the mode still escalates per level, but the
    /// opening layout is always hand-placed.
    public static func handcrafted(level: Int) -> DroneCourse {
        // Base track — a gentle left/right slalom climbing and dipping in height.
        var gates: [CourseGateSpec] = [
            CourseGateSpec(position: [ 0.0, 1.3,  -3.0], yawDegrees:   0),
            CourseGateSpec(position: [ 1.2, 1.6,  -5.5], yawDegrees:  20),
            CourseGateSpec(position: [-1.0, 1.1,  -8.0], yawDegrees: -25),
            CourseGateSpec(position: [-1.8, 1.8, -10.5], yawDegrees: -10),
            CourseGateSpec(position: [ 0.5, 1.4, -13.0], yawDegrees:  15),
            CourseGateSpec(position: [ 1.6, 2.0, -15.5], yawDegrees:  30),
            CourseGateSpec(position: [ 0.0, 1.2, -18.0], yawDegrees:   0),
        ]

        // Extend the track for later levels with a few extra winding gates.
        let extra = max(0, level - 1) * 2
        var z: Float = -20.5
        var side: Float = -1
        for i in 0..<extra {
            let x = side * Float.random(in: 0.8...1.9)
            let y = Float.random(in: 1.1...2.1)
            let yaw = side * Float.random(in: 10...35)
            gates.append(CourseGateSpec(position: [x, y, z], yawDegrees: yaw))
            z -= 2.5
            side *= -1
            _ = i
        }

        // 8s per gate, shrinking slightly each level, floored so it stays fair.
        let perGate = max(5.0, 8.0 - Double(level - 1) * 0.4)
        let timeLimit = perGate * Double(gates.count)

        return DroneCourse(gates: gates, timeLimit: timeLimit)
    }
}
