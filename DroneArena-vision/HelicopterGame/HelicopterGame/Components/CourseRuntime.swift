//
//  CourseRuntime.swift
//  HelicopterGame
//
//  Shared runtime state for the Time Trial obstacle course: the crash component
//  that the course system attaches to the drone while it is falling/recovering,
//  and a tiny input bridge used so non-thumb input paths (e.g. the macOS
//  simulator joystick) can report "lift" intent during crash recovery.
//

import RealityKit
import simd
import Foundation

/// Attached to the player drone while it is crashed. While present, normal flight
/// input is suppressed and CourseObstacleSystem owns the drone's transform.
public struct DroneCrashComponent: Component {
    public enum Phase {
        case falling   // tumbling down toward the landing pad
        case landed    // resting on the pad, waiting for the player to lift off
    }

    public var phase: Phase = .falling
    public var elapsed: TimeInterval = 0
    public var startPos: SIMD3<Float> = .zero
    public var landPos: SIMD3<Float> = .zero
    public var startOrientation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    public var spinAxis: SIMD3<Float> = SIMD3<Float>(1, 0, 0)

    public init() {}
}

/// Bridge for input paths that don't feed DualThumbController. Movement code sets
/// `directLift` (positive = throttle up) when it sees the drone is crashed instead
/// of moving it, so the course system can detect the recovery lift everywhere.
public enum CourseInput {
    public static var directLift: Float = 0
}
