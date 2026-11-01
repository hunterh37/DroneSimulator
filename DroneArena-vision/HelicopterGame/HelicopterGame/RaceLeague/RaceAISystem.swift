//
//  RaceAISystem.swift
//  HelicopterGame
//
//  CPU race pilots: follow the arc-length racing line with curvature-limited cornering,
//  acceleration limits, lane drift, mistakes and mild rubber-banding. Banked + pitched
//  attitude from speed and signed curvature.
//

import RealityKit
import simd

struct RaceAIComponent: Component {
    var pilotID: String
    /// Unbounded distance along the track. 0 = first crossing of the start gate.
    var s: Float
    var speed: Float = 0
    var topSpeed: Float
    var grip: Float
    var accel: Float
    var mistakeRate: Float
    var rubberBand: Float
    var lane: Float = 0
    var laneTarget: Float = 0
    var laneTimer: Float = 0
    var heightOffset: Float = 0
    var mistakeTimer: Float = 0
    var bobPhase: Float = 0
    var finishS: Float = .greatestFiniteMagnitude
    var finishTime: Double?
    var lapStartTime: Double = 0
    var lastLapIndex: Int = -1
    var bestLap: Double = .greatestFiniteMagnitude
    var lapCount: Int = 0
}

struct RaceAISystem: System {
    nonisolated(unsafe) static var track: RaceTrack?
    nonisolated(unsafe) static var isRacing = false
    nonisolated(unsafe) static var raceClock: Double = 0
    nonisolated(unsafe) static var playerS: Float = 0

    private static let query = EntityQuery(where: .has(RaceAIComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        guard let track = Self.track else { return }
        let dt = min(Float(context.deltaTime), 1.0 / 30.0)
        for e in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var ai = e.components[RaceAIComponent.self] else { continue }
            ai.bobPhase += dt * 6.3

            if Self.isRacing {
                step(&ai, track: track, dt: dt)
            }

            let p = track.position(at: ai.s)
            let t = track.tangent(at: ai.s)
            let right = simd_normalize(simd_cross(t, [0, 1, 0]))
            let bob = sin(ai.bobPhase) * 0.012
            e.position = p + right * ai.lane + [0, ai.heightOffset + bob, 0]

            let yaw = atan2(-t.x, -t.z)
            let climb = asin(max(-1, min(1, t.y)))
            let pitch = -0.32 * (ai.speed / max(ai.topSpeed, 0.1)) + climb * 0.5
            let kappa = track.curvature(at: ai.s)
            let roll = max(-0.75, min(0.75, -atan(ai.speed * ai.speed * kappa / 9.81)))
            let target = simd_quatf(angle: yaw, axis: [0, 1, 0])
                * simd_quatf(angle: pitch, axis: [1, 0, 0])
                * simd_quatf(angle: roll, axis: [0, 0, 1])
            e.orientation = simd_slerp(e.orientation, target, min(1, dt * 8))
            e.components.set(ai)
        }
    }

    private func step(_ ai: inout RaceAIComponent, track: RaceTrack, dt: Float) {
        let finished = ai.finishTime != nil
        let lookahead = max(1.5, ai.speed * 0.9)
        let kappa = track.peakCurvature(from: ai.s, ahead: lookahead)
        var target = min(ai.topSpeed, sqrt(ai.grip / max(kappa, 0.0005)))

        if !finished {
            let gap = Self.playerS - ai.s
            if gap > 3 { target *= 1 + ai.rubberBand * min(1, (gap - 3) / 12) }
            else if gap < -10 { target *= 1 - ai.rubberBand * 0.5 }

            if ai.mistakeTimer <= 0, Float.random(in: 0...1) < ai.mistakeRate * dt {
                ai.mistakeTimer = Float.random(in: 0.4...0.9)
                ai.laneTarget = Float.random(in: -0.45...0.45)
            }
        } else {
            target = min(target, 1.6)
        }
        if ai.mistakeTimer > 0 {
            ai.mistakeTimer -= dt
            target *= 0.62
        }

        if target > ai.speed { ai.speed = min(target, ai.speed + ai.accel * dt) }
        else { ai.speed = max(target, ai.speed - 7 * dt) }
        ai.s += ai.speed * dt

        ai.laneTimer -= dt
        if ai.laneTimer <= 0 {
            ai.laneTimer = Float.random(in: 1.5...3.5)
            ai.laneTarget = Float.random(in: -0.3...0.3)
        }
        ai.lane += (ai.laneTarget - ai.lane) * min(1, dt * 1.2)

        // Lap + finish bookkeeping
        if ai.s >= 0 {
            let lapIndex = Int(ai.s / track.length)
            if lapIndex != ai.lastLapIndex {
                if ai.lastLapIndex >= 0 && !finished {
                    let lap = Self.raceClock - ai.lapStartTime
                    ai.bestLap = min(ai.bestLap, lap)
                    ai.lapCount += 1
                }
                ai.lapStartTime = Self.raceClock
                ai.lastLapIndex = lapIndex
            }
        }
        if !finished && ai.s >= ai.finishS {
            ai.finishTime = Self.raceClock
        }
    }
}
