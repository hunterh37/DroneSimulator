//
//  BossProjectilePreloader.swift
//  HelicopterGame
//
//  Created by Claude on 10/15/25.
//  Preloads boss attack projectile 3D models for efficient spawning
//

import Foundation
import RealityKit
import Combine
import UIKit

/// Preloads all boss projectile 3D models at startup to eliminate runtime loading delays
/// Models are loaded once and cloned when spawning attacks
@MainActor
public class BossProjectilePreloader: ObservableObject {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `BossProjectilePreloader.shared` directly; everyone
    // else must go through GameContext.shared.bossProjectilePreloader.
    fileprivate static let shared = BossProjectilePreloader()

    @Published public var isLoaded = false
    @Published public var loadingProgress: Float = 0.0

    // Preloaded projectile template entities for each attack type
    private var projectileTemplates: [BossAttackType: Entity] = [:]

    private init() {}

    /// Preload all boss projectile models
    public func preloadAllProjectiles() async {
        gameLog("👑💥 [BossProjectilePreloader] Starting boss projectile preload...")

        let attackTypes: [BossAttackType] = [.swarm, .wave, .burst]
        let totalModels = Float(attackTypes.count)

        for (index, attackType) in attackTypes.enumerated() {
            await preloadProjectile(attackType: attackType)
            loadingProgress = Float(index + 1) / totalModels
        }

        isLoaded = true
        gameLog("✅ [BossProjectilePreloader] All boss projectiles preloaded (\(projectileTemplates.count) templates)")
    }

    /// Map attack type to USDZ model name
    private func modelName(for attackType: BossAttackType) -> String {
        switch attackType {
        case .swarm:
            return "BossAttack1" // Swarm projectiles
        case .wave:
            return "BossAttack2" // Wave projectiles
        case .burst:
            return "BossAttack3" // Burst projectiles
        }
    }

    /// Preload a single projectile model by attack type
    private func preloadProjectile(attackType: BossAttackType) async {
        // Skip if already loaded
        guard projectileTemplates[attackType] == nil else {
            gameLog("⚠️ [BossProjectilePreloader] \(attackType) already loaded, skipping")
            return
        }

        let modelName = modelName(for: attackType)

        do {
            // Load the 3D model asynchronously
            let entity = try await Entity(named: modelName, in: nil)

            // Store the template
            projectileTemplates[attackType] = entity

            gameLog("✅ [BossProjectilePreloader] Loaded \(modelName) for \(attackType)")
        } catch {
            gameLog("❌ [BossProjectilePreloader] Failed to load \(modelName): \(error.localizedDescription)")

            // Create a fallback entity as template
            let fallbackEntity = createFallbackProjectile(attackType: attackType)
            projectileTemplates[attackType] = fallbackEntity
            gameLog("⚠️ [BossProjectilePreloader] Using fallback model for \(attackType)")
        }
    }

    /// Create a fallback projectile for models that fail to load
    private func createFallbackProjectile(attackType: BossAttackType) -> Entity {
        let entity = Entity()

        // Different shapes and sizes based on attack type
        let mesh: MeshResource
        let color: UIColor
        let scale: Float

        switch attackType {
        case .swarm:
            // Small spheres for swarm
            scale = 0.05
            mesh = MeshResource.generateSphere(radius: scale)
            color = .cyan
        case .wave:
            // Medium spheres for wave
            scale = 0.1
            mesh = MeshResource.generateSphere(radius: scale)
            color = .orange
        case .burst:
            // Large spheres for burst
            scale = 0.15
            mesh = MeshResource.generateSphere(radius: scale)
            color = .red
        }

        var material = UnlitMaterial(color: color)
        let modelComponent = ModelComponent(mesh: mesh, materials: [material])
        entity.components.set(modelComponent)

        return entity
    }

    /// Get a cloned projectile entity by attack type
    /// - Parameters:
    ///   - attackType: The attack type (swarm, wave, or burst)
    ///   - color: Optional tint color for the projectile
    /// - Returns: A cloned entity ready to use, or nil if not loaded
    public func cloneProjectile(attackType: BossAttackType, color: UIColor? = nil) -> Entity? {
        guard let template = projectileTemplates[attackType] else {
            gameLog("❌ [BossProjectilePreloader] No template found for \(attackType)")
            return nil
        }

        // Clone the template
        let clonedEntity = template.clone(recursive: true)

        // Apply color tint if provided
        if let color = color {
            applyColorTint(to: clonedEntity, color: color)
        }

        return clonedEntity
    }

    /// Apply color tint to all materials in the entity and its children
    private func applyColorTint(to entity: Entity, color: UIColor) {
        // Apply to this entity
        if var modelComponent = entity.components[ModelComponent.self] {
            var materials = modelComponent.materials
            for i in 0..<materials.count {
                if var material = materials[i] as? UnlitMaterial {
                    material.color = .init(tint: color)
                    materials[i] = material
                } else if var material = materials[i] as? SimpleMaterial {
                    material.color = .init(tint: color)
                    materials[i] = material
                }
            }
            modelComponent.materials = materials
            entity.components.set(modelComponent)
        }

        // Apply to children recursively
        for child in entity.children {
            applyColorTint(to: child, color: color)
        }
    }

    /// Check if a specific attack type is loaded
    public func isModelLoaded(attackType: BossAttackType) -> Bool {
        return projectileTemplates[attackType] != nil
    }

    /// Get loading status for debugging
    public func getLoadingStatus() -> String {
        let loaded = projectileTemplates.count
        return "Boss projectiles loaded: \(loaded) (\(Int(loadingProgress * 100))%)"
    }
}

extension GameContext {
    public var bossProjectilePreloader: BossProjectilePreloader { BossProjectilePreloader.shared }
}
