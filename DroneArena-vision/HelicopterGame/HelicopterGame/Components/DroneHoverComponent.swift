//
//  DroneHoverComponent.swift
//  HelicopterGame
//
//  Created by Claude on 06/17/26.
//  Realistic drone "feel": idle micro-hover + motion banking/lean.
//
//  This component lives on the drone's VISUAL MODEL child (not the root
//  PlayerDroneEntity). The root is position-controlled by the joystick /
//  control input, so we only ever touch the child's *local* transform.
//  That keeps the hover/banking purely cosmetic and means it never fights
//  the movement systems that drive the root entity's world position.
//

import RealityKit
import simd
import Foundation

// MARK: - Drone Hover Component

public struct DroneHoverComponent: Component {

    // MARK: Idle micro-hover
    /// Vertical bob height in meters when the drone is stationary.
    public var bobAmplitude: Float = 0.012
    /// Primary bob frequency in Hz (converted to radians/sec internally).
    public var bobFrequency: Float = 1.1
    /// A faster, smaller secondary bob layered on top for organic motion.
    public var bobSecondaryAmplitude: Float = 0.004
    public var bobSecondaryFrequency: Float = 2.7
    /// Tiny horizontal drift so it doesn't feel rail-locked.
    public var swayAmplitude: Float = 0.006
    public var swayFrequency: Float = 0.8
    /// Subtle idle pitch/roll wobble in radians.
    public var idleWobbleAmplitude: Float = 0.018
    public var idleWobbleFrequency: Float = 0.9

    // MARK: Motion banking (the "how a drone really moves" part)
    /// How hard the drone leans into forward/back acceleration (radians per m/s).
    public var pitchPerSpeed: Float = 0.085
    /// How hard the drone banks/rolls into a strafe (radians per m/s).
    public var rollPerSpeed: Float = 0.11
    /// Max lean in either axis (radians). ~20deg.
    public var maxLean: Float = 0.35
    /// Positional "trail" — the body lags slightly behind the direction of travel (m per m/s).
    public var positionalLag: Float = 0.01
    public var maxPositionalLag: Float = 0.05
    /// How fast banking interpolates toward its target (higher = snappier).
    public var bankResponse: Float = 7.0
    /// How fast the velocity estimate is smoothed (higher = snappier, noisier).
    public var velocitySmoothing: Float = 8.0
    /// Idle hover fades out as speed rises; larger = fades faster.
    public var idleFalloff: Float = 2.5

    // MARK: Internal state
    public var time: Double = 0
    public var smoothedLocalVelocity: SIMD3<Float> = .zero
    public var previousParentWorldPos: SIMD3<Float>?

    /// Captured rest transform of the visual model (its authored local transform).
    public var restTranslation: SIMD3<Float> = .zero
    public var restOrientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    public var captured: Bool = false

    /// Smoothed applied values (so we lerp instead of snapping each frame).
    public var appliedPitch: Float = 0
    public var appliedRoll: Float = 0
    public var appliedLag: SIMD3<Float> = .zero

    public init() {}
}

// MARK: - Drone Hover System

public struct DroneHoverSystem: System {
    static let query = EntityQuery(where: .has(DroneHoverComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        guard dt > 0.0001 else { return }

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var hover = entity.components[DroneHoverComponent.self] else { continue }

            // Capture the model's authored rest transform once.
            if !hover.captured {
                hover.restTranslation = entity.transform.translation
                hover.restOrientation = entity.transform.rotation
                hover.captured = true
            }

            hover.time += context.deltaTime
            let t = Float(hover.time)

            // --- 1. Estimate the ROOT drone's velocity ---
            // We track the PARENT's world position, not this child's, because the
            // child is what we're animating — using it would feed the hover back on itself.
            var localVelocity = SIMD3<Float>.zero
            if let parent = entity.parent {
                let parentWorld = parent.position(relativeTo: nil)
                if let prev = hover.previousParentWorldPos {
                    let worldVel = (parentWorld - prev) / dt
                    // Express velocity in the parent's local frame so "forward" and
                    // "strafe" are meaningful regardless of which way the drone faces.
                    localVelocity = parent.orientation(relativeTo: nil).inverse.act(worldVel)
                }
                hover.previousParentWorldPos = parentWorld
            }

            // Exponential smoothing of velocity to kill per-frame jitter.
            let velBlend = min(dt * hover.velocitySmoothing, 1.0)
            hover.smoothedLocalVelocity = mix(hover.smoothedLocalVelocity,
                                              localVelocity,
                                              t: velBlend)
            let v = hover.smoothedLocalVelocity
            let speed = simd_length(v)

            // --- 2. Idle micro-hover (fades out the faster we move) ---
            let idleFactor = 1.0 / (1.0 + speed * hover.idleFalloff)

            let bob = (sin(t * hover.bobFrequency * .pi * 2) * hover.bobAmplitude
                     + sin(t * hover.bobSecondaryFrequency * .pi * 2) * hover.bobSecondaryAmplitude)
                     * idleFactor
            let swayX = sin(t * hover.swayFrequency * .pi * 2) * hover.swayAmplitude * idleFactor
            let swayZ = cos(t * hover.swayFrequency * .pi * 2 * 0.7) * hover.swayAmplitude * idleFactor

            let idleWobblePitch = sin(t * hover.idleWobbleFrequency * .pi * 2 * 1.3) * hover.idleWobbleAmplitude * idleFactor
            let idleWobbleRoll  = sin(t * hover.idleWobbleFrequency * .pi * 2)       * hover.idleWobbleAmplitude * idleFactor

            // --- 3. Motion banking ---
            // Forward in local space is -Z. Accelerating forward pitches the nose down.
            let forwardSpeed = -v.z
            let strafeSpeed  = v.x

            let targetPitch = clamp(forwardSpeed * hover.pitchPerSpeed, -hover.maxLean, hover.maxLean)
            // Bank INTO the strafe: moving +X (right) rolls the right side down.
            let targetRoll  = clamp(-strafeSpeed * hover.rollPerSpeed, -hover.maxLean, hover.maxLean)

            let bankBlend = min(dt * hover.bankResponse, 1.0)
            hover.appliedPitch = lerp(hover.appliedPitch, targetPitch, t: bankBlend)
            hover.appliedRoll  = lerp(hover.appliedRoll,  targetRoll,  t: bankBlend)

            // Positional trail: body lags opposite the velocity direction.
            var targetLag = SIMD3<Float>.zero
            if speed > 0.0001 {
                let dir = v / speed
                let lagMag = min(speed * hover.positionalLag, hover.maxPositionalLag)
                targetLag = -dir * lagMag
            }
            hover.appliedLag = mix(hover.appliedLag, targetLag, t: bankBlend)

            // --- 4. Compose final local transform on the visual model ---
            let offset = SIMD3<Float>(swayX + hover.appliedLag.x,
                                      bob   + hover.appliedLag.y,
                                      swayZ + hover.appliedLag.z)

            let pitch = hover.appliedPitch + idleWobblePitch
            let roll  = hover.appliedRoll  + idleWobbleRoll
            let pitchQ = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
            let rollQ  = simd_quatf(angle: roll,  axis: SIMD3<Float>(0, 0, 1))

            var transform = entity.transform
            transform.translation = hover.restTranslation + offset
            transform.rotation = hover.restOrientation * pitchQ * rollQ
            entity.transform = transform

            entity.components[DroneHoverComponent.self] = hover
        }
    }

    private func lerp(_ a: Float, _ b: Float, t: Float) -> Float { a + (b - a) * t }
    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> { a + (b - a) * t }
    private func clamp(_ x: Float, _ lo: Float, _ hi: Float) -> Float { min(max(x, lo), hi) }
}

// MARK: - Player Drone Entity Extension

extension PlayerDroneEntity {
    /// Attaches the realistic hover + banking effect to the drone's visual model.
    /// Call this with the loaded model child (so we animate the model, not the
    /// position-controlled root entity).
    /// - Parameters:
    ///   - model: the visual model entity (the `.usdz` child).
    ///   - configure: optional closure to tweak the component's tuning values.
    public func addDroneHover(to model: Entity,
                              configure: ((inout DroneHoverComponent) -> Void)? = nil) {
        var hover = DroneHoverComponent()
        configure?(&hover)
        model.components.set(hover)
        gameLog("🛸 Added drone hover/banking to visual model")
    }
}
