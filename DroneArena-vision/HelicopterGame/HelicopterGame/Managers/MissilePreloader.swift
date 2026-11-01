//
//  MissilePreloader.swift
//  HelicopterGame
//
//  Created by Claude on 10/13/25.
//

import Foundation
import RealityKit
import Combine
import UIKit

/// Preloads all missile 3D models at startup to eliminate runtime loading delays
/// Models are loaded once and cloned when firing missiles
@MainActor
public class MissilePreloader: ObservableObject {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `MissilePreloader.shared` directly; everyone else must
    // go through GameContext.shared.missilePreloader.
    fileprivate static let shared = MissilePreloader()

    @Published public var isLoaded = false
    @Published public var loadingProgress: Float = 0.0

    // Preloaded missile template entities for each weapon model name
    private var missileTemplates: [String: Entity] = [:]

    private init() {}

    /// Preload all missile models for all weapon types
    public func preloadAllMissiles(weapons: [MissileWeapon]) async {
        gameLog("🎯 [MissilePreloader] Starting missile preload...")

        // Get unique model names from weapons
        let modelNames = getModelNames(for: weapons)
        let totalModels = Float(modelNames.count)

        for (index, modelName) in modelNames.enumerated() {
            await preloadMissile(modelName: modelName)
            loadingProgress = Float(index + 1) / totalModels
        }

        isLoaded = true
        gameLog("✅ [MissilePreloader] All missiles preloaded (\(missileTemplates.count) templates)")
    }

    /// Extract unique model names for all weapons
    private func getModelNames(for weapons: [MissileWeapon]) -> [String] {
        var modelNames = Set<String>()
        for weapon in weapons {
            modelNames.insert(weaponModelName(for: weapon))
        }
        return Array(modelNames)
    }

    /// Map weapon ID to USDZ model name (matches LoadoutManager logic)
    private func weaponModelName(for weapon: MissileWeapon) -> String {
        switch weapon.id {
        case "standard":
            return "StandardMissile"
        case "rapid":
            return "RapidMissile"
        case "big":
            return "BigMissile"
        case "damage":
            return "DamageMissile"
        case "barrage_precision":
            return "BigMissile"
        case "barrage_heavy":
            return "BigMissile"
        case "barrage_standard":
            return "StandardMissile"
        case "barrage_light":
            return "RapidMissile"
        default:
            return "StandardMissile"
        }
    }

    /// Preload a single missile model by name
    private func preloadMissile(modelName: String) async {
        // Skip if already loaded
        guard missileTemplates[modelName] == nil else {
            gameLog("⚠️ [MissilePreloader] \(modelName) already loaded, skipping")
            return
        }

        do {
            // Load the 3D model asynchronously
            let entity = try await Entity(named: modelName, in: nil)

            // Store the template
            missileTemplates[modelName] = entity

            gameLog("✅ [MissilePreloader] Loaded \(modelName)")
        } catch {
            gameLog("❌ [MissilePreloader] Failed to load \(modelName): \(error.localizedDescription)")

            // Create a fallback cylinder entity as template
            let fallbackEntity = createFallbackMissile()
            missileTemplates[modelName] = fallbackEntity
            gameLog("⚠️ [MissilePreloader] Using fallback cylinder for \(modelName)")
        }
    }

    /// Create a fallback cylinder missile for models that fail to load
    private func createFallbackMissile() -> Entity {
        let entity = Entity()

        // Create cylinder mesh (30cm long, 4cm diameter)
        let cylinderMesh = MeshResource.generateSphere(radius: 0.1)

        // Use green color as default
        var material = UnlitMaterial(color: .green)

        let modelComponent = ModelComponent(mesh: cylinderMesh, materials: [material])
        entity.components.set(modelComponent)

        return entity
    }

    /// Get a cloned missile entity by model name
    /// - Parameters:
    ///   - modelName: The model name (e.g. "StandardMissile")
    ///   - color: Optional tint color for the missile
    /// - Returns: A cloned entity ready to use, or nil if not loaded
    public func cloneMissile(modelName: String, color: UIColor? = nil) -> Entity? {
        guard let template = missileTemplates[modelName] else {
            gameLog("❌ [MissilePreloader] No template found for \(modelName)")
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

    /// Check if a specific model is loaded
    public func isModelLoaded(modelName: String) -> Bool {
        return missileTemplates[modelName] != nil
    }

    /// Get loading status for debugging
    public func getLoadingStatus() -> String {
        let loaded = missileTemplates.count
        return "Missiles loaded: \(loaded) (\(Int(loadingProgress * 100))%)"
    }
}

extension GameContext {
    public var missilePreloader: MissilePreloader { MissilePreloader.shared }
}
