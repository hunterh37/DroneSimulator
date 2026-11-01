//
//  CollisionManager.swift
//  HelicopterGame
//
//  Created by Claude on 10/17/25.
//  Centralized collision event handling for all game entities
//

import RealityKit
import Combine
import Foundation
import QuartzCore
import UIKit
import _RealityKit_SwiftUI

/// Singleton manager that handles all collision events in the game
public class CollisionManager {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `CollisionManager.shared` directly; everyone else must
    // go through GameContext.shared.collision.
    fileprivate static let shared = CollisionManager()
    var collisionSubscription: EventSubscription?
    private var subscriptions = Set<AnyCancellable>()
    public private(set) var scene: RealityKit.Scene?

    private init() {
        gameLog("🎯 [CollisionManager] Initialized")
    }

    /// Initialize collision event subscriptions for a scene
    /// Call this once when setting up your RealityKit scene
    public func setup(scene: RealityKit.Scene) {
        // Clean up any existing subscriptions first
        subscriptions.removeAll()

        self.scene = scene

        // Subscribe to collision events
//        scene.subscribe(to: CollisionEvents.Began.self) { [weak self] event in
//            self?.handleCollisionBegan(event: event, scene: scene)
//        }.store(in: &subscriptions)
//
//        gameLog("🎯 [CollisionManager] ✅ Collision subscription active")
    }

    /// Cleanup subscriptions (call when tearing down the scene)
    public func cleanup() {
        subscriptions.removeAll()
        scene = nil
        gameLog("🎯 [CollisionManager] Cleaned up subscriptions")
    }

    // MARK: - Collision Event Handling

    public func handleCollisionBegan(event: CollisionEvents.Began) {
        let entityA = event.entityA
        let entityB = event.entityB

        // Check if entityA is a missile
        if let missileComponent = entityA.components[MissileComponent.self] {
            handleMissileCollision(missile: entityA, target: entityB, missileComponent: missileComponent)
        }
        // Check if entityB is a missile
        else if let missileComponent = entityB.components[MissileComponent.self] {
            handleMissileCollision(missile: entityB, target: entityA, missileComponent: missileComponent)
        }
    }

    // MARK: - Missile Collision Handling

    func handleMissileCollision(missile: Entity, target: Entity, missileComponent: MissileComponent) {
        gameLog("🎯 COLLISION EVENT! Missile collided with \(target.name) of type: \(type(of: target))")

        // Skip collision with missile owner (the drone that fired this missile)
        if let ownerDroneId = missileComponent.ownerDroneId {
            // For PlayerDroneEntity: Skip collision if owner ID looks like a UUID (from local player)
            if target is PlayerDroneEntity {
                // Check if ownerDroneId is a UUID format (contains hyphens and is long enough)
                if ownerDroneId.contains("-") && ownerDroneId.count >= 32 {
                    gameLog("🚀 Skipping collision with PlayerDroneEntity - missile owner is local player (UUID: \(ownerDroneId))")
                    return
                }
            }

            // For RemoteDroneEntity: Skip if missile owner matches remote player ID
            if let remoteDrone = target as? RemoteDroneEntity,
               ownerDroneId == remoteDrone.playerID {
                gameLog("🚀 Skipping collision with own RemoteDrone: \(remoteDrone.playerID)")
                return
            }

            // Fallback: Check entity name matches owner ID
            if target.name == ownerDroneId {
                gameLog("🚀 Skipping collision with own drone (name match): \(target.name)")
                return
            }
        }

        // Handle the missile hit
        handleMissileHit(missile: missile, target: target)
    }

    func handleMissileHit(missile: Entity, target: Entity?) {
        // Get the missile owner for explosion color
        let missileOwnerID = missile.components[MissileComponent.self]?.ownerDroneId ?? "unknown"

        if let target = target {
            gameLog("🎯 Missile hit target: \(target.name) of type: \(type(of: target))")

            // Create explosion effect at impact point
            let explosionPosition = target.position
            let explosion = ExplosionEntity.createDroneExplosion(at: explosionPosition)

            // Add explosion to the scene (use missile's parent or find root entity)
            if let parent = missile.parent {
                parent.addChild(explosion)
            }
            gameLog("💥 Created explosion effect at \(explosionPosition) for player \(missileOwnerID)")

            // Check if target is a PlayerDroneEntity (local player)
            if let playerDrone = target as? PlayerDroneEntity {
                gameLog("💥 Hit local PlayerDroneEntity!")

                // Get missile damage from component
                let missileDamage = missile.components[MissileComponent.self]?.damage ?? 20

                // Apply damage to both player drone entity AND PlayerHealthManager
                playerDrone.takeDamage()
                gameLog("💔 Local player drone took damage. Health: \(playerDrone.currentHealth)/\(playerDrone.maxHealth)")

                // Also update PlayerHealthManager (which controls the UI health bar)
                GameContext.shared.health.localPlayerHealth.takeDamage(missileDamage)
                gameLog("💔 Applied \(missileDamage) damage to PlayerHealthManager. Remaining health: \(GameContext.shared.health.localPlayerHealth.currentHealth)")

                // Check if player died
                if GameContext.shared.health.localPlayerHealth.currentHealth <= 0 {
                    gameLog("💀 Player died from enemy missile!")
                }
            }
            // Check if target is a RemoteDroneEntity specifically
            else if let remoteDrone = target as? RemoteDroneEntity {
                gameLog("💥 Hit RemoteDroneEntity for player: \(remoteDrone.playerID)")

                // Get missile damage from component
                let missileDamage = missile.components[MissileComponent.self]?.damage ?? 20

                // Only send damage message - DO NOT add killfeed entry here!
                Task {
                    await sendDamageMessage(victimPlayerID: remoteDrone.playerID, victimPosition: target.position, damage: missileDamage)
                }
                gameLog("💥 Sent damage message for remote player: \(remoteDrone.playerID) with damage: \(missileDamage)")
            }
            // If target is a remote player drone, send damage message (fallback method)
            else if let targetPlayerID = extractPlayerIDFromDroneName(target.name) {
                // Get missile damage from component
                let missileDamage = missile.components[MissileComponent.self]?.damage ?? 20

                Task {
                    await sendDamageMessage(victimPlayerID: targetPlayerID, victimPosition: target.position, damage: missileDamage)
                }
                gameLog("💥 Sent damage message for player: \(targetPlayerID) with damage: \(missileDamage)")
            }
            // If target is a boss enemy, damage it (boss has 500 HP)
            else if let boss = target as? EnemyDroneBossEntity {
                gameLog("💥 Player missile hit boss: \(boss.bossID)")

                // Get actual missile damage from component (not hardcoded!)
                let missileDamage = missile.components[MissileComponent.self]?.damage ?? 20
                let bossDamage = Float(missileDamage)
                boss.takeDamage(bossDamage)

                // Immediately update UI health display for instant visual feedback
                GameContext.shared.bossPosition.currentHealth = boss.health
                GameContext.shared.bossPosition.maxHealth = boss.maxHealth

                gameLog("👑 Boss took \(bossDamage) damage. Remaining health: \(boss.health)/\(boss.maxHealth)")

                // Check if boss was destroyed (health <= 0)
                if boss.health <= 0 {
                    // Add killfeed entry for boss kill
                    let healthManager = GameContext.shared.health
                    let networking = MultiplayerNetworking()
                    let killfeedEntry = KillfeedEntry(
                        killerPlayerID: networking.localPlayerID,
                        killedPlayerID: "Boss_\(boss.bossID)",
                        timestamp: CACurrentMediaTime()
                    )
                    healthManager.killfeedEntries.insert(killfeedEntry, at: 0)
                    gameLog("📰 Added killfeed entry: Player killed Boss \(boss.bossID)")

                    // Award 100 XP for killing boss (10x normal enemy)
                    let rankManager = PlayerRankManager()
                    rankManager.localPlayerRank.addXP(100)
                    rankManager.saveRank()
                    gameLog("⭐ Awarded 100 XP for boss kill!")
                }
            }
            // If target is an enemy drone, destroy it using proper damage system
            else if let enemyDrone = target as? EnemyDroneEntity {
                gameLog("💥 Player missile destroyed enemy drone: \(enemyDrone.enemyID)")

                // Add killfeed entry for bot kill
                let healthManager = GameContext.shared.health
                let networking = MultiplayerNetworking()
                let killfeedEntry = KillfeedEntry(
                    killerPlayerID: networking.localPlayerID,
                    killedPlayerID: "Bot_\(enemyDrone.enemyID)",
                    timestamp: CACurrentMediaTime()
                )
                healthManager.killfeedEntries.insert(killfeedEntry, at: 0)
                gameLog("📰 Added killfeed entry: Player killed \(enemyDrone.enemyID)")

                // Award 10 XP for killing AI drone
                let rankManager = PlayerRankManager()
                rankManager.localPlayerRank.addXP(10)
                rankManager.saveRank()
                gameLog("⭐ Awarded 10 XP for AI drone kill")

                // Use the enemy drone's takeDamage method (which includes explosion)
                enemyDrone.takeDamage()
                gameLog("🗑️ Enemy drone \(enemyDrone.enemyID) destroyed via takeDamage()")
            }
            // Check if target name indicates it's an enemy drone (fallback)
            else if target.name.hasPrefix("EnemyDrone_") {
                gameLog("💥 Player missile hit enemy drone: \(target.name)")

                // Add killfeed entry for bot kill (fallback case)
                let healthManager = GameContext.shared.health
                let networking = MultiplayerNetworking()
                let killfeedEntry = KillfeedEntry(
                    killerPlayerID: networking.localPlayerID,
                    killedPlayerID: "Bot_Unknown",
                    timestamp: CACurrentMediaTime()
                )
                healthManager.killfeedEntries.insert(killfeedEntry, at: 0)

                // Try to call takeDamage if it's an EnemyDroneEntity, otherwise remove directly
                if let enemyDrone = target as? EnemyDroneEntity {
                    enemyDrone.takeDamage()
                } else {
                    // Spawn explosion manually for non-EnemyDroneEntity targets
                    let explosion = ExplosionEntity.createDroneExplosion(at: target.position)
                    if let parent = target.parent {
                        parent.addChild(explosion)
                    }
                    target.removeFromParent()
                }
                gameLog("🗑️ Removed enemy drone \(target.name) from scene")
            }
        } else {
            gameLog("💥 Missile hit ground/obstacle")

            // Create ground impact explosion (smaller scale for ground hits)
            let groundExplosion = ExplosionEntity.createSmallExplosion(at: missile.position)
            if let parent = missile.parent {
                parent.addChild(groundExplosion)
            }
            gameLog("💥 Created ground impact explosion at \(missile.position)")
        }

        // Remove missile
        missile.removeFromParent()
    }

    // MARK: - Helper Methods

    func extractPlayerIDFromDroneName(_ name: String) -> String? {
        // Remote drones should have names like "RemoteDrone_PlayerID"
        if name.hasPrefix("RemoteDrone_") {
            return String(name.dropFirst("RemoteDrone_".count))
        }
        return nil
    }

    func sendDamageMessage(victimPlayerID: String, victimPosition: SIMD3<Float>, damage: Int) async {
        // Send damage notification
        NotificationCenter.default.post(
            name: .droneDamageDealt,
            object: nil,
            userInfo: [
                "victimPlayerID": victimPlayerID,
                "damageAmount": damage,
                "victimPosition": victimPosition
            ]
        )
        gameLog("📤 Sent damage message: \(damage) damage to player \(victimPlayerID)")
    }
}

extension GameContext {
    public var collision: CollisionManager { CollisionManager.shared }
}
