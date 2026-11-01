//
//  ExplosionEntity.swift
//  HelicopterGame
//
//  Created by Claude on 10/11/25.
//  Reusable explosion effect entity for drone destruction
//

import RealityKit
import UIKit
import simd

public class ExplosionEntity: Entity {
    private var explosionDuration: TimeInterval = 3.0

    public required init() {
        super.init()
        Task {
            await setupExplosionEffect()
        }
        scheduleRemoval()
    }

    public convenience init(at position: SIMD3<Float>) {
        self.init()
        self.position = position
    }

    private func setupExplosionEffect() async {
        // Create main explosion effect
        var particles = ParticleEmitterComponent()

        particles.emitterShape = .point
        particles.emitterShapeSize = [0.2, 0.2, 0.2]

        particles.mainEmitter.birthRate = 3
        particles.mainEmitter.lifeSpan = 3
        particles.mainEmitter.size = 0.2
        particles.mainEmitter.acceleration = .zero
        particles.speed = 0.007
        particles.spawnVelocityFactor = 0.00001

        // Use white color to preserve texture colors (red and black from image sequence)
        particles.mainEmitter.color = .constant(.single(.white))

        // Set burst mode instead of continuous emission
        particles.burstCount = 5 // Emit 5 particles in one burst
      //  particles.birthRate = 0 // Don't continuously emit after burst

        // Load explosion texture image sequence
        do {
            particles.mainEmitter.image = try await TextureResource(named: "explosion", in: Bundle.main)
            particles.mainEmitter.imageSequence = .init()
      //      particles.mainEmitter.imageSequence?.animationMode = .once // Changed from .looping to .once
            particles.mainEmitter.imageSequence?.rowCount = 5
            particles.mainEmitter.imageSequence?.columnCount = 4
            particles.mainEmitter.imageSequence?.initialFrame = 0
            particles.mainEmitter.imageSequence?.initialFrameVariation = 2
            particles.mainEmitter.imageSequence?.frameRate = 8
            gameLog("✅ [ExplosionEntity] Loaded explosion texture image sequence")
        } catch {
            gameLog("⚠️ [ExplosionEntity] Failed to load explosion texture: \(error.localizedDescription)")
            // Fallback: Use color evolution if texture loading fails
            particles.mainEmitter.color = .evolving(
                start: .single(UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)),
                end: .single(UIColor(red: 0.2, green: 0.0, blue: 0.0, alpha: 0.0))
            )
        }
        
        particles.mainEmitter.blendMode = .additive

        components.set(particles)

        // Play explosion sound
        playExplosionSound()
    }

    private func scheduleRemoval() {
        DispatchQueue.main.asyncAfter(deadline: .now() + explosionDuration) { [weak self] in
            self?.removeFromParent()
        }
    }

    private func playExplosionSound() {
        gameLog("💥 EXPLOSION! Playing explosion sound effect")
        GameContext.shared.sound.playExplosionSound(entity: self)
    }
}

// MARK: - Static Factory Methods
extension ExplosionEntity {

    /// Creates a drone explosion at the specified position
    public static func createDroneExplosion(at position: SIMD3<Float>) -> ExplosionEntity {
        let explosion = ExplosionEntity(at: position)
        explosion.transform.scale = [3, 3, 3]
        return explosion
    }

    /// Creates a larger explosion for bigger targets
    public static func createLargeExplosion(at position: SIMD3<Float>) -> ExplosionEntity {
        let explosion = ExplosionEntity(at: position)
        explosion.transform.scale = [4, 4, 4]
        return explosion
    }

    /// Creates a small explosion for minor impacts
    public static func createSmallExplosion(at position: SIMD3<Float>) -> ExplosionEntity {
        let explosion = ExplosionEntity(at: position)
        explosion.transform.scale = [1, 1, 1]
        return explosion
    }
}
