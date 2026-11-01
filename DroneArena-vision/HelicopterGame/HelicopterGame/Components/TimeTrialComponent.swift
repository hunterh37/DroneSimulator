//
//  TimeTrialComponent.swift
//  HelicopterGame
//
//  ECS Component and System for Time Trial game mode.
//
//  Time Trial is a hoop-on-post obstacle course: the player flies their drone
//  through a handcrafted sequence of CourseGateEntity gates against the clock.
//  Hitting a hoop frame or its post crashes the drone — it tumbles onto a spawned
//  CrashPadEntity and waits there until the player lifts off again with the
//  throttle. All of that crash/pass logic lives in this system; the timer and
//  level lifecycle are still owned by TimeTrialManager.
//

import RealityKit
import simd
import Foundation
import QuartzCore
#if os(visionOS)
import DicyaninThumbController
#endif

// MARK: - Components

public struct TimeTrialComponent: Component {
    public var currentState: TimeTrialState = .waiting
    public var currentLevel: TimeTrialLevel?
    public var ringsRemaining: Int = 0          // reused as "gates remaining"
    public var timeRemaining: TimeInterval = 0
    public var levelStartTime: TimeInterval = 0
    public var score: Int = 0
    public var nextRingSpawnTime: TimeInterval = 0
    public var spawnCooldown: TimeInterval = 0.5
    public var maxConcurrentRings: Int = 8

    public init() {}
}

/// Legacy ring component, retained so RingEntity still compiles. No longer spawned
/// by Time Trial, which now uses CourseGateEntity gates.
public struct RingComponent: Component {
    public let ringID: String
    public var isCollected: Bool = false
    public var ringValue: Int = 100
    public var levelIndex: Int = 0

    public init(ringID: String, value: Int = 100, levelIndex: Int = 0) {
        self.ringID = ringID
        self.ringValue = value
        self.levelIndex = levelIndex
    }
}

// MARK: - System

public class TimeTrialSystem: System {
    private static let timeTrialQuery = EntityQuery(where: .has(TimeTrialComponent.self))

    /// Throttle threshold (0...1) the player must push up to recover from a crash.
    private static let liftToRecover: Float = 0.35

    @MainActor public static var timeTrialManager: TimeTrialManager?

    public required init(scene: Scene) {}

    public func update(context: SceneUpdateContext) {
        guard let manager = TimeTrialSystem.timeTrialManager else { return }

        let deltaTime = Float(context.deltaTime)

        for entity in context.entities(matching: Self.timeTrialQuery, updatingSystemWhen: .rendering) {
            guard var component = entity.components[TimeTrialComponent.self] else { continue }
            guard component.currentState == .active, component.currentLevel != nil else { continue }

            // --- Timer ---
            component.timeRemaining -= Double(deltaTime)
            if component.timeRemaining <= 0 {
                component.currentState = .gameOver
                entity.components[TimeTrialComponent.self] = component
                Task { @MainActor in manager.endLevel(completed: false) }
                continue
            }

            guard let drone = manager.playerDrone as? PlayerDroneEntity else {
                entity.components[TimeTrialComponent.self] = component
                continue
            }

            // --- Crash recovery takes full control of the drone while active ---
            if drone.components[DroneCrashComponent.self] != nil {
                updateCrash(drone: drone, manager: manager, dt: deltaTime)
                entity.components[TimeTrialComponent.self] = component
                continue
            }

            // --- Gate pass / crash detection ---
            let gates = entity.children.compactMap { $0 as? CourseGateEntity }
            guard !gates.isEmpty else {
                entity.components[TimeTrialComponent.self] = component
                continue
            }

            let dronePos = drone.position(relativeTo: nil)
            for gate in gates where !gate.isPassed {
                let outcome = evaluate(gate: gate, droneWorldPos: dronePos)
                switch outcome {
                case .crash:
                    gate.flashCrash()
                    manager.beginCrash(drone: drone, gateRoot: entity)
                case .passed:
                    gate.markPassed()
                    component.score += 100
                    GameContext.shared.sound.playRingCollectSound(entity: gate)
                case .none:
                    break
                }
                if case .crash = outcome { break } // stop scanning once crashed
            }

            // --- Completion ---
            let remaining = gates.filter { !$0.isPassed }.count
            component.ringsRemaining = remaining
            if remaining <= 0 {
                entity.components[TimeTrialComponent.self] = component
                Task { @MainActor in manager.endLevel(completed: true) }
                continue
            }

            entity.components[TimeTrialComponent.self] = component
        }
    }

    // MARK: - Gate evaluation

    private enum GateOutcome { case none, passed, crash }

    private func evaluate(gate: CourseGateEntity, droneWorldPos: SIMD3<Float>) -> GateOutcome {
        guard var c = gate.components[CourseGateComponent.self] else { return .none }

        // Drone position in the gate's local frame.
        let local = gate.convert(position: droneWorldPos, from: nil)
        let r = sqrt(local.x * local.x + local.y * local.y)   // in-plane radius
        let lz = local.z                                       // distance along fly-through axis

        defer {
            c.prevLocalZ = lz
            c.hasPrevZ = true
            gate.components.set(c)
        }

        // Crash 1: clipped the hoop frame (near the rim centerline torus).
        let distToRim = sqrt((r - c.ringRadius) * (r - c.ringRadius) + lz * lz)
        if distToRim < c.crashBand {
            return .crash
        }

        // Crash 2: hit the post (vertical cylinder hanging below the hoop center).
        let horiz = sqrt(local.x * local.x + local.z * local.z)
        if local.y < -c.ringRadius,
           local.y > -(c.ringRadius + c.postHeight),
           horiz < c.postRadius + c.droneRadius {
            return .crash
        }

        // Pass: crossed the hoop plane (lz changed sign) inside the opening.
        if c.hasPrevZ,
           (c.prevLocalZ > 0) != (lz > 0),
           r < c.ringRadius - 0.05 {
            return .passed
        }

        return .none
    }

    // MARK: - Crash animation + recovery

    private func updateCrash(drone: PlayerDroneEntity, manager: TimeTrialManager, dt: Float) {
        guard var c = drone.components[DroneCrashComponent.self] else { return }
        c.elapsed += TimeInterval(dt)

        switch c.phase {
        case .falling:
            let dur: TimeInterval = 0.8
            let t = Float(min(1.0, c.elapsed / dur))
            let ease = 1 - pow(1 - t, 3) // easeOutCubic
            let y = c.startPos.y + (c.landPos.y - c.startPos.y) * ease
            drone.setPosition(SIMD3<Float>(c.startPos.x, y, c.startPos.z), relativeTo: nil)
            let spin = Float.pi * 1.5 * t
            drone.setOrientation(c.startOrientation * simd_quatf(angle: spin, axis: c.spinAxis), relativeTo: nil)
            if t >= 1.0 { c.phase = .landed; c.elapsed = 0 }

        case .landed:
            // Hold on the pad and settle upright.
            drone.setPosition(c.landPos, relativeTo: nil)
            let cur = drone.orientation(relativeTo: nil)
            drone.setOrientation(simd_slerp(cur, c.startOrientation, min(1.0, dt * 6)), relativeTo: nil)

            if Self.currentLift() > Self.liftToRecover {
                manager.recoverCrash(drone: drone)
                return
            }
        }

        drone.components.set(c)
    }

    /// Unified "throttle up" signal across input schemes. DualThumbController covers
    /// hand tracking, the 3D gamepad, and the on-screen virtual joysticks (which
    /// feed it via InputRouter). CourseInput.directLift covers the macOS-simulator
    /// joystick path that writes the drone transform directly.
    private static func currentLift() -> Float {
        var lift = CourseInput.directLift
        #if os(visionOS)
        if DualThumbController.shared.leftIsActive {
            lift = max(lift, DualThumbController.shared.leftDirection.y * DualThumbController.shared.leftMagnitude)
        }
        #endif
        return lift
    }
}

// MARK: - Entity Extensions

public extension Entity {
    func addTimeTrialComponent() {
        self.components[TimeTrialComponent.self] = TimeTrialComponent()
    }

    func removeTimeTrialComponent() {
        self.components[TimeTrialComponent.self] = nil
    }
}
