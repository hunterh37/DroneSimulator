//
//  PlayerHealthComponent.swift
//  HelicopterGame
//
//  Created by Claude on 10/5/25.
//

import RealityKit
import Foundation
import Combine
import simd
import QuartzCore

// MARK: - Player Health Component

public struct PlayerHealthComponent: Component {
    public var currentHealth: Int
    public var maxHealth: Int
    public var isAlive: Bool
    public var lastDamageTime: TimeInterval
    public var respawnCooldown: TimeInterval

    public init(maxHealth: Int = 100) {
        self.currentHealth = maxHealth
        self.maxHealth = maxHealth
        self.isAlive = true
        self.lastDamageTime = 0.0
        self.respawnCooldown = 3.0 // 3 seconds respawn delay
    }

    public mutating func takeDamage(_ amount: Int) -> Bool {
        guard isAlive else { return false }

        currentHealth = max(0, currentHealth - amount)
        lastDamageTime = CACurrentMediaTime()

        if currentHealth <= 0 {
            isAlive = false
            return true // Player died
        }

        return false // Player still alive
    }

    public mutating func heal(_ amount: Int) {
        guard isAlive else { return }
        currentHealth = min(maxHealth, currentHealth + amount)
    }

    public mutating func respawn() {
        currentHealth = maxHealth
        isAlive = true
        lastDamageTime = 0.0
    }

    public var healthPercentage: Float {
        return Float(currentHealth) / Float(maxHealth)
    }
}

// MARK: - Player Health Manager

@Observable
public class PlayerHealthManager {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `PlayerHealthManager.shared` directly; everyone else
    // must go through GameContext.shared.health.
    fileprivate static let shared = PlayerHealthManager()

    // Local player health
    public var localPlayerHealth: PlayerHealthComponent

    // Remote players health tracking
    public var remotePlayersHealth: [String: PlayerHealthComponent] = [:]

    // Killfeed data
    public var killfeedEntries: [KillfeedEntry] = []
    public let maxKillfeedEntries = 5

    // Persistent kill/death tracking (doesn't expire like killfeed)
    public var playerKillCounts: [String: Int] = [:] // PlayerID -> Kill count
    public var playerDeathCounts: [String: Int] = [:] // PlayerID -> Death count

    // Player rank management
    private var rankManager = PlayerRankManager()

    // Multiplayer networking reference
    private var multiplayerNetworking: MultiplayerNetworking?

    // Multiplayer manager for explosion effects
    private weak var multiplayerManager: MultiplayerManager?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.localPlayerHealth = PlayerHealthComponent()
        setupNotificationObservers()
    }

    public func setMultiplayerNetworking(_ networking: MultiplayerNetworking) {
        self.multiplayerNetworking = networking

        // Subscribe to multiplayer messages
        networking.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleMultiplayerMessage(message)
            }
            .store(in: &cancellables)
    }

    public func setMultiplayerManager(_ manager: MultiplayerManager) {
        self.multiplayerManager = manager
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .droneDamageDealt,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let victimPlayerID = userInfo["victimPlayerID"] as? String,
                  let damageAmount = userInfo["damageAmount"] as? Int,
                  let victimPosition = userInfo["victimPosition"] as? SIMD3<Float> else {
                return
            }

            Task {
                await self?.handleLocalDamageDealt(
                    victimPlayerID: victimPlayerID,
                    damageAmount: damageAmount,
                    victimPosition: victimPosition
                )
            }
        }
    }

    private func handleLocalDamageDealt(victimPlayerID: String, damageAmount: Int, victimPosition: SIMD3<Float>) async {
        // Send damage message to multiplayer
        await multiplayerNetworking?.sendDroneDamage(
            victimPlayerID: victimPlayerID,
            damageAmount: damageAmount,
            victimPosition: victimPosition
        )

        gameLog("💥 Dealt \(damageAmount) damage to player \(victimPlayerID)")
    }

    private func handleMultiplayerMessage(_ message: MultiplayerMessage) {
        switch message {
        case .droneDamage(let damageMessage):
            handleIncomingDamage(damageMessage)
        case .droneKill(let killMessage):
            handleIncomingKill(killMessage)
        case .droneRespawn(let respawnMessage):
            handleIncomingRespawn(respawnMessage)
        default:
            break
        }
    }

    private func handleIncomingDamage(_ damageMessage: DroneDamageMessage) {
        let isLocalPlayer = damageMessage.victimPlayerID == multiplayerNetworking?.localPlayerID

        if isLocalPlayer {
            // Apply damage to local player
            let playerDied = localPlayerHealth.takeDamage(damageMessage.damageAmount)

            gameLog("💔 Local player took \(damageMessage.damageAmount) damage. Health: \(localPlayerHealth.currentHealth)/\(localPlayerHealth.maxHealth)")

            // Post damage notification for visual effects (damage flash)
            NotificationCenter.default.post(
                name: .playerTookDamage,
                object: nil,
                userInfo: ["damageAmount": damageMessage.damageAmount]
            )

            if playerDied {
                gameLog("☠️ Local player died!")

                // 💥 SPAWN EXPLOSION at victim position for local player death
                spawnExplosionForKilledDrone(playerID: multiplayerNetworking?.localPlayerID ?? "", killPosition: damageMessage.victimPosition)

                Task {
                    await handleLocalPlayerDeath(killerPlayerID: damageMessage.attackerPlayerID)
                }
            }
        } else {
            // Update remote player health
            if remotePlayersHealth[damageMessage.victimPlayerID] == nil {
                remotePlayersHealth[damageMessage.victimPlayerID] = PlayerHealthComponent()
            }

            let playerDied = remotePlayersHealth[damageMessage.victimPlayerID]?.takeDamage(damageMessage.damageAmount) ?? false

            if playerDied {
                gameLog("☠️ Remote player \(damageMessage.victimPlayerID) died from damage by \(damageMessage.attackerPlayerID)")

                // 💥 SPAWN EXPLOSION at victim position for remote player death
                spawnExplosionForKilledDrone(playerID: damageMessage.victimPlayerID, killPosition: damageMessage.victimPosition)
            }
        }
    }

    private func handleIncomingKill(_ killMessage: DroneKillMessage) {
        let localPlayerID = multiplayerNetworking?.localPlayerID ?? ""

        // Only add to killfeed if we're NOT the victim (victim already added it locally when they died)
        if killMessage.killedPlayerID != localPlayerID {
            addKillfeedEntry(
                killerPlayerID: killMessage.killerPlayerID,
                killedPlayerID: killMessage.killedPlayerID
            )
        }

        // Handle rank progression for local player
        if killMessage.killerPlayerID == localPlayerID {
            // Local player got a kill
            rankManager.awardKill()

            // Post kill notification with killed player's name
            let killedPlayerName = getPlayerUsername(for: killMessage.killedPlayerID)
            NotificationCenter.default.post(
                name: .playerKilledEnemy,
                object: nil,
                userInfo: ["killedPlayerName": killedPlayerName]
            )
        } else if killMessage.killedPlayerID == localPlayerID {
            // Local player died
            rankManager.recordDeath()
        }

        // 💥 SPAWN EXPLOSION at drone position
        spawnExplosionForKilledDrone(playerID: killMessage.killedPlayerID, killPosition: killMessage.killPosition)

        // Reset health for killed player
        if killMessage.killedPlayerID == localPlayerID {
            localPlayerHealth = PlayerHealthComponent() // Reset but dead
            localPlayerHealth.isAlive = false
        } else {
            remotePlayersHealth[killMessage.killedPlayerID] = PlayerHealthComponent()
            remotePlayersHealth[killMessage.killedPlayerID]?.isAlive = false
        }
    }

    private func handleIncomingRespawn(_ respawnMessage: DroneRespawnMessage) {
        if respawnMessage.playerID == multiplayerNetworking?.localPlayerID {
            localPlayerHealth.respawn()
            gameLog("🔄 Local player respawned")
        } else {
            if remotePlayersHealth[respawnMessage.playerID] == nil {
                remotePlayersHealth[respawnMessage.playerID] = PlayerHealthComponent()
            }
            remotePlayersHealth[respawnMessage.playerID]?.respawn()
            gameLog("🔄 Remote player \(respawnMessage.playerID) respawned")
        }
    }

    public func handleLocalPlayerDeath(killerPlayerID: String) async {
        // Send kill message
        await multiplayerNetworking?.sendDroneKill(
            killedPlayerID: multiplayerNetworking?.localPlayerID ?? "",
            killPosition: SIMD3<Float>(0, 0, 0) // TODO: Get actual position
        )

        // Add to killfeed
        addKillfeedEntry(
            killerPlayerID: killerPlayerID,
            killedPlayerID: multiplayerNetworking?.localPlayerID ?? ""
        )

        // Start respawn timer
        Task {
            try await Task.sleep(nanoseconds: UInt64(localPlayerHealth.respawnCooldown * 1_000_000_000))
            await respawnLocalPlayer()
        }
    }

    private func respawnLocalPlayer() async {
        localPlayerHealth.respawn()

        // Send respawn message
        let respawnPosition = SIMD3<Float>(0, 2, 0) // TODO: Get proper spawn position
        await multiplayerNetworking?.sendDroneRespawn(respawnPosition: respawnPosition)

        gameLog("🔄 Local player respawned!")

        // Post notification for UI updates
        NotificationCenter.default.post(name: .localPlayerRespawned, object: nil)
    }

    private func addKillfeedEntry(killerPlayerID: String, killedPlayerID: String) {
        let entry = KillfeedEntry(
            killerPlayerID: killerPlayerID,
            killedPlayerID: killedPlayerID,
            timestamp: CACurrentMediaTime()
        )

        killfeedEntries.insert(entry, at: 0) // Add to beginning

        // Keep only the most recent entries
        if killfeedEntries.count > maxKillfeedEntries {
            killfeedEntries = Array(killfeedEntries.prefix(maxKillfeedEntries))
        }

        // Update persistent kill/death counts
        playerKillCounts[killerPlayerID, default: 0] += 1
        playerDeathCounts[killedPlayerID, default: 0] += 1

        let killerKills = playerKillCounts[killerPlayerID] ?? 0
        gameLog("📊 [PlayerHealthManager] Kill counts updated - \(killerPlayerID): \(killerKills) kills, \(killedPlayerID): \(playerDeathCounts[killedPlayerID] ?? 0) deaths")

        // Check win condition immediately after every kill
        Task { @MainActor in
            GameContext.shared.battle.checkWinConditionNow()
        }
    }

    public func getPlayerHealth(playerID: String) -> PlayerHealthComponent? {
        if playerID == multiplayerNetworking?.localPlayerID {
            return localPlayerHealth
        }
        return remotePlayersHealth[playerID]
    }

    public func addRemotePlayer(playerID: String) {
        if remotePlayersHealth[playerID] == nil {
            remotePlayersHealth[playerID] = PlayerHealthComponent()
        }
    }

    public func removeRemotePlayer(playerID: String) {
        remotePlayersHealth.removeValue(forKey: playerID)
    }

    // MARK: - Session Cleanup

    /// Resets all health state for a new multiplayer session
    public func resetForNewSession() {
        gameLog("🧹 [PlayerHealthManager] Resetting for new session")

        // Reset local player health to full
        localPlayerHealth = PlayerHealthComponent()

        // Clear all remote player health
        remotePlayersHealth.removeAll()

        // Clear killfeed (already done by battle manager, but ensures cleanup)
        killfeedEntries.removeAll()

        // Clear persistent kill/death counts
        playerKillCounts.removeAll()
        playerDeathCounts.removeAll()

        // Clear Combine subscriptions (will be re-established when networking reconnects)
        cancellables.removeAll()

        gameLog("✅ [PlayerHealthManager] Session reset complete")
    }

    private func getPlayerUsername(for playerID: String) -> String {
        // For now, return the playerID itself as the username
        // In a full implementation, this would look up the username from roomPlayers or another source
        // We can enhance this later to show actual usernames
        return playerID
    }

    // MARK: - Rank Management

    public func awardGameWin() {
        rankManager.awardGameWin()
    }

    public func awardGameLoss() {
        rankManager.awardGameLoss()
    }

    public var localPlayerRank: PlayerRank {
        return rankManager.localPlayerRank
    }

    // MARK: - Explosion Effects

    /// Spawns an explosion effect when a drone is killed
    /// - Parameters:
    ///   - playerID: ID of the player whose drone was killed
    ///   - killPosition: Position where the kill occurred
    private func spawnExplosionForKilledDrone(playerID: String, killPosition: SIMD3<Float>) {
        guard let manager = multiplayerManager else {
            gameLog("⚠️ [PlayerHealthManager] Cannot spawn explosion: Multiplayer manager not set")
            return
        }

        // Use the kill position for the explosion
        manager.spawnExplosionAt(position: killPosition)

        gameLog("💥 [PlayerHealthManager] Spawned explosion for killed drone - Player: \(playerID), Position: \(killPosition)")
    }
}

// MARK: - Killfeed Entry

public struct KillfeedEntry: Identifiable, Equatable {
    public let id = UUID()
    public let killerPlayerID: String
    public let killedPlayerID: String
    public let timestamp: TimeInterval

    public var age: TimeInterval {
        return CACurrentMediaTime() - timestamp
    }

    public var shouldExpire: Bool {
        return age > 5.0 // Expire after 5 seconds
    }

    public static func == (lhs: KillfeedEntry, rhs: KillfeedEntry) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
    static let localPlayerRespawned = Notification.Name("localPlayerRespawned")
    static let playerKillstreak = Notification.Name("playerKillstreak")
    static let playerKilledEnemy = Notification.Name("playerKilledEnemy")
    static let playerTookDamage = Notification.Name("playerTookDamage")
}

extension GameContext {
    public var health: PlayerHealthManager { PlayerHealthManager.shared }
}