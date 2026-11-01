//
//  EnemyAIBossSystem.swift
//  HelicopterGame
//
//  Created by Claude on 10/14/25.
//  System for managing boss AI behavior and attacks
//

import RealityKit
import Foundation
import QuartzCore
import UIKit

public class EnemyAIBossSystem: System {
    private static let query = EntityQuery(where: .has(EnemyAIBossComponent.self))
    private weak var cachedRoot: Entity?

    public required init(scene: RealityKit.Scene) {
        gameLog("👑 [EnemyAIBossSystem] System initialized")
    }

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        let bosses = context.scene.performQuery(Self.query)
        guard bosses.contains(where: { _ in true }) else { return }

        // Find player drone for targeting
        let playerDrone = PlayerDroneEntity.find(in: context.scene)

        // Update all boss entities
        for entity in bosses {
            guard let boss = entity as? EnemyDroneBossEntity else {
                gameLog("⚠️ [EnemyAIBossSystem] Entity is not EnemyDroneBossEntity: \(type(of: entity))")
                continue
            }

            // Debug: Print boss status occasionally
            if Int(CACurrentMediaTime() * 10) % 30 == 0 { // Every 3 seconds
                gameLog("👑 [EnemyAIBossSystem] Updating boss \(boss.bossID) at position \(boss.position), mode: \(boss.aiMode)")
            }

            // Update AI behavior
            boss.updateAI(deltaTime: deltaTime, playerDrone: playerDrone)

            // Handle attack spawning when in attack mode
            if boss.aiMode == .attack, let playerDrone = playerDrone {
                handleBossAttack(boss: boss, playerDrone: playerDrone, context: context)
            }

            // Update AI component timestamp
            if var aiComponent = entity.components[EnemyAIBossComponent.self] {
                aiComponent.lastUpdateTime = CACurrentMediaTime()
                entity.components[EnemyAIBossComponent.self] = aiComponent
            }
        }
    }

    private func handleBossAttack(boss: EnemyDroneBossEntity, playerDrone: Entity, context: SceneUpdateContext) {
        var aiComponent = boss.components[EnemyAIBossComponent.self]

        // Check if enough time has passed since last attack spawn
        let currentTime = CACurrentMediaTime()
        if currentTime - (aiComponent?.lastAttackTime ?? 100) < 0.5 { // Don't spam attacks
            return
        }

        // Spawn projectiles based on attack type (root cached, O(n) scan only on miss)
        if cachedRoot?.scene == nil { cachedRoot = findRootEntity(in: context.scene) }
        if let rootEntity = cachedRoot {
            AIBossProjectileSystem.spawnAttack(
                from: boss,
                attackType: boss.currentAttackType,
                targetPosition: playerDrone.position,
                addingTo: rootEntity
            )

            // Update last attack time
            aiComponent?.lastAttackTime = currentTime
            boss.components[EnemyAIBossComponent.self] = aiComponent

            gameLog("👑 [EnemyAIBossSystem] Boss \(boss.bossID) launched \(boss.currentAttackType) attack!")
        }
    }

    private func findRootEntity(in scene: Scene) -> Entity? {
        // Find the root entity to spawn projectiles under
        let allEntitiesQuery = EntityQuery(where: .has(Transform.self))

        for entity in scene.performQuery(allEntitiesQuery) {
            // Look for entity named "Root" or similar
            if entity.name.contains("Root") || entity.name.contains("World") {
                return entity
            }

            // If we find the player drone, use its parent as root
            if let playerDrone = PlayerDroneEntity.findRecursive(in: entity) {
                return playerDrone.parent
            }
        }

        // Fallback: return first entity with children
        for entity in scene.performQuery(allEntitiesQuery) {
            if !entity.children.isEmpty {
                return entity
            }
        }

        return nil
    }
}

// MARK: - Boss Spawner

public class EnemyDroneBossSpawner {
    private var spawnedBoss: EnemyDroneBossEntity?
    private var hasSpawnedBoss = false
    private var rootEntity: Entity?
    private var playerDrone: Entity?

    public init() {}

    public func startSpawning(in rootEntity: Entity, playerDrone: Entity?) {
        // Store references for wave-based spawning
        self.rootEntity = rootEntity
        self.playerDrone = playerDrone
        gameLog("👑 [BossSpawner] Ready for wave-based boss spawning")
    }

    public func update(in rootEntity: Entity, playerDrone: Entity?) {
        // Update stored references
        self.rootEntity = rootEntity
        self.playerDrone = playerDrone

        // Check if boss was destroyed
        if let boss = spawnedBoss, boss.parent == nil {
            gameLog("👑 [BossSpawner] Boss was destroyed")
            spawnedBoss = nil
            hasSpawnedBoss = false

            // Don't automatically respawn - let wave system control boss spawning
            gameLog("👑 [BossSpawner] Waiting for next boss wave to spawn boss")
        }

        // Check if it's a boss wave and no boss is spawned
        if GameContext.shared.waves.shouldSpawnBoss() && !hasSpawnedBoss {
            gameLog("👑 [BossSpawner] Boss wave detected - spawning boss for Wave \(GameContext.shared.waves.currentWave)")
            spawnBoss(in: rootEntity, playerDrone: playerDrone)
            hasSpawnedBoss = true
        }
    }

    /// Manually spawn a boss (called by wave system)
    public func spawnBossForWave(in rootEntity: Entity, playerDrone: Entity?) {
        if hasSpawnedBoss {
            gameLog("👑 [BossSpawner] Boss already spawned for this wave")
            return
        }

        gameLog("👑 [BossSpawner] Spawning boss for Wave \(GameContext.shared.waves.currentWave)")
        spawnBoss(in: rootEntity, playerDrone: playerDrone)
        hasSpawnedBoss = true
    }

    public func stopSpawning() {
        // Remove boss if exists
        spawnedBoss?.removeFromParent()
        spawnedBoss = nil
        hasSpawnedBoss = false
        rootEntity = nil
        playerDrone = nil
        gameLog("👑 [BossSpawner] Stopped boss spawning")
    }

    /// Reset boss spawning flag (called when wave changes from boss wave to normal wave)
    public func resetBossSpawnFlag() {
        hasSpawnedBoss = false
        gameLog("👑 [BossSpawner] Reset boss spawn flag for new wave cycle")
    }

    private func spawnBoss(in rootEntity: Entity, playerDrone: Entity?) {
        // Determine spawn position (far from player)
        let basePosition: SIMD3<Float>
        if let playerDrone = playerDrone {
            // Spawn 20 meters away from player in a random direction
            let angle = Float.random(in: 0...(2 * Float.pi))
            let distance: Float = 3
            basePosition = SIMD3<Float>(
                playerDrone.position.x + cos(angle) * distance,
                playerDrone.position.y + 3.0, // Spawn higher up
                playerDrone.position.z + sin(angle) * distance
            )
        } else {
            // Spawn at default location
            basePosition = SIMD3<Float>(0, 5, -20)
        }

        // Create boss entity
        let bossID = "Boss_\(UUID().uuidString.prefix(8))"
        let boss = EnemyDroneBossEntity(bossID: bossID, spawnPosition: basePosition)

        // Add to scene
        rootEntity.addChild(boss)
        spawnedBoss = boss

        // Play boss spawn sound
        GameContext.shared.sound.playBossSpawnSound(entity: boss)

        // Create boss spawn effect
        createBossSpawnEffect(at: basePosition, in: rootEntity)

        gameLog("👑 [BossSpawner] Spawned boss \(bossID) at position \(basePosition)")
    }

    private func createBossSpawnEffect(at position: SIMD3<Float>, in rootEntity: Entity) {
        // Create dramatic spawn visualization
        let spawnEffect = Entity()
        spawnEffect.name = "BossSpawnEffect"
        spawnEffect.position = position

        // Create glowing platform
        let platformMesh = MeshResource.generateCylinder(height: 0.2, radius: 1.5)
        var material = UnlitMaterial(color: .red)

        let platformModel = ModelEntity(mesh: platformMesh, materials: [material])
        spawnEffect.addChild(platformModel)

        // Add to scene
        rootEntity.addChild(spawnEffect)

        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            spawnEffect.removeFromParent()
        }

        gameLog("👑 [BossSpawner] Created boss spawn effect")
    }

    public var isBossAlive: Bool {
        return spawnedBoss?.parent != nil
    }

    public func getBoss() -> EnemyDroneBossEntity? {
        return spawnedBoss
    }
}
