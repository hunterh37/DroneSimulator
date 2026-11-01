//
//  DemoAutopilot.swift
//  HelicopterGame
//
//  Stick synthesis, target lookup and camera framing for DemoDirector.
//  Pure functions of entity poses so the same math runs in unit tests.
//

#if os(visionOS)
import Foundation
import RealityKit

enum DemoAutopilot {
    /// P-controller: yaw toward the target when far, strafe/forward/throttle
    /// in drone-local space for precise holds (claw pickups need ~3 cm).
    static func sticks(local d: SIMD3<Float>, speed: Float) -> DemoDirector.Sticks {
        let horiz = simd_length(SIMD2(d.x, d.z))
        // Heading error: target angle around +Y from local forward (-Z).
        let heading = atan2(-d.x, -d.z)
        var s = DemoDirector.Sticks()
        s.yaw = horiz > 0.25 ? clamp(heading * 1.6) : 0
        let gain: Float = 1.4
        s.fwd = clamp(-d.z * gain) * speed
        s.strafe = clamp(d.x * gain) * speed
        s.thr = clamp(d.y * 2.5)
        // Slow forward while turning hard so the drone carves instead of overshooting.
        if abs(heading) > 0.9 { s.fwd *= 0.35 }
        return s
    }

    @MainActor
    static func sticks(drone: Entity, root: Entity, target: SIMD3<Float>, speed: Float) -> DemoDirector.Sticks {
        let p = drone.position(relativeTo: root)
        let q = drone.orientation(relativeTo: root)
        return sticks(local: q.inverse.act(target - p), speed: speed)
    }

    private static func clamp(_ v: Float) -> Float { max(-1, min(1, v)) }
}

@MainActor
enum DemoTargets {
    /// "gates" = next Race League gate (aimed past the gate plane); anything
    /// else is an entity-name prefix, nearest match wins.
    static func resolve(_ target: String, root: Entity, from drone: Entity) -> SIMD3<Float>? {
        if target == "gates" { return RaceLeagueManager.shared.demoNextGate(relativeTo: root) }
        return nearest(prefix: target, root: root, from: drone)?.position(relativeTo: root)
    }

    static func nearest(prefix: String, root: Entity, from drone: Entity) -> Entity? {
        let p = drone.position(relativeTo: root)
        var best: (Entity, Float)?
        var stack: [Entity] = Array(root.children)
        while let e = stack.popLast() {
            if e.name.hasPrefix(prefix), e.isEnabled {
                let d = simd_distance(e.position(relativeTo: root), p)
                if best == nil || d < best!.1 { best = (e, d) }
                continue
            }
            stack.append(contentsOf: e.children)
        }
        return best?.0
    }
}

/// Fixed simulator eye: frame the drone by moving the world root.
@MainActor
final class DemoCamera {
    private(set) var presetName = "fixed"
    private var yawOffset: Float = 0
    private var target: SIMD3<Float> = [0, 0.3, -1.0]
    private var orbit: Float = 0
    private var orbitAngle: Float = 0
    private var ease: Float = 0.08
    private var follow = false
    private var needsReset = false

    func apply(_ op: DemoOp) {
        let dist = op.dist ?? 1.0
        presetName = op.preset ?? "chase"
        orbit = op.orbit ?? 0
        orbitAngle = 0
        ease = op.ease ?? 0.08
        follow = presetName != "fixed"
        needsReset = !follow
        let eye: Float = 1.15
        switch presetName {
        case "side": yawOffset = .pi * 0.5; target = [0, eye, -dist]
        case "front": yawOffset = .pi; target = [0, eye, -dist]
        case "high": yawOffset = .pi * 0.15; target = [0, eye - 0.45, -dist]
        case "low": yawOffset = -.pi * 0.2; target = [0, eye + 0.3, -dist]
        case "wide": yawOffset = .pi * 0.25; target = [0, eye - 0.6, -dist * 2.4]
        default: yawOffset = .pi * 0.06; target = [0, eye - 0.1, -dist]
        }
    }

    func update(root: Entity, drone: Entity, dt: Float) {
        guard follow else {
            if needsReset { root.transform = .identity; needsReset = false }
            return
        }
        orbitAngle += orbit * dt
        let p = drone.position(relativeTo: root)
        let fwd = drone.orientation(relativeTo: root).act([0, 0, -1])
        let droneYaw = atan2(-fwd.x, -fwd.z)
        let rot = simd_quatf(angle: yawOffset + orbitAngle - droneYaw, axis: [0, 1, 0])
        let goal = Transform(rotation: rot, translation: target - rot.act(p))
        let k = min(1, ease * dt * 60)
        var t = root.transform
        t.rotation = simd_slerp(t.rotation, goal.rotation, k)
        t.translation = simd_mix(t.translation, goal.translation, SIMD3(repeating: k))
        root.transform = t
    }
}
#endif
