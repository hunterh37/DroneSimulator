//
//  ExplosionParticleComponent.swift
//  HelicopterGame
//
//  Created by Claude on 10/7/25.
//

import RealityKit
import simd
import UIKit
import SwiftUI

// MARK: - Explosion Particle Entity

public class ExplosionParticleEntity: Entity, HasModel {

    public init(at position: SIMD3<Float>, color: UIColor = .green, intensity: Float = 1.0) {
        super.init()

        self.position = position
        setupExplosionEffect(color: color, intensity: intensity)

        // Auto-remove after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.removeFromParent()
        }
    }

    required init() {
        super.init()
    }

    private func setupExplosionEffect(color: UIColor, intensity: Float) {
        // Create multiple particle bursts for a nice explosion effect
        createParticleBurst(color: color, intensity: intensity, scale: 1.0, lifetime: 1.0)
        createParticleBurst(color: color.withAlphaComponent(0.7), intensity: intensity * 0.8, scale: 0.7, lifetime: 0.8)
        createParticleBurst(color: color.withAlphaComponent(0.5), intensity: intensity * 0.6, scale: 0.5, lifetime: 0.6)

        gameLog("💥 Created explosion particle effect at \(position) with color \(color)")
    }

    private func createParticleBurst(color: UIColor, intensity: Float, scale: Float, lifetime: Float) {
        // Create a sphere of small particles
        let particleCount = Int(20 * intensity) // 20-40 particles based on intensity

        for i in 0..<particleCount {
            // Random direction for particle
            let theta = Float.random(in: 0...(2 * Float.pi))
            let phi = Float.random(in: 0...Float.pi)

            let x = sin(phi) * cos(theta)
            let y = sin(phi) * sin(theta)
            let z = cos(phi)

            let direction = SIMD3<Float>(x, y, z)
            let distance = Float.random(in: 0.1...0.5) * scale // Random burst distance

            createParticle(
                direction: direction,
                distance: distance,
                color: color,
                lifetime: lifetime,
                delay: Float(i) * 0.02 // Slight stagger
            )
        }
    }

    private func createParticle(direction: SIMD3<Float>, distance: Float, color: UIColor, lifetime: Float, delay: Float) {
        // Create small particle entity
        let particle = Entity()

        // Create small sphere for particle
        let sphereMesh = MeshResource.generateSphere(radius: 0.015) // 1.5cm particles
        var material = UnlitMaterial(color: color)
        material.color = .init(tint: color)

        let modelComponent = ModelComponent(mesh: sphereMesh, materials: [material])
        particle.components.set(modelComponent)

        // Start at explosion center
        particle.position = SIMD3<Float>(0, 0, 0)

        addChild(particle)

        // Animate particle explosion after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(delay)) {
            self.animateParticle(particle, direction: direction, distance: distance, lifetime: lifetime)
        }
    }

    private func animateParticle(_ particle: Entity, direction: SIMD3<Float>, distance: Float, lifetime: Float) {
        let finalPosition = direction * distance

        // Use transform animations directly with AnimationResource
        let moveAnimation = try! AnimationResource.generate(with: FromToByAnimation(
            from: Transform(translation: SIMD3<Float>(0, 0, 0)),
            to: Transform(translation: finalPosition),
            duration: Double(lifetime)
        ))

        let scaleAnimation = try! AnimationResource.generate(with: FromToByAnimation(
            from: Transform(scale: SIMD3<Float>(1, 1, 1)),
            to: Transform(scale: SIMD3<Float>(0.1, 0.1, 0.1)),
            duration: Double(lifetime)
        ))

        // Start animations
        particle.playAnimation(moveAnimation)
        particle.playAnimation(scaleAnimation)

        // Remove particle after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(lifetime)) {
            particle.removeFromParent()
        }
    }
}

// MARK: - Explosion Effect Factory

public struct ExplosionEffectFactory {

    /// Create explosion effect with player's color
    public static func createPlayerExplosion(at position: SIMD3<Float>, forPlayerID playerID: String) -> ExplosionParticleEntity {
        let color = getPlayerColor(for: playerID)
        return ExplosionParticleEntity(at: position, color: color, intensity: 1.2)
    }

    /// Create explosion effect with custom color
    public static func createCustomExplosion(at position: SIMD3<Float>, color: UIColor, intensity: Float = 1.0) -> ExplosionParticleEntity {
        return ExplosionParticleEntity(at: position, color: color, intensity: intensity)
    }

    /// Create enemy explosion (orange/red)
    public static func createEnemyExplosion(at position: SIMD3<Float>) -> ExplosionParticleEntity {
        let enemyColor = UIColor.orange
        return ExplosionParticleEntity(at: position, color: enemyColor, intensity: 1.0)
    }

    // MARK: - Helper Methods

    private static func getPlayerColor(for playerID: String) -> UIColor {
        // Get local player color from profile manager
        let networking = MultiplayerNetworking()

        if playerID == networking.localPlayerID {
            // Local player - use their profile color
            let profileManager = GameContext.shared.playerProfile
            return UIColor(swiftUIColor: profileManager.playerColor)
        } else {
            // Remote player - try to get their color (simplified for now)
            // In a full implementation, you'd track remote player colors
            return UIColor.cyan // Default color for remote players
        }
    }
}

// MARK: - UIColor Extension for SwiftUI Color

extension UIColor {
    convenience init(swiftUIColor color: Color) {
        // Convert SwiftUI Color to UIColor properly without recursion
        let cgColor = color.cgColor ?? UIColor.blue.cgColor
        self.init(cgColor: cgColor)
    }
}