//
//  EnemyDroneAISystem.swift
//  HelicopterGame
//
//  Created by Claude on 10/5/25.
//

import RealityKit
import Foundation
import QuartzCore
import UIKit

public class EnemyDroneAISystem: System {
    private static let query = EntityQuery(where: .has(EnemyAIComponent.self))

    public required init(scene: RealityKit.Scene) {
    }

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        let enemies = context.scene.performQuery(Self.query)
        guard enemies.contains(where: { _ in true }) else { return }

        // Find player drone for targeting
        let playerDrone = PlayerDroneEntity.find(in: context.scene)

        // Update all enemy drones
        for entity in enemies {
            guard let enemyDrone = entity as? EnemyDroneEntity else {
                continue
            }

            // Update AI behavior
            enemyDrone.updateAI(deltaTime: deltaTime, playerDrone: playerDrone)

            // Update AI component timestamp
            if var aiComponent = entity.components[EnemyAIComponent.self] {
                aiComponent.lastUpdateTime = CACurrentMediaTime()
                entity.components[EnemyAIComponent.self] = aiComponent
            }
        }
    }
}

// MARK: - Enemy Drone Spawner

public class EnemyDroneSpawner {
    private var spawnedEnemies: [EnemyDroneEntity] = []
    private var maxEnemies: Int = 3
    private var spawnRadius: Float = 20.0
    private var lastSpawnTime: TimeInterval = 0
    private var spawnCooldown: TimeInterval = 5.0 // 5 seconds between spawns

    public init() {}

    public func setup(maxEnemies: Int = 3, spawnRadius: Float = 20.0, spawnCooldown: TimeInterval = 5.0) {
        self.maxEnemies = maxEnemies
        self.spawnRadius = spawnRadius
        self.spawnCooldown = spawnCooldown
    }

    public func startSpawning(in rootEntity: Entity, playerDrone: Entity?) {
        // Initial spawn of enemies
        for i in 0..<maxEnemies {
            spawnEnemy(in: rootEntity, enemyIndex: i, playerDrone: playerDrone)
        }

        lastSpawnTime = CACurrentMediaTime()
    }

    public func update(in rootEntity: Entity, playerDrone: Entity?) {
        let currentTime = CACurrentMediaTime()

        // Remove destroyed enemies from tracking list
        spawnedEnemies.removeAll { enemy in
            enemy.parent == nil
        }

        // Spawn new enemies if below max and cooldown has passed
        if spawnedEnemies.count < maxEnemies && currentTime - lastSpawnTime >= spawnCooldown {
            let enemyIndex = spawnedEnemies.count
            spawnEnemy(in: rootEntity, enemyIndex: enemyIndex, playerDrone: playerDrone)
            lastSpawnTime = currentTime
        }
    }

    public func stopSpawning() {
        // Remove all spawned enemies
        for enemy in spawnedEnemies {
            enemy.removeFromParent()
        }
        spawnedEnemies.removeAll()
    }

    private func spawnEnemy(in rootEntity: Entity, enemyIndex: Int, playerDrone: Entity?) {
        // Generate spawn position around the player or world center
        let basePosition: SIMD3<Float>
        if let playerDrone = playerDrone {
            basePosition = playerDrone.position
        } else {
            basePosition = SIMD3<Float>(0, 2, 0)
        }

        // Random position around the base position
        let angle = Float.random(in: 0...(2 * Float.pi))
        let distance = Float.random(in: (spawnRadius * 0.5)...spawnRadius)
        let height = Float.random(in: 1.5...4.0) // Random height for varied patrol levels

        let spawnPosition = SIMD3<Float>(
            basePosition.x + cos(angle) * distance,
            height,
            basePosition.z + sin(angle) * distance
        )

        // Create spawner visualization at the spawn position
        createSpawnerVisualization(at: spawnPosition, in: rootEntity)

        // Create enemy drone
        let enemyID = "Enemy_\(enemyIndex)_\(UUID().uuidString.prefix(8))"
        let enemyDrone = EnemyDroneEntity(enemyID: enemyID, spawnPosition: spawnPosition)

        // Add to scene
        rootEntity.addChild(enemyDrone)
        spawnedEnemies.append(enemyDrone)
    }

    private func createSpawnerVisualization(at position: SIMD3<Float>, in rootEntity: Entity) {
        // Create spawner entity with 3D model visualization
        let spawnerEntity = Entity()
        spawnerEntity.name = "Spawner_\(UUID().uuidString.prefix(8))"
        spawnerEntity.position = position

        // Load Spawner.usdz model asynchronously
        Task {
            do {
                if let spawnerURL = Bundle.main.url(forResource: "Spawner", withExtension: "usdz") {
                    let spawnerModel = try await Entity(contentsOf: spawnerURL)

                    await MainActor.run {
                        // Scale appropriately (0.2 scale for visibility)
                        spawnerModel.scale = SIMD3<Float>(repeating: 0.2)
                        spawnerEntity.addChild(spawnerModel)
                    }
                } else {
                    // Fallback: Create a simple visual marker if USDZ not found
                    await MainActor.run {
                        createFallbackSpawnerVisual(for: spawnerEntity)
                    }
                }
            } catch {
                await MainActor.run {
                    createFallbackSpawnerVisual(for: spawnerEntity)
                }
            }
        }

        // Add spawner entity to scene
        rootEntity.addChild(spawnerEntity)
    }

    private func createFallbackSpawnerVisual(for spawnerEntity: Entity) {
        // Create a simple glowing platform as fallback
        let platformMesh = MeshResource.generateCylinder(height: 0.1, radius: 0.3)
        var material = UnlitMaterial(color: .cyan)
        material.color = .init(tint: .cyan.withAlphaComponent(0.6))

        let platformModel = ModelEntity(mesh: platformMesh, materials: [material])
        spawnerEntity.addChild(platformModel)
    }

    public var currentEnemyCount: Int {
        return spawnedEnemies.count
    }

    public func getSpawnedEnemies() -> [EnemyDroneEntity] {
        return spawnedEnemies
    }
}
