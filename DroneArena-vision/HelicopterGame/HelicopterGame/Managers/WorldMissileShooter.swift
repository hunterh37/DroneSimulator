//
//  WorldMissileShooter.swift
//  HelicopterGame
//
//  Created by Claude on 11/12/25.
//

import Foundation
import RealityKit
import simd
import UIKit
import Combine

/// Manager for firing missiles from above onto world positions
/// Uses the same missile system as PlayerDrone but fires from a high altitude straight down
@MainActor
public class WorldMissileShooter: ObservableObject {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `WorldMissileShooter.shared` directly; everyone else
    // must go through GameContext.shared.worldMissileShooter.
    fileprivate static let shared = WorldMissileShooter()

    // Reference to the root entity where missiles are spawned
    private weak var rootEntity: Entity?

    // Fire rate limiting
    private var lastFireTime: TimeInterval = 0.0
    private let fireRate: Float = 0.5 // seconds between volleys

    // Spawn height above target
    @Published var spawnHeight: Float = 10.0 // 10 meters above target

    // Missile speed (downward)
    private let missileSpeed: Float = 8.0 // 8 m/s downward

    private init() {}

    /// Set the root entity where missiles will be spawned
    public func setRootEntity(_ entity: Entity) {
        self.rootEntity = entity
        gameLog("🎯 [WorldMissileShooter] Root entity set")
    }

    /// Fire missiles at a target position using the player's selected weapon
    /// - Parameters:
    ///   - targetPosition: The world position to fire at (missiles spawn above this)
    ///   - slot: The weapon slot to use (1 or 2, defaults to 1)
    public func fireMissilesAt(targetPosition: SIMD3<Float>, slot: Int = 1) {
        guard let rootEntity = rootEntity else {
            gameLog("❌ [WorldMissileShooter] No root entity set")
            return
        }

        // Check fire rate limit
        let currentTime = CACurrentMediaTime()
        if currentTime - lastFireTime < TimeInterval(fireRate) {
            gameLog("⏱️ [WorldMissileShooter] Fire rate limited")
            return
        }
        lastFireTime = currentTime

        // Get weapon stats from LoadoutManager
        let loadoutManager = GameContext.shared.loadout
        guard let weaponStats = loadoutManager.getCurrentWeaponStats(slot: slot) else {
            gameLog("❌ [WorldMissileShooter] No weapon stats available for slot \(slot)")
            return
        }

        let weaponModelName = loadoutManager.getCurrentWeaponModelName(slot: slot)
        let weaponTrailColor = weaponStats.trailColor

        // Get player color and trail color
        let playerColor = UIColor(swiftUIColor: GameContext.shared.playerProfile.playerColor)
        let missileTrailColor = UIColor(hex: weaponTrailColor) ?? playerColor

        // Calculate spawn position (above target)
        let spawnPosition = SIMD3<Float>(
            targetPosition.x,
            targetPosition.y + spawnHeight,
            targetPosition.z
        )

        // Missile velocity (straight down)
        let missileVelocity = SIMD3<Float>(0, -missileSpeed, 0)

        // Get weapon configuration
        let missileCount = weaponStats.missileCount
        let missileRows = weaponStats.missileRows
        let missilesPerRow = weaponStats.missilesPerRow
        let horizontalSpacing = weaponStats.horizontalSpacing
        let verticalSpacing = weaponStats.verticalSpacing
        let collisionRadius = weaponStats.collisionRadius
        let missileDamage = weaponStats.damage

        gameLog("🚀 [WorldMissileShooter] Firing \(missileCount) missiles at \(targetPosition)")

        // Spawn missiles in grid pattern (horizontal plane)
        var missileIndex = 0
        for row in 0..<missileRows {
            for col in 0..<missilesPerRow {
                guard missileIndex < missileCount else { break }

                // Calculate offsets from center (in horizontal plane X-Z)
                let centerRow = Float(missileRows - 1) / 2.0
                let centerCol = Float(missilesPerRow - 1) / 2.0

                let rowOffset = (Float(row) - centerRow) * verticalSpacing   // Z-axis offset
                let colOffset = (Float(col) - centerCol) * horizontalSpacing // X-axis offset

                // Calculate spawn position for this missile in the grid
                // Grid is in the horizontal plane (X-Z), missiles spawn at same Y height
                let gridOffset = SIMD3<Float>(colOffset, 0, rowOffset)
                let offsetSpawnPosition = spawnPosition + gridOffset

                // Create world missile with weapon-specific model and stats
                let missile = WorldMissileEntity(
                    velocity: missileVelocity,
                    lifetime: 5.0, // 5 seconds lifetime (enough time to reach ground from 10m)
                    playerColor: playerColor,
                    trailColor: missileTrailColor,
                    modelName: weaponModelName,
                    collisionRadius: collisionRadius,
                    damage: missileDamage
                )
                missile.position = offsetSpawnPosition

                // Missiles point straight down - rotation is set in WorldMissileEntity init
                // Don't override the orientation here

                rootEntity.addChild(missile)

                missileIndex += 1
            }
        }

        // Play shoot sound
        GameContext.shared.sound.playShootSound(entity: rootEntity)
    }

    /// Fire missiles using a grid coordinate (normalized 0-1 in X-Z plane)
    /// - Parameters:
    ///   - gridX: X coordinate in grid (0-1, where 0.5 is center)
    ///   - gridY: Y coordinate in grid (0-1, where 0.5 is center) - maps to Z-axis in world
    ///   - worldBounds: The size of the game world (width and depth)
    ///   - slot: The weapon slot to use (1 or 2, defaults to 1)
    public func fireMissilesAtGrid(gridX: Float, gridY: Float, worldBounds: SIMD2<Float> = SIMD2<Float>(20, 20), slot: Int = 1) {
        // Convert grid coordinates (0-1) to world coordinates
        // Center the world at origin (0, 0, 0)
        let worldX = (gridX - 0.5) * worldBounds.x
        let worldZ = (gridY - 0.5) * worldBounds.y

        // Target position at ground level (Y = 0)
        let targetPosition = SIMD3<Float>(worldX, 0, worldZ)

        fireMissilesAt(targetPosition: targetPosition, slot: slot)
    }
}

extension GameContext {
    public var worldMissileShooter: WorldMissileShooter { WorldMissileShooter.shared }
}
