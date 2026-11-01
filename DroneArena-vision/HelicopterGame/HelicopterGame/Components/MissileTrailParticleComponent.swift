//
//  MissileTrailParticleComponent.swift
//  HelicopterGame
//
//  Created by Claude on 10/13/25.
//

import RealityKit
import simd
import UIKit
import SwiftUI

// MARK: - Missile Trail Particle Entity

public class MissileTrailParticleEntity: Entity {

    public init(trailColor: UIColor = .cyan) {
        super.init()
        setupTrailEffect(color: trailColor)
        gameLog("🌟 Created missile trail particle entity with color \(trailColor)")
    }

    required init() {
        super.init()
    }

    private func setupTrailEffect(color: UIColor) {
        // Create laser-like trail using RealityKit ParticleEmitterComponent
        var particles = ParticleEmitterComponent()

        // Emit particles in a tight stream behind the missile
        particles.emitterShape = .point
        particles.emitterShapeSize = [0.01, 0.01, 0.01] // Very small emission point for laser effect

        // High birth rate for continuous laser trail
        particles.mainEmitter.birthRate = 200 // 200 particles per second for smooth trail
        particles.mainEmitter.lifeSpan = 0.5 // Particles last 0.5 seconds
        particles.mainEmitter.size = 0.02 // 2cm particle size

        // Use player color with slight fade
        particles.mainEmitter.color = .evolving(
            start: .single(color),
            end: .single(color.withAlphaComponent(0.0)) // Fade to transparent
        )

        // Minimal speed so particles stay close to emission point (trail effect)
        particles.speed = 0.1 // Very slow - particles should linger where emitted

        // Additive blend mode for glowing laser effect
        particles.mainEmitter.blendMode = .additive

        components.set(particles)
    }

    public func updateTrailColor(_ color: UIColor) {
        // Recreate particle emitter with new color
        if var particles = components[ParticleEmitterComponent.self] {
            particles.mainEmitter.color = .evolving(
                start: .single(color),
                end: .single(color.withAlphaComponent(0.0))
            )
            components.set(particles)
            gameLog("🌟 Updated missile trail color to \(color)")
        }
    }
}
