//
//  DroneTrailParticleComponent.swift
//  HelicopterGame
//
//  Created by Claude on 10/7/25.
//  Rebuilt as a GPU-driven jet/laser exhaust using ParticleEmitterComponent.
//

import RealityKit
import simd
import UIKit
import SwiftUI

// MARK: - Drone Trail Particle Component

/// Marker/config component kept for API + System-query compatibility.
/// The heavy lifting is done by a single GPU-driven `ParticleEmitterComponent`,
/// so this struct only carries tuning state (no per-particle CPU work).
public struct DroneTrailParticleComponent: Component {
    public var trailColor: UIColor
    public var particleLifetime: Float
    public var emissionRate: Float
    public var isEnabled: Bool

    public init(trailColor: UIColor = .cyan, particleLifetime: Float = 1.0, emissionRate: Float = 0.1, isEnabled: Bool = true) {
        self.trailColor = trailColor
        self.particleLifetime = particleLifetime
        self.emissionRate = emissionRate
        self.isEnabled = isEnabled
    }
}

// MARK: - Drone Trail Particle Entity

/// A high-performance jet/laser exhaust plume.
///
/// Performance: instead of spawning one `Entity` + two `AnimationResource`s +
/// a `DispatchQueue` timer per particle (the old approach), this uses a single
/// `ParticleEmitterComponent`. All particle simulation runs on the GPU — the CPU
/// cost is effectively constant regardless of particle count, and there is zero
/// per-particle allocation, animation, or main-thread cleanup.
public class DroneTrailParticleEntity: Entity, HasModel {

    /// Base birth rate (particles/sec) of the white-hot core when idle.
    private var baseBirthRate: Float = 260
    /// Extra birth rate added at full throttle.
    private var throttleBirthRate: Float = 900

    private var lastDronePosition: SIMD3<Float> = .zero
    private var smoothedSpeed: Float = 0
    private var hasLastPosition = false

    public init(trailColor: UIColor = .cyan, particleLifetime: Float = 1.0, emissionRate: Float = 0.1) {
        super.init()

        // Sit the emitter slightly behind the drone and aim the plume backward (+Z local).
        self.position = SIMD3<Float>(0, 0, 0.12)

        let config = DroneTrailParticleComponent(
            trailColor: trailColor,
            particleLifetime: particleLifetime,
            emissionRate: emissionRate,
            isEnabled: true
        )
        self.components.set(config)

        let emitter = Self.makeExhaustEmitter(color: trailColor, lifetime: max(0.25, min(particleLifetime, 0.8)))
        self.components.set(emitter)
    }

    required init() {
        super.init()
    }

    // MARK: - Emitter construction

    /// Builds a two-stage jet/laser exhaust:
    ///  • main core  — white-hot, stretched along travel (laser streak), additive
    ///  • spawned embers — colored glowing sparks that drift and fade
    private static func makeExhaustEmitter(color: UIColor, lifetime: Float) -> ParticleEmitterComponent {
        var p = ParticleEmitterComponent()

        // Tight nozzle so the plume reads as a focused jet, not a cloud.
        p.emitterShape = .sphere
        p.emitterShapeSize = [0.012, 0.012, 0.012]
        p.birthDirection = .local
        p.emissionDirection = [0, 0, 1]          // blast straight back (+Z local)

        // Particles are simulated in world space, so they hang in the air and the
        // drone "flies out" of them — that's what makes the contrail read.
        p.speed = 0.85
        p.speedVariation = 0.25

        // ---- Core: white-hot laser streak --------------------------------------
        var core = p.mainEmitter
        core.birthRate = 260
        core.birthRateVariation = 40
        core.lifeSpan = Double(lifetime)
        core.lifeSpanVariation = Double(lifetime) * 0.3
        core.size = 0.016
        core.sizeVariation = 0.006
        core.spreadingAngle = 0.18                // ~10° cone — tight
        core.stretchFactor = 4.0                  // motion-streak → laser look
        core.color = .evolving(
            start: .single(.white),
            end: .single(color.withAlphaComponent(0.0))
        )
        core.opacityCurve = .easeFadeOut
        core.sizeMultiplierAtEndOfLifespan = 0.05 // taper to a point
        core.blendMode = .additive
        core.dampingFactor = 1.2                  // slows as it trails → settles into a tail
        core.isLightingEnabled = false

        // ---- Embers: colored glow sparks shed from the core --------------------
        var ember = ParticleEmitterComponent.ParticleEmitter()
        ember.birthRate = 18
        ember.lifeSpan = Double(lifetime) * 1.8
        ember.lifeSpanVariation = Double(lifetime)
        ember.size = 0.01
        ember.sizeVariation = 0.006
        ember.spreadingAngle = 0.6
        ember.color = .evolving(
            start: .single(color),
            end: .single(color.withAlphaComponent(0.0))
        )
        ember.opacityCurve = .gradualFadeInOut
        ember.sizeMultiplierAtEndOfLifespan = 0.0
        ember.blendMode = .additive
        ember.dampingFactor = 2.0
        ember.isLightingEnabled = false

        p.mainEmitter = core
        p.spawnedEmitter = ember
        return p
    }

    // MARK: - Per-frame update (cheap)

    /// Called by `DroneTrailSystem` each frame. No particle work happens here —
    /// the GPU owns that. We only modulate the emission rate so the exhaust
    /// "roars" up under speed and idles when hovering. Pure value math, O(1).
    public func updateTrail(deltaTime: Float, dronePosition: SIMD3<Float>, droneOrientation: simd_quatf) {
        guard let config = components[DroneTrailParticleComponent.self] else { return }

        guard config.isEnabled else {
            if var emitter = components[ParticleEmitterComponent.self], emitter.mainEmitter.birthRate != 0 {
                emitter.mainEmitter.birthRate = 0
                components.set(emitter)
            }
            return
        }

        // Estimate speed, smoothed to avoid jitter.
        var instantSpeed: Float = 0
        if hasLastPosition, deltaTime > 0 {
            instantSpeed = simd_length(dronePosition - lastDronePosition) / deltaTime
        }
        lastDronePosition = dronePosition
        hasLastPosition = true
        smoothedSpeed += (instantSpeed - smoothedSpeed) * min(1, deltaTime * 8)

        // Map speed (~0...4 m/s) to a 0...1 throttle.
        let throttle = max(0, min(1, smoothedSpeed / 4.0))
        let targetBirthRate = baseBirthRate + throttleBirthRate * throttle

        guard var emitter = components[ParticleEmitterComponent.self] else { return }
        // Only write back when it actually changed enough to matter.
        if abs(emitter.mainEmitter.birthRate - targetBirthRate) > 8 {
            emitter.mainEmitter.birthRate = targetBirthRate
            emitter.speed = 0.85 + 0.6 * throttle      // longer plume at speed
            components.set(emitter)
        }
    }

    // MARK: - API compatibility (kept so callers don't change)

    /// No longer needed (particles simulate in world space automatically) but
    /// retained so existing callers compile.
    public func setWorldParent(_ parent: Entity) { /* no-op: GPU world-space sim */ }

    public func setTrailColor(_ color: UIColor) {
        if var config = components[DroneTrailParticleComponent.self] {
            config.trailColor = color
            components.set(config)
        }
        if var emitter = components[ParticleEmitterComponent.self] {
            emitter.mainEmitter.color = .evolving(
                start: .single(.white),
                end: .single(color.withAlphaComponent(0.0))
            )
            emitter.spawnedEmitter?.color = .evolving(
                start: .single(color),
                end: .single(color.withAlphaComponent(0.0))
            )
            components.set(emitter)
        }
    }

    public func setTrailEnabled(_ enabled: Bool) {
        if var config = components[DroneTrailParticleComponent.self] {
            config.isEnabled = enabled
            components.set(config)
        }
        if var emitter = components[ParticleEmitterComponent.self] {
            emitter.mainEmitter.birthRate = enabled ? baseBirthRate : 0
            components.set(emitter)
        }
    }
}

// MARK: - Drone Trail Factory

public struct DroneTrailFactory {

    /// Create trail for local player drone using their profile color
    public static func createLocalPlayerTrail() -> DroneTrailParticleEntity {
        let profileManager = GameContext.shared.playerProfile
        let playerColor = UIColor(swiftUIColor: profileManager.playerColor)

        return DroneTrailParticleEntity(
            trailColor: playerColor,
            particleLifetime: 0.55,
            emissionRate: 0.08
        )
    }

    /// Create trail for remote player drone using their specific color
    public static func createRemotePlayerTrail(playerColor: String) -> DroneTrailParticleEntity {
        let color = UIColor(hex: playerColor) ?? UIColor.cyan

        return DroneTrailParticleEntity(
            trailColor: color,
            particleLifetime: 0.55,
            emissionRate: 0.08
        )
    }

    /// Create trail with custom color and settings
    public static func createCustomTrail(color: UIColor, lifetime: Float = 0.55, emissionRate: Float = 0.08) -> DroneTrailParticleEntity {
        return DroneTrailParticleEntity(
            trailColor: color,
            particleLifetime: lifetime,
            emissionRate: emissionRate
        )
    }
}

// MARK: - Drone Trail System

public class DroneTrailSystem: System {
    static let query = EntityQuery(where: .has(DroneTrailParticleComponent.self))

    public required init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard let trailEntity = entity as? DroneTrailParticleEntity else { continue }
            let worldPos = trailEntity.position(relativeTo: nil)
            let worldOrient = trailEntity.orientation(relativeTo: nil)
            trailEntity.updateTrail(
                deltaTime: Float(context.deltaTime),
                dronePosition: worldPos,
                droneOrientation: worldOrient
            )
        }
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        // Remove # prefix if present
        let hexColor = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex

        if hexColor.count == 6 {
            let scanner = Scanner(string: hexColor)
            var hexNumber: UInt64 = 0

            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                b = CGFloat(hexNumber & 0x0000ff) / 255
                a = 1.0

                self.init(red: r, green: g, blue: b, alpha: a)
                return
            }
        }

        return nil
    }
}
