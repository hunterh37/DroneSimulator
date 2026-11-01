//
//  AIBossProjectileSystem.swift
//  HelicopterGame
//
//  Created by Claude on 10/14/25.
//  System for managing boss attack projectiles
//

import RealityKit
import Foundation
import QuartzCore
import UIKit

/// Component for boss projectiles
public struct AIBossProjectileComponent: Component {
    public var velocity: SIMD3<Float>
    public var lifetime: Float
    public var damage: Float
    public var attackType: BossAttackType
    public var spawnTime: TimeInterval

    public init(velocity: SIMD3<Float>, lifetime: Float = 5.0, damage: Float = 20.0, attackType: BossAttackType) {
        self.velocity = velocity
        self.lifetime = lifetime
        self.damage = damage
        self.attackType = attackType
        self.spawnTime = CACurrentMediaTime()
    }
}

/// System for updating boss projectiles
public class AIBossProjectileSystem: System {
    private static let query = EntityQuery(where: .has(AIBossProjectileComponent.self))

    public required init(scene: RealityKit.Scene) {
        gameLog("💥 [AIBossProjectileSystem] System initialized")
    }

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        let currentTime = CACurrentMediaTime()

        for entity in context.scene.performQuery(Self.query) {
            guard var projectile = entity.components[AIBossProjectileComponent.self] else { continue }

            // Check lifetime
            let age = currentTime - projectile.spawnTime
            if age > Double(projectile.lifetime) {
                entity.removeFromParent()
                continue
            }

            // Move projectile
            entity.position += projectile.velocity * deltaTime

            // Check for collision with player
            if let collision = checkPlayerCollision(entity: entity, in: context.scene) {
                handlePlayerHit(entity: entity, projectile: projectile, player: collision)
                entity.removeFromParent()
            }
        }
    }

    private func checkPlayerCollision(entity: Entity, in scene: Scene) -> Entity? {
        // Uses the shared player-drone lookup (fast O(1) cache path with a scene-scan
        // fallback), then applies this system's collision-distance check.
        guard let player = PlayerDroneEntity.find(in: scene) else {
            return nil
        }

        let distance = length(entity.position - player.position)
        return distance < 0.5 ? player : nil // Collision threshold
    }

    private func handlePlayerHit(entity: Entity, projectile: AIBossProjectileComponent, player: Entity) {
        gameLog("💥 [AIBossProjectileSystem] Boss projectile hit player! Damage: \(projectile.damage)")

        // Apply damage to player drone and health systems
        if let playerDrone = player as? PlayerDroneEntity {
            // Update PlayerHealthManager (for UI health bar and game over detection)
            let damageAmount = Int(projectile.damage / 5.0) // Convert boss damage to health points (10-30 damage -> 2-6 HP)
            let playerDied = GameContext.shared.health.localPlayerHealth.takeDamage(damageAmount)

            gameLog("💥 [AIBossProjectileSystem] Applied \(damageAmount) damage. Health: \(GameContext.shared.health.localPlayerHealth.currentHealth)/\(GameContext.shared.health.localPlayerHealth.maxHealth)")

            // Also update the component on the drone to keep them in sync
            if var healthComponent = playerDrone.components[PlayerHealthComponent.self] {
                healthComponent.currentHealth = GameContext.shared.health.localPlayerHealth.currentHealth
                healthComponent.isAlive = GameContext.shared.health.localPlayerHealth.isAlive
                playerDrone.components[PlayerHealthComponent.self] = healthComponent
            }

            // Check if player died and post notification
            if playerDied {
                gameLog("💀 [AIBossProjectileSystem] Player died from boss attack!")

                // Post death notification for game over screen
                NotificationCenter.default.post(
                    name: .playerDied,
                    object: nil
                )
            }
        }

        // Visual feedback could be added here
    }

    /// Spawn projectiles based on attack type
    public static func spawnAttack(
        from boss: EnemyDroneBossEntity,
        attackType: BossAttackType,
        targetPosition: SIMD3<Float>,
        addingTo rootEntity: Entity
    ) {
        gameLog("💥 [AIBossProjectileSystem] Spawning \(attackType) attack from boss \(boss.bossID)")

        switch attackType {
        case .swarm:
            spawnSwarmAttack(from: boss, targetPosition: targetPosition, addingTo: rootEntity)
        case .wave:
            spawnWaveAttack(from: boss, targetPosition: targetPosition, addingTo: rootEntity)
        case .burst:
            spawnBurstAttack(from: boss, targetPosition: targetPosition, addingTo: rootEntity)
        }
    }

    // MARK: - Swarm Attack
    // Many small projectiles in a spread pattern

    private static func spawnSwarmAttack(from boss: EnemyDroneBossEntity, targetPosition: SIMD3<Float>, addingTo rootEntity: Entity) {
        let projectileCount = 15
        let spreadAngle: Float = .pi / 3 // 60 degree spread

        for i in 0..<projectileCount {
            // Calculate spread direction
            let angleOffset = spreadAngle * (Float(i) / Float(projectileCount - 1) - 0.5)

            // Base direction towards target
            let baseDirection = normalize(targetPosition - boss.position)

            // Create rotation quaternion for spread
            let spreadRotation = simd_quatf(angle: angleOffset, axis: SIMD3<Float>(0, 1, 0))
            let projectileDirection = spreadRotation.act(baseDirection)

            let velocity = projectileDirection * 3.0 // Medium speed

            let projectile = createProjectile(
                at: boss.position + SIMD3<Float>(0, 0, 0), // Spawn at boss position
                velocity: velocity,
                attackType: BossAttackType.swarm,
                scale: 0.05, // Small projectiles
                color: UIColor.cyan
            )

            rootEntity.addChild(projectile)
        }

        gameLog("💥 Spawned swarm attack with \(projectileCount) projectiles")
    }

    // MARK: - Wave Attack
    // Medium-sized projectiles in a wave formation

    private static func spawnWaveAttack(from boss: EnemyDroneBossEntity, targetPosition: SIMD3<Float>, addingTo rootEntity: Entity) {
        let projectileCount = 8
        let waveRadius: Float = 2.0

        for i in 0..<projectileCount {
            let angle = (Float(i) / Float(projectileCount)) * 2 * .pi

            // Position projectiles in a circle around the boss
            let offset = SIMD3<Float>(
                cos(angle) * waveRadius,
                sin(angle) * 0.5, // Some vertical variation
                sin(angle) * waveRadius
            )

            let spawnPosition = boss.position + offset

            // All projectiles move towards target
            let direction = normalize(targetPosition - spawnPosition)
            let velocity = direction * 4.0 // Faster than swarm

            let projectile = createProjectile(
                at: spawnPosition,
                velocity: velocity,
                attackType: BossAttackType.wave,
                scale: 0.1, // Medium projectiles
                color: UIColor.orange
            )

            rootEntity.addChild(projectile)
        }

        gameLog("💥 Spawned wave attack with \(projectileCount) projectiles")
    }

    // MARK: - Burst Attack
    // Large fast projectiles in rapid succession

    private static func spawnBurstAttack(from boss: EnemyDroneBossEntity, targetPosition: SIMD3<Float>, addingTo rootEntity: Entity) {
        let projectileCount = 5

        // Spawn projectiles with slight delay between each (handled by rapid succession in time)
        for i in 0..<projectileCount {
            let delay = Double(i) * 0.1 // 0.1 second between each projectile

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Direct line to target with slight variation
                let baseDirection = normalize(targetPosition - boss.position)

                // Add slight random variation
                let randomX = Float.random(in: -0.1...0.1)
                let randomY = Float.random(in: -0.1...0.1)
                let randomZ = Float.random(in: -0.1...0.1)
                let variation = SIMD3<Float>(randomX, randomY, randomZ)

                let direction = normalize(baseDirection + variation)
                let velocity = direction * 8.0 // Very fast

                let projectile = createProjectile(
                    at: boss.position + SIMD3<Float>(0, 0, -0.5), // Slightly in front of boss
                    velocity: velocity,
                    attackType: BossAttackType.burst,
                    scale: 0.15, // Large projectiles
                    color: UIColor.red
                )

                boss.parent?.addChild(projectile)
            }
        }

        gameLog("💥 Spawned burst attack with \(projectileCount) projectiles (rapid succession)")
    }

    // MARK: - Projectile Creation

    private static func createProjectile(
        at position: SIMD3<Float>,
        velocity: SIMD3<Float>,
        attackType: BossAttackType,
        scale: Float,
        color: UIColor
    ) -> Entity {
        let projectile = Entity()
        projectile.position = position

        // Try to clone preloaded 3D model
        if let clonedModel = GameContext.shared.bossProjectilePreloader.cloneProjectile(attackType: attackType, color: color) {
            // Use preloaded USDZ model
            projectile.addChild(clonedModel)
            gameLog("💥 [AIBossProjectileSystem] Using preloaded \(attackType) model")
        } else {
            // Fallback: Create procedural sphere (should rarely happen if preloader worked)
            gameLog("⚠️ [AIBossProjectileSystem] Preloaded model not available for \(attackType), using fallback")
            let mesh = MeshResource.generateSphere(radius: scale)

            // Different visual styles based on attack type
            let material: Material
            switch attackType {
            case .swarm:
                // Glowing cyan for swarm
                var unlitMaterial = UnlitMaterial(color: color)
                material = unlitMaterial
            case .wave:
                // Semi-transparent orange for wave
                var simpleMaterial = SimpleMaterial(color: color, roughness: 0.2, isMetallic: true)
                material = simpleMaterial
            case .burst:
                // Bright red for burst
                var unlitMaterial = UnlitMaterial(color: color)
                material = unlitMaterial
            }

            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
            projectile.addChild(modelEntity)
        }

        // Add collision component (same for all types)
        let collisionShape = ShapeResource.generateSphere(radius: scale)
        projectile.components.set(CollisionComponent(shapes: [collisionShape]))

        // Add projectile component with attack-specific damage
        let damage: Float
        switch attackType {
        case .swarm:
            damage = 4 // Lower damage, but many projectiles
        case .wave:
            damage = 6 // Medium damage
        case .burst:
            damage = 8 // High damage
        }

        let component = AIBossProjectileComponent(
            velocity: velocity,
            lifetime: 5.0,
            damage: damage,
            attackType: attackType
        )
        projectile.components.set(component)

        return projectile
    }
}
