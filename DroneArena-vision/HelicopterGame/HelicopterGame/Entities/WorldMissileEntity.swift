//
//  WorldMissileEntity.swift
//  HelicopterGame
//
//  Created by Claude on 11/12/25.
//

import RealityKit
import simd
import Foundation
import QuartzCore
import UIKit

// MARK: - World Missile Component

/// Component for missiles fired from above (world missile system)
public struct WorldMissileComponent: Component {
    public let velocity: SIMD3<Float>
    public let creationTime: TimeInterval
    public let lifetime: Float
    public let damage: Int

    public init(velocity: SIMD3<Float>, creationTime: TimeInterval, lifetime: Float, damage: Int = 20) {
        self.velocity = velocity
        self.creationTime = creationTime
        self.lifetime = lifetime
        self.damage = damage
    }
}

// MARK: - World Missile Entity

/// Missile entity fired from above in the world missile system
public class WorldMissileEntity: Entity, HasModel, HasCollision {

    public static var showCollisionDebug: Bool = false

    public init(velocity: SIMD3<Float>, lifetime: Float = 3.0, playerColor: UIColor? = nil, trailColor: UIColor? = nil, modelName: String? = nil, collisionRadius: Float = 0.2, damage: Int = 20) {
        super.init()

        // Try to use preloaded model first, then fallback to async loading
        var modelLoaded = false
        if let modelName = modelName {
            // Try to clone preloaded model
            if let clonedModel = GameContext.shared.missilePreloader.cloneMissile(modelName: modelName, color: playerColor) {
                // Add cloned model to missile entity
                clonedModel.scale = SIMD3<Float>(repeating: 0.3)
                self.addChild(clonedModel)
                modelLoaded = true
            }
        }

        // Fallback to async loading or procedural if preload not available
        if !modelLoaded {
            if let modelName = modelName {
                setupMissileVisualFromUSDZ(modelName: modelName, color: playerColor, collisionRadius: collisionRadius)
            } else {
                setupMissileVisual(color: playerColor)
            }
        }

        setupMissilePhysics(collisionRadius: collisionRadius)

        // Add world missile component with damage value
        let creationTime = CACurrentMediaTime()
        self.components.set(WorldMissileComponent(
            velocity: velocity,
            creationTime: creationTime,
            lifetime: lifetime,
            damage: damage
        ))

        // Missiles fire straight down, so rotate to point downward
        // Default cylinder has height along Y-axis, rotate 180 degrees around X-axis to point down
        self.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))

        // Add laser trail effect using trail color (or player color as fallback)
        let effectiveTrailColor = trailColor ?? playerColor
        addMissileTrail(playerColor: effectiveTrailColor)
    }

    required init() {
        super.init()
    }

    private func setupMissileVisualFromUSDZ(modelName: String, color: UIColor?, collisionRadius: Float) {
        Task {
            do {
                // Try multiple file name variations
                let possibleNames = [modelName, "Missile"] // Fallback to default Missile
                var loadedModel: Entity?

                for name in possibleNames {
                    if let modelURL = Bundle.main.url(forResource: name, withExtension: "usdz") {
                        loadedModel = try await Entity(contentsOf: modelURL)
                        break
                    }
                }

                if let model = loadedModel {
                    self.addChild(model)

                    // Apply player color tint if available
                    if let color = color {
                        applyColorTintToModel(model, color: color)
                    }
                } else {
                    self.setupMissileVisual(color: color)
                }
            } catch {
                self.setupMissileVisual(color: color)
            }
        }
    }

    private func applyColorTintToModel(_ entity: Entity, color: UIColor) {
        // Recursively apply color tint to all ModelComponents in the hierarchy
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

        // Apply to children
        for child in entity.children {
            applyColorTintToModel(child, color: color)
        }
    }

    private func setupMissileVisual(color: UIColor?) {
        // Create cylinder missile (laser-like)
        let cylinderMesh = MeshResource.generateCylinder(height: 0.3, radius: 0.02) // 30cm long, 2cm radius

        // Use player color or default to cyan
        let missileColor = color ?? UIColor.cyan
        var material = UnlitMaterial(color: missileColor)
        material.color = .init(tint: missileColor)

        let modelComponent = ModelComponent(mesh: cylinderMesh, materials: [material])
        self.components.set(modelComponent)

        // Set missile scale
        self.scale = SIMD3<Float>(repeating: 0.4)
    }

    private func setupMissilePhysics(collisionRadius: Float) {
        // No CollisionComponent - using manual distance checking instead
        if WorldMissileEntity.showCollisionDebug {
            let shape = ShapeResource.generateCapsule(height: 0.3, radius: collisionRadius)
            addCollisionDebugVisualizer(collisionShape: shape)
        }
    }

    private func addCollisionDebugVisualizer(collisionShape: ShapeResource) {
        let shapeBounds = collisionShape.bounds
        let debugMesh: MeshResource = MeshResource.generateCylinder(height: 0.3, radius: shapeBounds.extents.x / 2)

        var debugMaterial = UnlitMaterial(color: .red)
        debugMaterial.color = .init(tint: .red.withAlphaComponent(0.3))

        let debugEntity = Entity()
        debugEntity.name = "CollisionDebugVisualizer"
        debugEntity.components.set(ModelComponent(mesh: debugMesh, materials: [debugMaterial]))

        self.addChild(debugEntity)
    }

    private func addMissileTrail(playerColor: UIColor?) {
        let trailColor = playerColor ?? UIColor.cyan
        let missileTrail = MissileTrailParticleEntity(trailColor: trailColor)
        self.addChild(missileTrail)
    }
}

// MARK: - World Missile System

/// System that updates world missiles (missiles fired from above)
public class WorldMissileSystem: System {
    static let query = EntityQuery(where: .has(WorldMissileComponent.self))
    static let droneTargetQuery = EntityQuery(where: .has(DroneMissileComponent.self))
    static let playerTargetQuery = EntityQuery(where: .has(PlayerHealthComponent.self))
    static let bossTargetQuery = EntityQuery(where: .has(EnemyAIBossComponent.self))

    public required init(scene: RealityKit.Scene) {
    }

    public func update(context: SceneUpdateContext) {
        let currentTime = CACurrentMediaTime()
        // Snapshot missiles (entities are removed mid-loop) and gather targets once per frame
        let missiles = Array(context.scene.performQuery(Self.query))
        guard !missiles.isEmpty else { return }
        var targets: [Entity] = []
        targets.append(contentsOf: context.scene.performQuery(Self.droneTargetQuery))
        targets.append(contentsOf: context.scene.performQuery(Self.playerTargetQuery))
        targets.append(contentsOf: context.scene.performQuery(Self.bossTargetQuery))

        for entity in missiles {
            guard entity.scene != nil else { continue }
            guard let missileComponent = entity.components[WorldMissileComponent.self] else { continue }

            let deltaTime = Float(context.deltaTime)
            let age = Float(currentTime) - Float(missileComponent.creationTime)

            // Check if missile has expired
            if age >= missileComponent.lifetime {
                entity.removeFromParent()
                continue
            }

            // Manually update position (missiles move downward)
            let movement = missileComponent.velocity * deltaTime
            entity.position += movement

            // Check for collisions using distance checking
            checkMissileCollisions(missile: entity, in: context.scene, targets: targets)
        }
    }

    private func checkMissileCollisions(missile: Entity, in scene: Scene, targets allTargets: [Entity]) {
        guard let missileComponent = missile.components[WorldMissileComponent.self] else { return }

        let missilePosition = missile.position

        // Only check collisions if missile is close to ground (optimization)
        // Skip collision checks if missile is still high up
        guard missilePosition.y < 5.0 else { return }

        // Query for all potential targets (same as drone missiles)

        for entity in allTargets {
            guard entity != missile, entity.scene != nil else { continue }

            // Get target-specific collision radius
            let targetRadius = getCollisionRadius(for: entity)
            let distance = length(entity.position - missilePosition)

            if distance < targetRadius {
                handleMissileHit(missile: missile, target: entity, scene: scene)
                return
            }
        }

        // Check if missile hit ground (Y < 0)
        if missilePosition.y < 0 {
            handleMissileHit(missile: missile, target: nil, scene: scene)
        }
    }

    private func getCollisionRadius(for entity: Entity) -> Float {
        // Boss has largest collision radius
        if entity is EnemyDroneBossEntity {
            return 2.0
        }
        // Remote player drones
        else if entity is RemoteDroneEntity {
            return 0.6
        }
        // Local player drone
        else if entity is PlayerDroneEntity {
            return 0.6
        }
        // Regular enemy drones
        else if entity is EnemyDroneEntity {
            return 0.5
        }
        // Default fallback
        else {
            return 0.5
        }
    }

    private func handleMissileHit(missile: Entity, target: Entity?, scene: Scene) {
        if let target = target {
            // Create explosion effect at impact point
            let explosionPosition = target.position
            let explosion = ExplosionEntity.createLargeExplosion(at: explosionPosition)
            if let parent = missile.parent {
                parent.addChild(explosion)
            }

            // Local player drone collision
            if let playerDrone = target as? PlayerDroneEntity {
                let missileDamage = missile.components[WorldMissileComponent.self]?.damage ?? 20

                // Apply damage to player health
                playerDrone.takeDamage()
                GameContext.shared.health.localPlayerHealth.takeDamage(missileDamage)

                // Post notification for damage flash UI
                NotificationCenter.default.post(name: .playerTookDamage, object: nil)
            }
            // Boss collision handling
            else if let boss = target as? EnemyDroneBossEntity {
                let missileDamage = missile.components[WorldMissileComponent.self]?.damage ?? 20
                boss.takeDamage(Float(missileDamage))

                // Force immediate UI update
                Task { @MainActor in
                    GameContext.shared.bossPosition.currentHealth = boss.health
                    GameContext.shared.bossPosition.maxHealth = boss.maxHealth
                }

                // Check if boss was destroyed
                if boss.health <= 0 {
                    let healthManager = GameContext.shared.health
                    let networking = MultiplayerNetworking()
                    let killfeedEntry = KillfeedEntry(
                        killerPlayerID: networking.localPlayerID,
                        killedPlayerID: "Boss_\(boss.bossID)",
                        timestamp: CACurrentMediaTime()
                    )
                    healthManager.killfeedEntries.insert(killfeedEntry, at: 0)

                    let rankManager = PlayerRankManager()
                    rankManager.localPlayerRank.addXP(100)
                    rankManager.saveRank()
                }
            }
            // Remote player drone collision (multiplayer)
            else if let remoteDrone = target as? RemoteDroneEntity {
                let missileDamage = missile.components[WorldMissileComponent.self]?.damage ?? 20

                // Send damage message to the victim player
                Task {
                    await sendDamageMessage(victimPlayerID: remoteDrone.playerID, victimPosition: target.position, damage: missileDamage)
                }
            }
            // Enemy drone collision
            else if let enemyDrone = target as? EnemyDroneEntity {
                enemyDrone.takeDamage()

                // Add killfeed entry for bot kill
                let healthManager = GameContext.shared.health
                let networking = MultiplayerNetworking()
                let killfeedEntry = KillfeedEntry(
                    killerPlayerID: networking.localPlayerID,
                    killedPlayerID: "Bot_\(enemyDrone.enemyID)",
                    timestamp: CACurrentMediaTime()
                )
                healthManager.killfeedEntries.insert(killfeedEntry, at: 0)

                // Award 10 XP for killing AI drone
                let rankManager = PlayerRankManager()
                rankManager.localPlayerRank.addXP(10)
                rankManager.saveRank()
            }
        } else {
            // Ground impact explosion
            let groundExplosion = ExplosionEntity.createSmallExplosion(at: missile.position)
            if let parent = missile.parent {
                parent.addChild(groundExplosion)
            }
        }

        // Remove missile
        missile.removeFromParent()
    }

    private func sendDamageMessage(victimPlayerID: String, victimPosition: SIMD3<Float>, damage: Int) async {
        NotificationCenter.default.post(
            name: .droneDamageDealt,
            object: nil,
            userInfo: [
                "victimPlayerID": victimPlayerID,
                "damageAmount": damage,
                "victimPosition": victimPosition
            ]
        )
    }
}
