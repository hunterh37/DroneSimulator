//
//  DroneMissileComponent.swift
//  HelicopterGame
//
//  Created by Claude on 10/5/25.
//

import RealityKit
import simd
import Foundation
import QuartzCore
import UIKit

// MARK: - Notification Names
extension Notification.Name {
    static let droneDamageDealt = Notification.Name("droneDamageDealt")
    static let playerDied = Notification.Name("playerDied")
}

// MARK: - Drone Missile Component

public struct DroneMissileComponent: Component {
    public var canFireMissiles: Bool = true
    public var missileSpeed: Float = 5.0  // m/s (reduced from 15.0 for better visibility)
    public var missileLifetime: Float = 3.0  // seconds
    public var fireRate: Float = 0.5  // seconds between shots
    public var lastFireTime: TimeInterval = 0.0

    public init(canFireMissiles: Bool = true, missileSpeed: Float = 5.0, missileLifetime: Float = 3.0, fireRate: Float = 0.5) {
        self.canFireMissiles = canFireMissiles
        self.missileSpeed = missileSpeed
        self.missileLifetime = missileLifetime
        self.fireRate = fireRate
    }
}

// MARK: - Missile Entity Component

public struct MissileComponent: Component {
    public let velocity: SIMD3<Float>
    public let creationTime: TimeInterval
    public let lifetime: Float
    public let ownerDroneId: String?
    public let damage: Int // Damage dealt by this missile

    public init(velocity: SIMD3<Float>, creationTime: TimeInterval, lifetime: Float, ownerDroneId: String? = nil, damage: Int = 20) {
        self.velocity = velocity
        self.creationTime = creationTime
        self.lifetime = lifetime
        self.ownerDroneId = ownerDroneId
        self.damage = damage
    }
}

// MARK: - Missile Entity

public class MissileEntity: Entity, HasModel, HasCollision, HasAnchoring {

    // Debug toggle for collision visualization (set to true to see collision shapes)
    public static var showCollisionDebug: Bool = false

    public init(velocity: SIMD3<Float>, lifetime: Float = 3.0, ownerDroneId: String? = nil, playerColor: UIColor? = nil, trailColor: UIColor? = nil, modelName: String? = nil, collisionRadius: Float = 0.2, damage: Int = 20) {
        super.init()

        // Try to use preloaded model first, then fallback to async loading
        var modelLoaded = false
        if let modelName = modelName {
            // Try to clone preloaded model
            if let clonedModel = GameContext.shared.missilePreloader.cloneMissile(modelName: modelName, color: playerColor) {
                // Add cloned model to missile entity
                clonedModel.scale = SIMD3<Float>(repeating: 0.3) // 15% scale
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

        // Add missile component with damage value
        let creationTime = CACurrentMediaTime()
        self.components.set(MissileComponent(
            velocity: velocity,
            creationTime: creationTime,
            lifetime: lifetime,
            ownerDroneId: ownerDroneId,
            damage: damage
        ))
        
        self.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))

        // Add laser trail effect using trail color (or player color as fallback)
        let effectiveTrailColor = trailColor ?? playerColor
        addMissileTrail(playerColor: effectiveTrailColor)

    }

    required init() {
        super.init()
    }

    private func setupMissileVisualFromUSDZ(modelName: String, color: UIColor?, collisionRadius: Float) {

        // Try to load the USDZ model asynchronously
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
        // Create MUCH LARGER cylinder missile (laser-like) - make it visible!
        let cylinderMesh = MeshResource.generateCylinder(height: 0.3, radius: 0.02) // 30cm long, 4cm diameter

        // Use player color or default to green
        let missileColor = color ?? UIColor.green
        var material = UnlitMaterial(color: missileColor)
        material.color = .init(tint: missileColor)

        let modelComponent = ModelComponent(mesh: cylinderMesh, materials: [material])
        self.components.set(modelComponent)

        // No rotation applied - missile stays at 0 degrees Z rotation
        // Default cylinder has height along Y-axis (vertical orientation)
        self.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))

        // Set missile scale to 0.4
        self.scale = SIMD3<Float>(repeating: 0.4)

    }

    private func setupMissilePhysics(collisionRadius: Float) {
        // No CollisionComponent - using manual distance checking instead
        // Just add debug visualizer if needed
        if MissileEntity.showCollisionDebug {
            let shape = ShapeResource.generateCapsule(height: 0.3, radius: collisionRadius)
            addCollisionDebugVisualizer(collisionShape: shape)
        }
    }

    // Apply initial velocity after missile is added to scene
    public func applyInitialVelocity(_ velocity: SIMD3<Float>) {
        // Set velocity using PhysicsMotionComponent
        var motionComponent = PhysicsMotionComponent(linearVelocity: velocity, angularVelocity: [0, 0, 0])
        self.components.set(motionComponent)
    }

    private func addCollisionDebugVisualizer(collisionShape: ShapeResource) {
        // Visualize the ACTUAL collision shape (capsule), not just bounding box
        let shapeBounds = collisionShape.bounds

        // For capsule: height and radius from the actual shape
        // The collision shape was created with specific height and radius
        // We'll visualize it as a capsule mesh to match exactly

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

// MARK: - Drone Missile System

public class DroneMissileSystem: System {
    static let query = EntityQuery(where: .has(MissileComponent.self))
    static let droneTargetQuery = EntityQuery(where: .has(DroneMissileComponent.self))
    static let playerTargetQuery = EntityQuery(where: .has(PlayerHealthComponent.self))
    static let bossTargetQuery = EntityQuery(where: .has(EnemyAIBossComponent.self))
    static let critterQuery = EntityQuery(where: .has(SafariCritterComponent.self))

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
            guard let missileComponent = entity.components[MissileComponent.self] else { continue }

            let deltaTime = Float(context.deltaTime)
            let age = Float(currentTime) - Float(missileComponent.creationTime)

            // Check if missile has expired
            if age >= missileComponent.lifetime {
                entity.removeFromParent()
                continue
            }

            // Manually update position
            let movement = missileComponent.velocity * deltaTime
            entity.position += movement

            // Check for collisions using distance checking
            checkMissileCollisions(missile: entity, in: context.scene, targets: targets)
        }
    }

    private func checkMissileCollisions(missile: Entity, in scene: Scene, targets allTargets: [Entity]) {
        guard let missileComponent = missile.components[MissileComponent.self] else { return }

        let missilePosition = missile.position

        // Safari targets (nested under SafariWorld, so compare in the missile's parent space)
        for critter in scene.performQuery(Self.critterQuery) {
            guard let c = critter.components[SafariCritterComponent.self], c.state != .popped else { continue }
            let critterPos = critter.position(relativeTo: missile.parent) + SIMD3<Float>(0, c.kind.size, 0)
            if length(critterPos - missilePosition) < c.hitRadius {
                SafariCritterSystem.pop(critter)
                missile.removeFromParent()
                return
            }
        }

        // Query for all potential targets

        for entity in allTargets {
            guard entity != missile, entity.scene != nil else { continue }

            // Skip collision with missile owner
            if let ownerDroneId = missileComponent.ownerDroneId {
                if entity is PlayerDroneEntity && ownerDroneId.contains("-") && ownerDroneId.count >= 32 {
                    continue
                }
                if let remoteDrone = entity as? RemoteDroneEntity, ownerDroneId == remoteDrone.playerID {
                    continue
                }
                if entity.name == ownerDroneId {
                    continue
                }
            }

            // Get target-specific collision radius based on entity type
            let targetRadius = getCollisionRadius(for: entity)
            let distance = length(entity.position - missilePosition)

            if distance < targetRadius {
                handleMissileHit(missile: missile, target: entity, scene: scene)
                return
            }
        }
    }

    private func getCollisionRadius(for entity: Entity) -> Float {
        // Boss has largest collision radius
        if entity is EnemyDroneBossEntity {
            return 2.0 // 2 meter radius for boss (huge target)
        }
        // Remote player drones
        else if entity is RemoteDroneEntity {
            return 0.6 // 60cm radius for remote players
        }
        // Local player drone
        else if entity is PlayerDroneEntity {
            return 0.6 // 60cm radius for local player
        }
        // Regular enemy drones
        else if entity is EnemyDroneEntity {
            return 0.5 // 50cm radius for AI enemies
        }
        // Default fallback
        else {
            return 0.5 // 50cm default
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
                let missileDamage = missile.components[MissileComponent.self]?.damage ?? 20

                // Apply damage to player health
                playerDrone.takeDamage()
                GameContext.shared.health.localPlayerHealth.takeDamage(missileDamage)

                // Post notification for damage flash UI
                NotificationCenter.default.post(name: .playerTookDamage, object: nil)
            }
            // Boss collision handling
            else if let boss = target as? EnemyDroneBossEntity {
                let missileDamage = missile.components[MissileComponent.self]?.damage ?? 20
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

                let missileDamage = missile.components[MissileComponent.self]?.damage ?? 20

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

    // Static method to fire missile from drone - now just uses the parent entity approach
    public static func fireMissile(from drone: Entity, in scene: Scene) {
        // For compatibility, we'll add to the drone's parent
        guard let parent = drone.parent else {
            return
        }
        fireMissile(from: drone, addingTo: parent)
    }

    // Overloaded method that can add to any Entity (like rootEntity)
    public static func fireMissile(from drone: Entity, addingTo parent: Entity, slot: Int = 1) {
        guard var missileComponent = drone.components[DroneMissileComponent.self] else {
            return
        }

        let currentTime = CACurrentMediaTime()

        // Get weapon stats from LoadoutManager for local player (use specified slot)
        let loadoutManager = GameContext.shared.loadout
        let weaponStats = loadoutManager.getCurrentWeaponStats(slot: slot)
        let weaponModelName = loadoutManager.getCurrentWeaponModelName(slot: slot)
        let fireRateOverride = loadoutManager.getFireRate(slot: slot)
        let weaponTrailColor = weaponStats?.trailColor

        // Use weapon-specific fire rate for local player
        let fireRate: Float
        if drone is PlayerDroneEntity {
            fireRate = fireRateOverride
        } else {
            fireRate = missileComponent.fireRate
        }

        // Check fire rate limit
        if currentTime - missileComponent.lastFireTime < TimeInterval(fireRate) {
            return
        }

        // Update last fire time
        missileComponent.lastFireTime = currentTime
        drone.components.set(missileComponent)

        // Play shoot sound for player drone (spatial audio)
        if drone is PlayerDroneEntity {
            GameContext.shared.sound.playShootSound(entity: drone)
        }

        let spawnPosition = drone.position(relativeTo: nil)

        // Calculate forward direction of drone
        let forwardDirection = drone.orientation.act(SIMD3<Float>(0, 0, -1)) // Negative Z is forward

        // Use weapon-specific speed for local player
        let missileSpeed: Float
        if let stats = weaponStats, drone is PlayerDroneEntity {
            missileSpeed = stats.speed
        } else {
            missileSpeed = missileComponent.missileSpeed
        }

        let missileVelocity = forwardDirection * missileSpeed
        
        // Create and add missile to scene
        // Use proper player ID for local player, drone name for others
        let ownerID: String
        let missileColor: UIColor
        let missileTrailColor: UIColor

        if let playerDrone = drone as? PlayerDroneEntity {
            // For local player drone, use the actual local player ID and their color
            let networking = MultiplayerNetworking()
            ownerID = networking.localPlayerID
            missileColor = UIColor(swiftUIColor: GameContext.shared.playerProfile.playerColor)

            // Use weapon-specific trail color if available, otherwise use player color
            if let trailColorHex = weaponTrailColor {
                missileTrailColor = UIColor(hex: trailColorHex) ?? missileColor
            } else {
                missileTrailColor = missileColor
            }
        } else if let remoteDrone = drone as? RemoteDroneEntity {
            // For remote player drone, use their color
            ownerID = drone.name
            missileColor = UIColor(hex: remoteDrone.playerColor) ?? UIColor.green
            missileTrailColor = missileColor
        } else {
            // For other drones (enemy), use the drone name and default color
            ownerID = drone.name
            missileColor = UIColor.orange // Enemy missile color
            missileTrailColor = missileColor
        }

        // Get collision radius and damage from weapon stats
        let collisionRadius: Float
        let missileDamage: Int
        if let stats = weaponStats, drone is PlayerDroneEntity {
            collisionRadius = stats.collisionRadius
            missileDamage = stats.damage
        } else {
            collisionRadius = 0.2 // Default
            missileDamage = 20 // Default damage for enemy drones
        }

        // Get missile count and grid pattern from weapon stats
        let missileCount: Int
        let missileRows: Int
        let missilesPerRow: Int
        let horizontalSpacing: Float
        let verticalSpacing: Float

        if let stats = weaponStats, drone is PlayerDroneEntity {
            missileCount = stats.missileCount
            missileRows = stats.missileRows
            missilesPerRow = stats.missilesPerRow
            horizontalSpacing = stats.horizontalSpacing
            verticalSpacing = stats.verticalSpacing
        } else {
            missileCount = 1 // Default for non-player drones
            missileRows = 1
            missilesPerRow = 1
            horizontalSpacing = 0.15 // Default horizontal spacing
            verticalSpacing = 0.12 // Default vertical spacing
        }

        // Calculate directions for grid positioning
        let rightDirection = drone.orientation.act(SIMD3<Float>(1, 0, 0)) // X-axis (horizontal)
        let upDirection = drone.orientation.act(SIMD3<Float>(0, 1, 0)) // Y-axis (vertical)

        // Spawn missiles in grid pattern
        var missileIndex = 0
        for row in 0..<missileRows {
            for col in 0..<missilesPerRow {
                guard missileIndex < missileCount else { break }

                // Calculate offsets from center
                let centerRow = Float(missileRows - 1) / 2.0
                let centerCol = Float(missilesPerRow - 1) / 2.0

                let rowOffset = (Float(row) - centerRow) * verticalSpacing
                let colOffset = (Float(col) - centerCol) * horizontalSpacing

                // Calculate spawn position for this missile in the grid
                let gridOffset = (rightDirection * colOffset) + (upDirection * rowOffset)
                let offsetSpawnPosition = spawnPosition + gridOffset

                // Optional: Add slight angle spread for barrage effect (smaller than before)
                let spreadAngle: Float
                if missileCount > 4 {
                    // For barrage missiles, add very subtle spread
                    let anglePerMissile: Float = 0.02 // ~1 degree spread (reduced from 0.05)
                    let relativeCol = Float(col) - centerCol
                    spreadAngle = relativeCol * anglePerMissile
                } else {
                    spreadAngle = 0
                }

                // Apply angular spread to velocity
                let spreadRotation = simd_quatf(angle: spreadAngle, axis: SIMD3<Float>(0, 1, 0))
                let spreadForwardDirection = spreadRotation.act(forwardDirection)
                let spreadMissileVelocity = spreadForwardDirection * missileSpeed

                // Create missile with weapon-specific model and stats
                // For player drones: use loadout weapon model
                // For enemy drones: use StandardMissile model
                let missileModelName: String?
                if drone is PlayerDroneEntity {
                    missileModelName = weaponModelName
                } else if drone is EnemyDroneEntity {
                    missileModelName = "StandardMissile"
                } else {
                    missileModelName = nil
                }

                let missile = MissileEntity(
                    velocity: spreadMissileVelocity,
                    lifetime: missileComponent.missileLifetime,
                    ownerDroneId: ownerID,
                    playerColor: missileColor,
                    trailColor: missileTrailColor,
                    modelName: missileModelName,
                    collisionRadius: collisionRadius,
                    damage: missileDamage
                )
                missile.position = offsetSpawnPosition

                // Use drone orientation directly
                missile.orientation = drone.orientation

                parent.addChild(missile)

                // Play missile whoosh sound on the missile entity
                GameContext.shared.sound.playMissileWhooshSound(entity: missile)

                missileIndex += 1
            }
        }

    }

}

// MARK: - Entity Extensions

public extension Entity {
    func addDroneMissileCapability(
        missileSpeed: Float = 15.0,
        missileLifetime: Float = 3.0,
        fireRate: Float = 0.5
    ) {
        let component = DroneMissileComponent(
            canFireMissiles: true,
            missileSpeed: missileSpeed,
            missileLifetime: missileLifetime,
            fireRate: fireRate
        )
        self.components.set(component)

    }
}
