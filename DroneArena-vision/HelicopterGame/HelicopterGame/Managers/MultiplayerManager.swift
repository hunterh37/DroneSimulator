//
//  MultiplayerManager.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import Foundation
import RealityKit
import Combine
import simd
import QuartzCore
import UIKit

@MainActor
@Observable
public class MultiplayerManager {
    // Networking
    public var networking = MultiplayerNetworking()
    public var isMultiplayerEnabled = false

    // Remote drone management
    public var remoteDrones: [String: RemoteDroneEntity] = [:]
    public weak var worldAnchor: Entity?

    // Room players tracking
    public var roomPlayers: [RoomPlayer] = []

    // Current room info
    public var currentRoomName: String = ""
    public var currentRoomCode: String? = nil

    // Game state tracking
    public var currentGameState: GameStatusMessage.GameState = .lobby

    // Update timing
    private var lastPositionSent: TimeInterval = 0
    private let positionUpdateInterval: TimeInterval = 1.0 / 3.0 // 3 FPS

    // Movement tracking
    private var lastSentPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    private var lastSentRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    private let movementThreshold: Float = 0.01 // Minimum distance to consider "moved"

    // Cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupNetworkingObservation()
    }

    // Note: Removed deinit to avoid MainActor isolation issues
    // Cleanup is handled through endMultiplayerSession() when explicitly called

    // MARK: - Session Management

    public func startWebSocketSession(host: String = NetworkConfig.backendHost, port: UInt16 = NetworkConfig.defaultPort) async throws {
        isMultiplayerEnabled = true
        try await networking.startSession(mode: .webSocket(host: host, port: port))
    }

    public func joinRoom(_ roomId: String, host: String = NetworkConfig.backendHost, roomName: String = "", roomCode: String? = nil) async throws {
        isMultiplayerEnabled = true
        currentRoomName = roomName
        currentRoomCode = roomCode
        try await networking.connectToRoom(roomId: roomId, host: host)

        // Send join room message with player info including rank and selected drone
        let profileManager = GameContext.shared.playerProfile
        let healthManager = GameContext.shared.health
        let droneType = GameContext.shared.loadout.selectedDrone?.modelName // Get selected drone model name
        gameLog("🚁 [MultiplayerManager] Joining room with:")
        gameLog("   - playerName: \(profileManager.playerName)")
        gameLog("   - droneType: \(droneType ?? "nil (will use default)")")
        gameLog("   - selectedDrone: \(GameContext.shared.loadout.selectedDrone?.displayName ?? "nil")")
        let joinMessage = RoomJoinMessage(
            playerID: networking.localPlayerID,
            playerName: profileManager.playerName,
            playerColor: profileManager.playerColorHex,
            playerRank: healthManager.localPlayerRank,
            droneType: droneType
        )

        guard let session = networking.currentSession else {
            throw NSError(domain: "MultiplayerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active session"])
        }

        do {
            try await session.sendMessage(.roomJoin(joinMessage))
            try await waitForRoomJoinResponse()
        } catch {
            // Do not leave a half-open session behind on a failed join
            await endMultiplayerSession()
            throw error
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    private func waitForRoomJoinResponse() async throws {
        return try await withTimeout(seconds: 10) { [weak self] in
            guard let self = self else { throw NSError(domain: "MultiplayerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Manager deallocated"]) }
            for await message in self.networking.messagePublisher.values {
                switch message {
                case .roomJoinSuccess:
                    return
                case .error(let errorMessage):
                    throw NSError(domain: "RoomJoinError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage.message])
                default:
                    continue
                }
            }
        }
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Room join timed out"])
            }

            guard let result = try await group.next() else {
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result"])
            }

            group.cancelAll()
            return result
        }
    }

    public func startSharePlaySession() async throws {
        isMultiplayerEnabled = true
        try await networking.startSession(mode: .sharePlay)
    }

    public func endMultiplayerSession() async {
        isMultiplayerEnabled = false
        await networking.endSession()
        removeAllRemoteDrones()
        roomPlayers.removeAll()
        currentRoomName = ""
        currentRoomCode = nil
        currentGameState = .lobby
        lastPositionSent = 0
        lastSentPosition = SIMD3<Float>(0, 0, 0)
        lastSentRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        GameContext.shared.battle.resetBattle()
        GameContext.shared.health.resetForNewSession()
    }

    // MARK: - Position Broadcasting

    public func updateLocalDronePosition(_ drone: PlayerDroneEntity) {
        guard isMultiplayerEnabled && networking.isConnected else { return }

        let currentPosition = drone.transform.translation
        let currentRotation = drone.transform.rotation
        let currentTime = CACurrentMediaTime()

        guard currentTime - lastPositionSent >= positionUpdateInterval else { return }

        let positionDelta = distance(currentPosition, lastSentPosition)
        let rotationChanged = abs(currentRotation.real - lastSentRotation.real) > 0.01 ||
                             abs(currentRotation.imag.x - lastSentRotation.imag.x) > 0.01 ||
                             abs(currentRotation.imag.y - lastSentRotation.imag.y) > 0.01 ||
                             abs(currentRotation.imag.z - lastSentRotation.imag.z) > 0.01

        guard positionDelta > movementThreshold || rotationChanged else { return }

        lastPositionSent = currentTime
        lastSentPosition = currentPosition
        lastSentRotation = currentRotation

        Task {
            await networking.sendDronePosition(
                position: currentPosition,
                rotation: currentRotation,
                state: drone.droneState,
                droneType: GameContext.shared.loadout.selectedDrone?.modelName
            )
        }
    }

    public func updateLocalDronePositionAsync(_ drone: PlayerDroneEntity) async {
        guard isMultiplayerEnabled && networking.isConnected else { return }

        let currentPosition = drone.transform.translation
        let currentRotation = drone.transform.rotation
        let currentTime = CACurrentMediaTime()

        guard currentTime - lastPositionSent >= positionUpdateInterval else { return }

        let positionDelta = distance(currentPosition, lastSentPosition)
        let rotationChanged = abs(currentRotation.real - lastSentRotation.real) > 0.01 ||
                             abs(currentRotation.imag.x - lastSentRotation.imag.x) > 0.01 ||
                             abs(currentRotation.imag.y - lastSentRotation.imag.y) > 0.01 ||
                             abs(currentRotation.imag.z - lastSentRotation.imag.z) > 0.01

        guard positionDelta > movementThreshold || rotationChanged else { return }

        lastPositionSent = currentTime
        lastSentPosition = currentPosition
        lastSentRotation = currentRotation

        await networking.sendDronePosition(
            position: currentPosition,
            rotation: currentRotation,
            state: drone.droneState,
            droneType: GameContext.shared.loadout.selectedDrone?.modelName
        )
    }

    // MARK: - Remote Drone Management

    private func setupNetworkingObservation() {
        networking.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleIncomingMessage(message)
            }
            .store(in: &cancellables)
    }

    private func handleIncomingMessage(_ message: MultiplayerMessage) {
        switch message {
        case .dronePosition(let positionMessage):
            handleDronePositionMessage(positionMessage)
        case .roomJoin(let joinMessage):
            handlePlayerJoin(joinMessage)
        case .roomLeave(let leaveMessage):
            handlePlayerLeave(leaveMessage)
        case .roomJoinSuccess(let successMessage):
            roomPlayers = successMessage.players
            isMultiplayerEnabled = true
            gameLog("🎮 [MultiplayerManager] Room join success - existing players:")
            for player in successMessage.players {
                gameLog("   - \(player.name): droneType=\(player.droneType ?? "nil")")
            }
        case .playerJoined(let playerMessage):
            let newPlayer = RoomPlayer(
                id: playerMessage.playerID,
                name: playerMessage.playerName,
                color: playerMessage.playerColor,
                joinedAt: ISO8601DateFormatter().string(from: Date()),
                isReady: false,
                rank: playerMessage.playerRank,
                droneType: playerMessage.droneType
            )
            roomPlayers.removeAll { $0.id == newPlayer.id }
            roomPlayers.append(newPlayer)
            gameLog("👥 [MultiplayerManager] Player joined: \(playerMessage.playerName) with drone: \(playerMessage.droneType ?? "default")")

            // Send current game status to the new player (and everyone)
            Task {
                await sendCurrentGameStatus()
            }
        case .playerLeft(let leftMessage):
            roomPlayers.removeAll { $0.id == leftMessage.playerID }
            removeRemoteDrone(playerID: leftMessage.playerID)
        case .fireDroneMissile(let missileMessage):
            handleDroneMissileMessage(missileMessage)
        case .droneDamage:
            break
        case .droneKill(let killMessage):
            hideRemoteDrone(playerID: killMessage.killedPlayerID)
        case .droneRespawn(let respawnMessage):
            showRemoteDrone(playerID: respawnMessage.playerID)
        case .error(let errorMessage):
            gameLog("❌ [MultiplayerManager] Server error: \(errorMessage.code) - \(errorMessage.message)")
        case .ping, .pong:
            break
        case .playerReady(let readyMessage):
            updatePlayerReadyStatus(playerID: readyMessage.playerID, isReady: readyMessage.isReady)
        case .gameStart:
            currentGameState = .countdown
        case .gameCountdown:
            break
        case .gameStatus:
            // Forward to subscribers (handled in LobbyView)
            break
        }
    }

    private func handleDronePositionMessage(_ message: DronePositionMessage) {
        guard message.playerID != networking.localPlayerID else { return }

        let remoteDrone = getOrCreateRemoteDrone(for: message.playerID, droneType: message.droneType)
        remoteDrone.updateFromNetwork(message)

        // Debug log every 30th message to avoid spam
        if Int.random(in: 0..<30) == 0 {
            gameLog("📍 [MultiplayerManager] Received position update for '\(remoteDrone.playerName)': pos=\(message.position), in scene: \(remoteDrone.parent != nil)")
        }
    }

    private func handlePlayerJoin(_ message: RoomJoinMessage) {}

    private func handlePlayerLeave(_ message: RoomLeaveMessage) {
        removeRemoteDrone(playerID: message.playerID)
    }

    private func handleDroneMissileMessage(_ message: FireDroneMissileMessage) {
        guard message.playerID != networking.localPlayerID else { return }
        guard let remoteDrone = remoteDrones[message.playerID] else { return }
        guard let worldAnchor = worldAnchor else { return }

        // Get weapon stats from weaponType if available
        let weaponStats: WeaponStats?
        let weaponModelName: String?
        if let weaponType = message.weaponType {
            weaponStats = GameContext.shared.loadout.getWeaponStats(weaponId: weaponType)
            weaponModelName = GameContext.shared.loadout.getWeaponModelName(weaponId: weaponType)
        } else {
            weaponStats = nil
            weaponModelName = nil
        }

        // Extract missile color from remote drone
        let missileColor = UIColor(hex: remoteDrone.playerColor) ?? UIColor.green

        // Get missile parameters from weapon stats or use defaults
        let missileCount = weaponStats?.missileCount ?? 1
        let missileRows = weaponStats?.missileRows ?? 1
        let missilesPerRow = weaponStats?.missilesPerRow ?? 1
        let horizontalSpacing = weaponStats?.horizontalSpacing ?? 0.15
        let verticalSpacing = weaponStats?.verticalSpacing ?? 0.12
        let collisionRadius = weaponStats?.collisionRadius ?? 0.2
        let missileDamage = weaponStats?.damage ?? 20
        let missileSpeed = weaponStats?.speed ?? length(message.velocity)
        let trailColorHex = weaponStats?.trailColor
        let missileTrailColor = trailColorHex != nil ? UIColor(hex: trailColorHex!) : missileColor

        // Calculate forward direction from the velocity
        let forwardDirection = normalize(message.velocity)

        // Calculate right and up directions for grid positioning
        let up = SIMD3<Float>(0, 1, 0)
        let rightDirection = normalize(cross(forwardDirection, up))
        let upDirection = normalize(cross(rightDirection, forwardDirection))

        // Calculate drone orientation from forward direction
        let droneOrientation = simd_quatf(from: SIMD3<Float>(0, 0, -1), to: forwardDirection)

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
                let offsetSpawnPosition = message.startPosition + gridOffset

                // Optional: Add slight angle spread for barrage effect
                let spreadAngle: Float
                if missileCount > 4 {
                    let anglePerMissile: Float = 0.02 // ~1 degree spread
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
                let missile = MissileEntity(
                    velocity: spreadMissileVelocity,
                    lifetime: 3.0,
                    ownerDroneId: message.playerID,
                    playerColor: missileColor,
                    trailColor: missileTrailColor,
                    modelName: weaponModelName,
                    collisionRadius: collisionRadius,
                    damage: missileDamage
                )
                missile.position = offsetSpawnPosition

                // Use drone orientation
                missile.orientation = droneOrientation

                worldAnchor.addChild(missile)

                missileIndex += 1
            }
        }
    }

    private func getOrCreateRemoteDrone(for playerID: String, droneType: String? = nil) -> RemoteDroneEntity {
        if let existingDrone = remoteDrones[playerID] {
            return existingDrone
        }

        let player = roomPlayers.first { $0.id == playerID }
        let playerName = player?.name ?? "Player \(String(playerID.prefix(8)))"
        let playerColor = player?.color ?? "#FFFFFF"

        // Prioritize droneType from message parameter, fall back to player data, then default to "Drone"
        let droneModelName = droneType ?? player?.droneType ?? "Drone"

        gameLog("🚁 [MultiplayerManager] Creating remote drone for '\(playerName)' with model: \(droneModelName)")
        gameLog("   Sources - message.droneType: \(droneType ?? "nil"), player.droneType: \(player?.droneType ?? "nil")")

        let newDrone = RemoteDroneEntity(playerID: playerID, playerName: playerName, playerColor: playerColor, droneModelName: droneModelName)
        newDrone.addNameTag()

        if let worldAnchor = worldAnchor {
            worldAnchor.addChild(newDrone)
            gameLog("✅ [MultiplayerManager] Added remote drone '\(playerName)' to world anchor at position: \(newDrone.position)")
        } else {
            gameLog("⚠️ [MultiplayerManager] World anchor not ready yet - remote drone '\(playerName)' created but not added to scene")
        }

        remoteDrones[playerID] = newDrone
        return newDrone
    }

    private func removeRemoteDrone(playerID: String) {
        if let drone = remoteDrones[playerID] {
            drone.removeFromParent()
            remoteDrones.removeValue(forKey: playerID)
        }
    }

    private func removeAllRemoteDrones() {
        for (playerID, _) in remoteDrones {
            removeRemoteDrone(playerID: playerID)
        }
    }

    private func hideRemoteDrone(playerID: String) {
        if let drone = remoteDrones[playerID] {
            drone.isEnabled = false
        }
    }

    private func showRemoteDrone(playerID: String) {
        if let drone = remoteDrones[playerID] {
            drone.isEnabled = true
        }
    }

    public func setupWorldAnchor(_ anchor: Entity) {
        self.worldAnchor = anchor
        gameLog("🌍 [MultiplayerManager] World anchor set up")

        // Add any orphaned remote drones that were created before the anchor was ready
        addOrphanedDronesToScene()
    }

    private func addOrphanedDronesToScene() {
        guard let worldAnchor = worldAnchor else { return }

        var orphanedCount = 0
        for (playerID, drone) in remoteDrones {
            // Check if drone is not in the scene yet (parent is nil)
            if drone.parent == nil {
                worldAnchor.addChild(drone)
                orphanedCount += 1
                gameLog("✅ [MultiplayerManager] Retroactively added orphaned remote drone '\(drone.playerName)' to scene")
            }
        }

        if orphanedCount > 0 {
            gameLog("🔄 [MultiplayerManager] Added \(orphanedCount) orphaned remote drone(s) to scene")
        }
    }

    public func update(deltaTime: Float) {}

    // MARK: - Quick Connect Utilities

    public func quickConnectToRoom(roomID: String? = nil) async throws {
        try await startWebSocketSession(host: NetworkConfig.backendHost, port: NetworkConfig.defaultPort)
    }

    public var connectionStatus: String {
        if !isMultiplayerEnabled {
            return "Offline"
        } else if networking.isConnected {
            return "Connected (\(networking.connectedPlayers.count) players)"
        } else {
            return "Connecting..."
        }
    }

    public var connectedPlayerCount: Int {
        return networking.connectedPlayers.count
    }

    public var isConnected: Bool {
        // If we have players in the room, we must be connected (regardless of WebSocket state)
        return networking.isConnected || (!roomPlayers.isEmpty && isMultiplayerEnabled)
    }

    // MARK: - Lobby Management

    private func updatePlayerReadyStatus(playerID: String, isReady: Bool) {
        if let index = roomPlayers.firstIndex(where: { $0.id == playerID }) {
            let player = roomPlayers[index]
            roomPlayers[index] = RoomPlayer(
                id: player.id,
                name: player.name,
                color: player.color,
                joinedAt: player.joinedAt,
                isReady: isReady,
                rank: player.rank,
                droneType: player.droneType
            )
        }
    }

    // MARK: - Explosion Effects

    public func spawnDroneExplosion(for playerID: String) {
        guard let worldAnchor = worldAnchor else { return }

        let explosionPosition: SIMD3<Float>

        if playerID == networking.localPlayerID {
            explosionPosition = SIMD3<Float>(0, 0, 0)
        } else if let remoteDrone = remoteDrones[playerID] {
            explosionPosition = remoteDrone.position
        } else {
            return
        }

        let explosion = ExplosionEntity.createDroneExplosion(at: explosionPosition)
        worldAnchor.addChild(explosion)
    }

    public func spawnExplosionAt(position: SIMD3<Float>) {
        guard let worldAnchor = worldAnchor else { return }

        let explosion = ExplosionEntity.createDroneExplosion(at: position)
        worldAnchor.addChild(explosion)

        GameContext.shared.sound.playExplosionSound(entity: explosion)
    }

    // MARK: - Game State Management

    public func sendCurrentGameStatus() async {
        await networking.sendGameStatus(
            gameState: currentGameState,
            players: roomPlayers
        )
    }

    public func updateGameState(_ newState: GameStatusMessage.GameState) async {
        currentGameState = newState
        await sendCurrentGameStatus()
    }
}

// MARK: - Integration Extensions

extension FlightController {
    public func sendMultiplayerUpdate(_ drone: PlayerDroneEntity, multiplayerManager: MultiplayerManager) async {
        await multiplayerManager.updateLocalDronePosition(drone)
    }
}