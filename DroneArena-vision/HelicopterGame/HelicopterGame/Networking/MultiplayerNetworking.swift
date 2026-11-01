//
//  MultiplayerNetworking.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import Foundation
import Network
import Combine
import simd
import QuartzCore

// MARK: - Networking Mode
public enum MultiplayerMode {
    case sharePlay
    case webSocket(host: String, port: UInt16)
}

// MARK: - Codable Message Types
public struct DronePositionMessage: Codable {
    public let playerID: String
    public let position: SIMD3<Float>
    public let rotation: simd_quatf
    public let timestamp: TimeInterval
    public let droneState: DroneState
    public let droneType: String? // Selected drone model ID

    public init(playerID: String, position: SIMD3<Float>, rotation: simd_quatf, droneState: DroneState, droneType: String? = nil) {
        self.playerID = playerID
        self.position = position
        self.rotation = rotation
        self.timestamp = CACurrentMediaTime()
        self.droneState = droneState
        self.droneType = droneType
    }
}

public struct RoomJoinMessage: Codable {
    public let playerID: String
    public let playerName: String
    public let playerColor: String
    public let playerRank: PlayerRank?
    public let droneType: String? // Selected drone model ID (e.g., "standard", "stealth", "heavy")
    public let timestamp: TimeInterval

    public init(playerID: String, playerName: String, playerColor: String, playerRank: PlayerRank? = nil, droneType: String? = nil) {
        self.playerID = playerID
        self.playerName = playerName
        self.playerColor = playerColor
        self.playerRank = playerRank
        self.droneType = droneType
        self.timestamp = Date().timeIntervalSince1970
    }
}

public struct FireDroneMissileMessage: Codable {
    public let playerID: String
    public let missileID: String
    public let startPosition: SIMD3<Float>
    public let velocity: SIMD3<Float>
    public let timestamp: TimeInterval
    public let weaponType: String? // Optional: "standard", "rapid", "big", "damage"

    public init(playerID: String, startPosition: SIMD3<Float>, velocity: SIMD3<Float>, weaponType: String? = nil) {
        self.playerID = playerID
        self.missileID = UUID().uuidString
        self.startPosition = startPosition
        self.velocity = velocity
        self.timestamp = CACurrentMediaTime()
        self.weaponType = weaponType
    }
}

public struct RoomLeaveMessage: Codable {
    public let playerID: String
    public let timestamp: TimeInterval

    public init(playerID: String) {
        self.playerID = playerID
        self.timestamp = Date().timeIntervalSince1970
    }
}

public struct DroneDamageMessage: Codable {
    public let attackerPlayerID: String
    public let victimPlayerID: String
    public let damageAmount: Int
    public let victimPosition: SIMD3<Float>
    public let timestamp: TimeInterval

    public init(attackerPlayerID: String, victimPlayerID: String, damageAmount: Int, victimPosition: SIMD3<Float>) {
        self.attackerPlayerID = attackerPlayerID
        self.victimPlayerID = victimPlayerID
        self.damageAmount = damageAmount
        self.victimPosition = victimPosition
        self.timestamp = CACurrentMediaTime()
    }
}

public struct DroneKillMessage: Codable {
    public let killerPlayerID: String
    public let killedPlayerID: String
    public let killPosition: SIMD3<Float>
    public let timestamp: TimeInterval

    public init(killerPlayerID: String, killedPlayerID: String, killPosition: SIMD3<Float>) {
        self.killerPlayerID = killerPlayerID
        self.killedPlayerID = killedPlayerID
        self.killPosition = killPosition
        self.timestamp = CACurrentMediaTime()
    }
}

public struct DroneRespawnMessage: Codable {
    public let playerID: String
    public let respawnPosition: SIMD3<Float>
    public let timestamp: TimeInterval

    public init(playerID: String, respawnPosition: SIMD3<Float>) {
        self.playerID = playerID
        self.respawnPosition = respawnPosition
        self.timestamp = CACurrentMediaTime()
    }
}

// Response message types from server
public struct RoomJoinSuccessMessage: Codable {
    public let playerID: String
    public let roomStatus: String
    public let playerCount: Int
    public let players: [RoomPlayer]
    public let timestamp: TimeInterval
}

public struct RoomPlayer: Codable {
    public let id: String
    public let name: String
    public let color: String
    public let joinedAt: String
    public var isReady: Bool = false
    public let rank: PlayerRank?
    public let droneType: String? // Selected drone model ID

    public init(id: String, name: String, color: String, joinedAt: String, isReady: Bool = false, rank: PlayerRank? = nil, droneType: String? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.joinedAt = joinedAt
        self.isReady = isReady
        self.rank = rank
        self.droneType = droneType
    }
}

public struct PlayerJoinedMessage: Codable {
    public let playerID: String
    public let playerName: String
    public let playerColor: String
    public let playerCount: Int
    public let roomStatus: String
    public let timestamp: TimeInterval
    public let playerRank: PlayerRank?
    public let droneType: String? // Selected drone model ID
}

public struct PlayerLeftMessage: Codable {
    public let playerID: String
    public let playerCount: Int
    public let roomStatus: String
    public let timestamp: TimeInterval
}

public struct ErrorMessage: Codable {
    public let code: String
    public let message: String
    public let timestamp: TimeInterval
}

// MARK: - Ping/Pong Messages

public struct PingMessage: Codable {
    public let playerID: String
    public let timestamp: TimeInterval

    public init(playerID: String) {
        self.playerID = playerID
        self.timestamp = CACurrentMediaTime()
    }
}

public struct PongMessage: Codable {
    public let playerID: String
    public let clientTimestamp: TimeInterval
    public let serverTimestamp: TimeInterval
    public let roundTripTime: TimeInterval
    public let latencyMs: Double
    public let averageLatency: Double
    public let pingCount: Int

    public init(playerID: String, clientTimestamp: TimeInterval, serverTimestamp: TimeInterval, roundTripTime: TimeInterval, latencyMs: Double, averageLatency: Double, pingCount: Int) {
        self.playerID = playerID
        self.clientTimestamp = clientTimestamp
        self.serverTimestamp = serverTimestamp
        self.roundTripTime = roundTripTime
        self.latencyMs = latencyMs
        self.averageLatency = averageLatency
        self.pingCount = pingCount
    }
}

// MARK: - Lobby Messages

public struct PlayerReadyMessage: Codable {
    public let playerID: String
    public let isReady: Bool
    public let timestamp: TimeInterval

    public init(playerID: String, isReady: Bool) {
        self.playerID = playerID
        self.isReady = isReady
        self.timestamp = Date().timeIntervalSince1970
    }
}

public struct GameStartMessage: Codable {
    public let initiatorPlayerID: String
    public let countdown: Int
    public let timestamp: TimeInterval

    public init(initiatorPlayerID: String, countdown: Int = 3) {
        self.initiatorPlayerID = initiatorPlayerID
        self.countdown = countdown
        self.timestamp = Date().timeIntervalSince1970
    }
}

public struct GameCountdownMessage: Codable {
    public let countdown: Int
    public let timestamp: TimeInterval

    public init(countdown: Int) {
        self.countdown = countdown
        self.timestamp = Date().timeIntervalSince1970
    }
}

public struct GameStatusMessage: Codable {
    public enum GameState: String, Codable {
        case lobby      // Game is in lobby, waiting for players
        case countdown  // Countdown has started
        case active     // Game is currently active
        case ended      // Game has ended
    }

    public let senderPlayerID: String
    public let gameState: GameState
    public let players: [RoomPlayer]
    public let countdownValue: Int? // Current countdown value if in countdown state
    public let timestamp: TimeInterval

    public init(senderPlayerID: String, gameState: GameState, players: [RoomPlayer], countdownValue: Int? = nil) {
        self.senderPlayerID = senderPlayerID
        self.gameState = gameState
        self.players = players
        self.countdownValue = countdownValue
        self.timestamp = Date().timeIntervalSince1970
    }
}

public enum MultiplayerMessage: Codable {
    case dronePosition(DronePositionMessage)
    case roomJoin(RoomJoinMessage)
    case roomLeave(RoomLeaveMessage)
    case fireDroneMissile(FireDroneMissileMessage)
    case droneDamage(DroneDamageMessage)
    case droneKill(DroneKillMessage)
    case droneRespawn(DroneRespawnMessage)
    // Connection monitoring messages
    case ping(PingMessage)
    case pong(PongMessage)
    // Server response messages
    case roomJoinSuccess(RoomJoinSuccessMessage)
    case playerJoined(PlayerJoinedMessage)
    case playerLeft(PlayerLeftMessage)
    case error(ErrorMessage)
    // Lobby messages
    case playerReady(PlayerReadyMessage)
    case gameStart(GameStartMessage)
    case gameCountdown(GameCountdownMessage)
    case gameStatus(GameStatusMessage)

    enum CodingKeys: String, CodingKey {
        case type, data
    }

    enum MessageType: String, Codable {
        case dronePosition, roomJoin, roomLeave, fireDroneMissile
        case droneDamage, droneKill, droneRespawn
        case ping, pong
        case roomJoinSuccess, playerJoined, playerLeft, error
        case playerReady, gameStart, gameCountdown, gameStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .dronePosition:
            let data = try container.decode(DronePositionMessage.self, forKey: .data)
            self = .dronePosition(data)
        case .roomJoin:
            let data = try container.decode(RoomJoinMessage.self, forKey: .data)
            self = .roomJoin(data)
        case .roomLeave:
            let data = try container.decode(RoomLeaveMessage.self, forKey: .data)
            self = .roomLeave(data)
        case .fireDroneMissile:
            let data = try container.decode(FireDroneMissileMessage.self, forKey: .data)
            self = .fireDroneMissile(data)
        case .droneDamage:
            let data = try container.decode(DroneDamageMessage.self, forKey: .data)
            self = .droneDamage(data)
        case .droneKill:
            let data = try container.decode(DroneKillMessage.self, forKey: .data)
            self = .droneKill(data)
        case .droneRespawn:
            let data = try container.decode(DroneRespawnMessage.self, forKey: .data)
            self = .droneRespawn(data)
        case .ping:
            let data = try container.decode(PingMessage.self, forKey: .data)
            self = .ping(data)
        case .pong:
            let data = try container.decode(PongMessage.self, forKey: .data)
            self = .pong(data)
        case .roomJoinSuccess:
            let data = try container.decode(RoomJoinSuccessMessage.self, forKey: .data)
            self = .roomJoinSuccess(data)
        case .playerJoined:
            let data = try container.decode(PlayerJoinedMessage.self, forKey: .data)
            self = .playerJoined(data)
        case .playerLeft:
            let data = try container.decode(PlayerLeftMessage.self, forKey: .data)
            self = .playerLeft(data)
        case .error:
            let data = try container.decode(ErrorMessage.self, forKey: .data)
            self = .error(data)
        case .playerReady:
            let data = try container.decode(PlayerReadyMessage.self, forKey: .data)
            self = .playerReady(data)
        case .gameStart:
            let data = try container.decode(GameStartMessage.self, forKey: .data)
            self = .gameStart(data)
        case .gameCountdown:
            let data = try container.decode(GameCountdownMessage.self, forKey: .data)
            self = .gameCountdown(data)
        case .gameStatus:
            let data = try container.decode(GameStatusMessage.self, forKey: .data)
            self = .gameStatus(data)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .dronePosition(let data):
            try container.encode(MessageType.dronePosition, forKey: .type)
            try container.encode(data, forKey: .data)
        case .roomJoin(let data):
            try container.encode(MessageType.roomJoin, forKey: .type)
            try container.encode(data, forKey: .data)
        case .roomLeave(let data):
            try container.encode(MessageType.roomLeave, forKey: .type)
            try container.encode(data, forKey: .data)
        case .fireDroneMissile(let data):
            try container.encode(MessageType.fireDroneMissile, forKey: .type)
            try container.encode(data, forKey: .data)
        case .droneDamage(let data):
            try container.encode(MessageType.droneDamage, forKey: .type)
            try container.encode(data, forKey: .data)
        case .droneKill(let data):
            try container.encode(MessageType.droneKill, forKey: .type)
            try container.encode(data, forKey: .data)
        case .droneRespawn(let data):
            try container.encode(MessageType.droneRespawn, forKey: .type)
            try container.encode(data, forKey: .data)
        case .ping(let data):
            try container.encode(MessageType.ping, forKey: .type)
            try container.encode(data, forKey: .data)
        case .pong(let data):
            try container.encode(MessageType.pong, forKey: .type)
            try container.encode(data, forKey: .data)
        case .roomJoinSuccess(let data):
            try container.encode(MessageType.roomJoinSuccess, forKey: .type)
            try container.encode(data, forKey: .data)
        case .playerJoined(let data):
            try container.encode(MessageType.playerJoined, forKey: .type)
            try container.encode(data, forKey: .data)
        case .playerLeft(let data):
            try container.encode(MessageType.playerLeft, forKey: .type)
            try container.encode(data, forKey: .data)
        case .error(let data):
            try container.encode(MessageType.error, forKey: .type)
            try container.encode(data, forKey: .data)
        case .playerReady(let data):
            try container.encode(MessageType.playerReady, forKey: .type)
            try container.encode(data, forKey: .data)
        case .gameStart(let data):
            try container.encode(MessageType.gameStart, forKey: .type)
            try container.encode(data, forKey: .data)
        case .gameCountdown(let data):
            try container.encode(MessageType.gameCountdown, forKey: .type)
            try container.encode(data, forKey: .data)
        case .gameStatus(let data):
            try container.encode(MessageType.gameStatus, forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}

// MARK: - Multiplayer Session Protocol
public protocol MultiplayerSession: ObservableObject {
    var isConnected: Bool { get }
    var connectedPlayers: [String] { get }

    func connect() async throws
    func disconnect()
    func sendMessage(_ message: MultiplayerMessage) async throws

    var messagePublisher: AnyPublisher<MultiplayerMessage, Never> { get }
}

// MARK: - WebSocket Implementation
@MainActor
public class WebSocketMultiplayerSession: MultiplayerSession {
    // Reused across all messages: allocating a fresh coder per packet (and
    // pretty-printing socket traffic) was wasteful given position updates fire
    // many times per second. Compact output, single instance.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    @Published public var isConnected: Bool = false
    @Published public var connectedPlayers: [String] = []

    private let host: String
    private let port: UInt16
    private var webSocketTask: URLSessionWebSocketTask?
    private let messageSubject = PassthroughSubject<MultiplayerMessage, Never>()

    // Player identity
    private var localPlayerID: String

    // Connection monitoring
    private var pingTimer: Timer?
    private var lastPongReceived: Date = Date()
    private let pingInterval: TimeInterval = 30.0 // Send ping every 30 seconds
    private let pongTimeout: TimeInterval = 10.0 // Expect pong within 10 seconds
    private var roomId: String?
    private var isReconnecting: Bool = false
    private var isDisconnectRequested: Bool = false
    private var listeningTask: Task<Void, Never>?

    public var messagePublisher: AnyPublisher<MultiplayerMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    public init(host: String, port: UInt16, localPlayerID: String) {
        self.host = host
        self.port = port
        self.localPlayerID = localPlayerID
    }

    public func connect() async throws {
        guard let url = URL(string: "wss://\(host)") else {
            throw NetworkError.invalidURL
        }
        isDisconnectRequested = false

        let urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession.webSocketTask(with: url)

        gameLog("🔄 [MultiplayerNetworking] Starting WebSocket connection...")
        webSocketTask?.resume()

        // Give the connection a moment to establish
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Check if we're still connected (no errors occurred)
        if let task = webSocketTask, task.state == .running {
            isConnected = true
            lastPongReceived = Date()
            gameLog("✅ [MultiplayerNetworking] Successfully connected to host")

            // Start connection monitoring
            startConnectionMonitoring()

            // Start listening for messages after connection is confirmed
            listeningTask = Task {
                await startListening()
            }
        } else {
            let errorMsg = "WebSocket connection failed or was cancelled"
            gameLog("❌ [MultiplayerNetworking] \(errorMsg)")
            throw NetworkError.connectionFailed(NSError(domain: "WebSocketError", code: -1011, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
        }
    }

    public func connectToRoom(roomId: String, host: String) async throws {
        gameLog("🌐 [MultiplayerNetworking] Connecting to room \(roomId) at \(host)")

        // Store room info for reconnection
        self.roomId = roomId
        isDisconnectRequested = false

        let urlString = "wss://\(host)/ws/rooms/\(roomId)"
        gameLog("🔗 [MultiplayerNetworking] Constructing URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            gameLog("❌ [MultiplayerNetworking] Invalid room URL: \(urlString)")
            throw NetworkError.invalidURL
        }

        gameLog("✅ [MultiplayerNetworking] Valid WebSocket URL created: \(url)")
        gameLog("📋 [MultiplayerNetworking] URL scheme: \(url.scheme ?? "nil")")
        gameLog("📋 [MultiplayerNetworking] URL host: \(url.host ?? "nil")")
        gameLog("📋 [MultiplayerNetworking] URL path: \(url.path)")
        gameLog("📋 [MultiplayerNetworking] URL absoluteString: \(url.absoluteString)")

        let urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession.webSocketTask(with: url)

        gameLog("🔄 [MultiplayerNetworking] Starting WebSocket connection...")
        webSocketTask?.resume()

        // Give the connection a moment to establish
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Check if we're still connected (no errors occurred)
        if let task = webSocketTask, task.state == .running {
            isConnected = true
            lastPongReceived = Date()
            gameLog("✅ [MultiplayerNetworking] Successfully connected to room \(roomId)")

            // Start connection monitoring
            startConnectionMonitoring()

            // Start listening for messages after connection is confirmed
            listeningTask = Task {
                await startListening()
            }
        } else {
            let errorMsg = "WebSocket connection failed or was cancelled"
            gameLog("❌ [MultiplayerNetworking] \(errorMsg)")
            throw NetworkError.connectionFailed(NSError(domain: "WebSocketError", code: -1011, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
        }
    }

    private func waitForConnection() async throws {
        guard let webSocketTask = webSocketTask else {
            throw NetworkError.notConnected
        }

        gameLog("🏓 [MultiplayerNetworking] Sending ping to verify connection...")

        // Send a ping to verify the connection is working
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            webSocketTask.sendPing { error in
                if let error = error {
                    gameLog("❌ [MultiplayerNetworking] Ping failed: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    gameLog("✅ [MultiplayerNetworking] Ping successful - connection verified")
                    continuation.resume()
                }
            }
        }

        // Add a small delay to ensure the connection is fully established
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }

    public func disconnect() {
        gameLog("🔌 [WebSocketSession] Starting disconnect process...")
        isDisconnectRequested = true

        // Cancel listening task first
        listeningTask?.cancel()
        listeningTask = nil

        // Stop monitoring
        stopConnectionMonitoring()

        // Mark as disconnected to stop the listening loop
        isConnected = false

        // Cancel WebSocket task
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        // Clear state
        connectedPlayers.removeAll()
        roomId = nil
        isReconnecting = false

        gameLog("✅ [WebSocketSession] Disconnect complete")
    }

    public func sendMessage(_ message: MultiplayerMessage) async throws {
        guard let webSocketTask = webSocketTask else {
            gameLog("❌ [WebSocketSession] Cannot send message - not connected")
            throw NetworkError.notConnected
        }

        let data = try Self.encoder.encode(message)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        gameLogVerbose("📤 [WebSocketSession] Sending message")

        try await webSocketTask.send(.string(jsonString))
        gameLogVerbose("✅ [WebSocketSession] Message sent successfully")
    }

    private func startListening() async {
        guard let webSocketTask = webSocketTask else {
            gameLog("❌ [WebSocketSession] No webSocketTask to listen on")
            return
        }

        gameLog("👂 [WebSocketSession] Starting to listen for messages (isConnected: \(isConnected))")

        do {
            while isConnected {
                gameLogVerbose("📡 [WebSocketSession] Waiting for next message...")
                let message = try await webSocketTask.receive()
                gameLogVerbose("📨 [WebSocketSession] Message received!")
                await handleReceivedMessage(message)
            }
            gameLog("👂 [WebSocketSession] Stopped listening (isConnected: \(isConnected))")
        } catch {
            gameLog("❌ [WebSocketSession] Listening error: \(error)")
            await MainActor.run {
                if isConnected && !isReconnecting {
                    gameLog("🔄 [WebSocketSession] Connection lost, attempting to reconnect...")
                    attemptReconnection()
                }
                isConnected = false
            }
        }
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            gameLogVerbose("📥 [WebSocketSession] Received raw message:")
            gameLogVerbose("📄 Raw JSON: \(text)")

            guard let data = text.data(using: .utf8) else {
                gameLog("❌ [WebSocketSession] Failed to convert message to UTF-8 data")
                return
            }

            do {
                // First, try to decode as a generic JSON to see the structure.
                // This is purely diagnostic, so only do the extra parsing work
                // when verbose socket logging is actually enabled.
                #if DEBUG
                if gameLogVerboseEnabled,
                   let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    gameLogVerbose("📋 [WebSocketSession] Parsed JSON structure:")
                    for (key, value) in jsonObject {
                        gameLogVerbose("   \(key): \(value)")
                    }
                }
                #endif

                let multiplayerMessage = try Self.decoder.decode(MultiplayerMessage.self, from: data)
                gameLogVerbose("✅ [WebSocketSession] Successfully decoded message: \(multiplayerMessage)")

                await MainActor.run {
                    // Update connected players list and handle responses
                    switch multiplayerMessage {
                    case .roomJoin(let joinMessage):
                        gameLog("👥 [WebSocketSession] Player joined: \(joinMessage.playerName) (\(joinMessage.playerID))")
                        if !connectedPlayers.contains(joinMessage.playerID) {
                            connectedPlayers.append(joinMessage.playerID)
                        }
                    case .roomLeave(let leaveMessage):
                        gameLog("👋 [WebSocketSession] Player left: \(leaveMessage.playerID)")
                        connectedPlayers.removeAll { $0 == leaveMessage.playerID }
                    case .roomJoinSuccess(let successMessage):
                        gameLog("🎉 [WebSocketSession] Room join SUCCESS!")
                        gameLog("   Player ID: \(successMessage.playerID)")
                        gameLog("   Room Status: \(successMessage.roomStatus)")
                        gameLog("   Player Count: \(successMessage.playerCount)")
                        gameLog("   Players in room:")
                        for player in successMessage.players {
                            gameLog("     - \(player.name) (\(player.id)) joined at \(player.joinedAt)")
                        }
                        // Update connected players with all players in room
                        connectedPlayers = successMessage.players.map { $0.id }
                    case .playerJoined(let playerMessage):
                        gameLog("👥 [WebSocketSession] New player joined room: \(playerMessage.playerName)")
                        gameLog("   Player Color: \(playerMessage.playerColor)")
                        gameLog("   Player Count: \(playerMessage.playerCount)")
                        gameLog("   Room Status: \(playerMessage.roomStatus)")
                        if !connectedPlayers.contains(playerMessage.playerID) {
                            connectedPlayers.append(playerMessage.playerID)
                        }
                    case .playerLeft(let leftMessage):
                        gameLog("👋 [WebSocketSession] Player left room: \(leftMessage.playerID)")
                        gameLog("   Player Count: \(leftMessage.playerCount)")
                        gameLog("   Room Status: \(leftMessage.roomStatus)")
                        connectedPlayers.removeAll { $0 == leftMessage.playerID }
                    case .error(let errorMessage):
                        gameLog("❌ [WebSocketSession] Server error received:")
                        gameLog("   Code: \(errorMessage.code)")
                        gameLog("   Message: \(errorMessage.message)")
                        gameLog("   Timestamp: \(errorMessage.timestamp)")
                    case .dronePosition:
                        // Don't log drone position messages as they're frequent
                        break
                    case .fireDroneMissile(let missileMessage):
                        gameLog("🚀 [WebSocketSession] Drone missile fired:")
                        gameLog("   Player ID: \(missileMessage.playerID)")
                        gameLog("   Position: \(missileMessage.startPosition)")
                        gameLog("   Velocity: \(missileMessage.velocity)")
                    case .droneDamage(let damageMessage):
                        gameLog("💥 [WebSocketSession] Drone damage:")
                        gameLog("   Attacker: \(damageMessage.attackerPlayerID)")
                        gameLog("   Victim: \(damageMessage.victimPlayerID)")
                        gameLog("   Damage: \(damageMessage.damageAmount)")
                    case .droneKill(let killMessage):
                        gameLog("☠️ [WebSocketSession] Drone kill:")
                        gameLog("   Killer: \(killMessage.killerPlayerID)")
                        gameLog("   Killed: \(killMessage.killedPlayerID)")
                    case .droneRespawn(let respawnMessage):
                        gameLog("🔄 [WebSocketSession] Drone respawn:")
                        gameLog("   Player: \(respawnMessage.playerID)")
                        gameLog("   Position: \(respawnMessage.respawnPosition)")
                    case .ping(let pingMessage):
                        gameLog("🏓 [WebSocketSession] Ping received from \(pingMessage.playerID)")
                    case .pong(let pongMessage):
                        gameLog("🏓 [WebSocketSession] Pong received from \(pongMessage.playerID) - Latency: \(pongMessage.latencyMs)ms")
                    case .playerReady(let readyMessage):
                        gameLog("✅ [WebSocketSession] Player ready status update: \(readyMessage.playerID) - Ready: \(readyMessage.isReady)")
                    case .gameStart(let startMessage):
                        gameLog("🚀 [WebSocketSession] Game start initiated by: \(startMessage.initiatorPlayerID)")
                    case .gameCountdown(let countdownMessage):
                        gameLog("⏰ [WebSocketSession] Game countdown: \(countdownMessage.countdown)")
                    case .gameStatus(let statusMessage):
                        gameLog("📊 [WebSocketSession] Game status: \(statusMessage.gameState) from \(statusMessage.senderPlayerID)")
                    }

                    messageSubject.send(multiplayerMessage)
                }
            } catch {
                gameLog("❌ [WebSocketSession] Failed to decode message:")
                gameLog("   Error: \(error)")
                gameLog("   Raw text: \(text)")

                // Try to decode as a generic JSON to understand the structure
                do {
                    if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        gameLog("   JSON structure received:")
                        for (key, value) in jsonObject {
                            gameLog("     \(key): \(value)")
                        }
                    }
                } catch {
                    gameLog("   Failed to parse as JSON: \(error)")
                }
            }
        case .data:
            gameLog("📥 [WebSocketSession] Received unexpected binary data")
        @unknown default:
            gameLog("📥 [WebSocketSession] Received unknown message type")
        }
    }

    // MARK: - Connection Monitoring

    private func startConnectionMonitoring() {
        stopConnectionMonitoring()

        gameLog("🏓 [WebSocketSession] Starting connection monitoring with \(pingInterval)s ping interval")

        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sendPingAndCheckConnection()
            }
        }
    }

    private func stopConnectionMonitoring() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func sendPingAndCheckConnection() async {
        guard isConnected else {
            gameLog("🏓 [WebSocketSession] Not connected, skipping ping")
            return
        }

        // Check if we've received a pong recently
        let timeSinceLastPong = Date().timeIntervalSince(lastPongReceived)
        if timeSinceLastPong > (pingInterval + pongTimeout) {
            gameLog("⚠️ [WebSocketSession] No pong received in \(timeSinceLastPong)s, connection may be dead")
            if !isReconnecting {
                attemptReconnection()
            }
            return
        }

        do {
            gameLog("🏓 [WebSocketSession] Sending multiplayer ping message...")

            // Create ping message with current player ID
            let pingMessage = PingMessage(playerID: localPlayerID)
            let multiplayerMessage = MultiplayerMessage.ping(pingMessage)

            // Send as proper multiplayer message
            try await sendMessage(multiplayerMessage)
            gameLog("✅ [WebSocketSession] Multiplayer ping sent successfully")

        } catch {
            gameLog("❌ [WebSocketSession] Failed to send multiplayer ping: \(error)")
            if !isReconnecting {
                attemptReconnection()
            }
        }
    }

    private func attemptReconnection() {
        guard !isDisconnectRequested else { return }
        guard !isReconnecting else {
            gameLog("🔄 [WebSocketSession] Reconnection already in progress")
            return
        }

        isReconnecting = true
        isConnected = false
        stopConnectionMonitoring()

        gameLog("🔄 [WebSocketSession] Starting reconnection attempt...")

        Task { [weak self] in
            guard let self else { return }
            do {
                // Wait a moment before reconnecting
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                guard !self.isDisconnectRequested else {
                    self.isReconnecting = false
                    return
                }
                listeningTask?.cancel()

                // Close old connection
                webSocketTask?.cancel(with: .normalClosure, reason: nil)
                webSocketTask = nil

                // Attempt to reconnect
                if let roomId = roomId {
                    try await connectToRoom(roomId: roomId, host: host)
                    gameLog("✅ [WebSocketSession] Successfully reconnected to room \(roomId)")
                } else {
                    try await connect()
                    gameLog("✅ [WebSocketSession] Successfully reconnected to host")
                }

                isReconnecting = false
            } catch {
                gameLog("❌ [WebSocketSession] Reconnection failed: \(error)")
                isReconnecting = false

                // Try again after a longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    guard let self else { return }
                    if !self.isConnected && !self.isDisconnectRequested {
                        self.attemptReconnection()
                    }
                }
            }
        }
    }

    // MARK: - Ping/Pong Handling

    public func handlePongReceived(pong: PongMessage) {
        gameLog("✅ [WebSocketSession] Pong received - connection is healthy")
        lastPongReceived = Date()
    }

    // MARK: - App Lifecycle Support

    public func handleAppDidEnterBackground() {
        gameLog("📱 [WebSocketSession] App entered background, stopping ping timer")
        stopConnectionMonitoring()
    }

    public func handleAppWillEnterForeground() {
        gameLog("📱 [WebSocketSession] App entering foreground, checking connection")

        if isConnected {
            // Resume connection monitoring
            startConnectionMonitoring()

            // Send immediate ping to test connection
            Task {
                await sendPingAndCheckConnection()
            }
        } else if !isReconnecting {
            // Attempt to reconnect if not connected
            attemptReconnection()
        }
    }
}

// MARK: - SharePlay Implementation (Placeholder)
@MainActor
public class SharePlayMultiplayerSession: MultiplayerSession {
    @Published public var isConnected: Bool = false
    @Published public var connectedPlayers: [String] = []

    private let messageSubject = PassthroughSubject<MultiplayerMessage, Never>()

    public var messagePublisher: AnyPublisher<MultiplayerMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    public func connect() async throws {
        // TODO: Implement SharePlay connection logic
        throw NetworkError.notImplemented("SharePlay implementation pending")
    }

    public func disconnect() {
        // TODO: Implement SharePlay disconnection logic
        isConnected = false
        connectedPlayers.removeAll()
    }

    public func sendMessage(_ message: MultiplayerMessage) async throws {
        // TODO: Implement SharePlay message sending
        throw NetworkError.notImplemented("SharePlay implementation pending")
    }
}

// MARK: - Error Types
public enum NetworkError: LocalizedError {
    case invalidURL
    case notConnected
    case notImplemented(String)
    case connectionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .notConnected:
            return "Not connected to multiplayer session"
        case .notImplemented(let feature):
            return "Feature not implemented: \(feature)"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Main Multiplayer Networking Manager
@MainActor
@Observable
public class MultiplayerNetworking {
    public var currentSession: (any MultiplayerSession)?
    public var currentMode: MultiplayerMode?
    public var localPlayerID: String
    public var localPlayerName: String

    // Remote drones data
    public var remoteDrones: [String: DronePositionMessage] = [:]

    // Message forwarding
    private let messageSubject = PassthroughSubject<MultiplayerMessage, Never>()
    public var messagePublisher: AnyPublisher<MultiplayerMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()

    public init(playerName: String = "Player") {
        self.localPlayerID = UUID().uuidString
        self.localPlayerName = playerName
    }

    public func startSession(mode: MultiplayerMode) async throws {
        // Disconnect any existing session
        await endSession()

        // Create new session based on mode
        let session: any MultiplayerSession
        switch mode {
        case .sharePlay:
            session = SharePlayMultiplayerSession()
        case .webSocket(let host, let port):
            session = WebSocketMultiplayerSession(host: host, port: port, localPlayerID: localPlayerID)
        }

        currentSession = session
        currentMode = mode

        // Subscribe to messages
        session.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleIncomingMessage(message)
            }
            .store(in: &cancellables)

        // Connect
        try await session.connect()

        // Send join message with selected drone type
        let profileManager = GameContext.shared.playerProfile
        let rankManager = PlayerRankManager()
        let droneType = GameContext.shared.loadout.selectedDrone?.modelName // Get selected drone model (.usdz file name)
        let joinMessage = RoomJoinMessage(
            playerID: localPlayerID,
            playerName: profileManager.playerName,
            playerColor: profileManager.playerColorHex,
            playerRank: rankManager.localPlayerRank,
            droneType: droneType
        )
        try await session.sendMessage(.roomJoin(joinMessage))
    }

    public func connectToRoom(roomId: String, host: String) async throws {
        gameLog("🌐 [MultiplayerNetworking] Connecting to room \(roomId) at \(host)")

        // Disconnect any existing session (only if currently connected)
        if currentSession?.isConnected == true {
            gameLog("🔄 [MultiplayerNetworking] Disconnecting from existing session...")
            await endSession()
        } else if let stale = currentSession {
            // Tear down a stale (e.g. reconnecting) session so it cannot resurrect
            stale.disconnect()
            currentSession = nil
            remoteDrones.removeAll()
            cancellables.removeAll()
        } else {
            gameLog("ℹ️ [MultiplayerNetworking] No existing session to disconnect")
        }

        // Create WebSocket session for room connection
        let session = WebSocketMultiplayerSession(host: host, port: 443, localPlayerID: localPlayerID)
        currentSession = session
        currentMode = .webSocket(host: host, port: 443)

        // Subscribe to messages
        session.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleIncomingMessage(message)
            }
            .store(in: &cancellables)

        // Connect to room-specific WebSocket endpoint
        try await session.connectToRoom(roomId: roomId, host: host)
        gameLog("🌐 [MultiplayerNetworking] Connected to room \(roomId)")
    }

    public func endSession() async {
        gameLog("🔌 [MultiplayerNetworking] Starting endSession...")

        if let session = currentSession {
            // Send leave message
            let leaveMessage = RoomLeaveMessage(playerID: localPlayerID)
            try? await session.sendMessage(.roomLeave(leaveMessage))
            gameLog("📤 [MultiplayerNetworking] Sent leave message")

            // Give server time to process the leave message before disconnecting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            session.disconnect()
            gameLog("🔌 [MultiplayerNetworking] Session disconnected")
        }

        currentSession = nil
        currentMode = nil
        remoteDrones.removeAll()
        cancellables.removeAll()

        gameLog("✅ [MultiplayerNetworking] endSession complete")
    }

    public func sendDronePosition(position: SIMD3<Float>, rotation: simd_quatf, state: DroneState, droneType: String? = nil) async {
        guard let session = currentSession else { return }

        let positionMessage = DronePositionMessage(
            playerID: localPlayerID,
            position: position,
            rotation: rotation,
            droneState: state,
            droneType: droneType
        )

        do {
            try await session.sendMessage(.dronePosition(positionMessage))
        } catch {
            gameLog("Failed to send drone position: \(error)")
        }
    }

    public func sendFireDroneMissile(position: SIMD3<Float>, velocity: SIMD3<Float>) async {
        guard let session = currentSession else { return }

        // Get weapon type from LoadoutManager
        let weaponType = GameContext.shared.loadout.selectedWeapon?.id

        let missileMessage = FireDroneMissileMessage(
            playerID: localPlayerID,
            startPosition: position,
            velocity: velocity,
            weaponType: weaponType
        )

        do {
            try await session.sendMessage(.fireDroneMissile(missileMessage))
            gameLog("🚀 [MultiplayerNetworking] Sent missile fire with weapon type: \(weaponType ?? "nil")")
        } catch {
            gameLog("Failed to send drone missile: \(error)")
        }
    }

    public func sendDroneDamage(victimPlayerID: String, damageAmount: Int, victimPosition: SIMD3<Float>) async {
        guard let session = currentSession else { return }

        let damageMessage = DroneDamageMessage(
            attackerPlayerID: localPlayerID,
            victimPlayerID: victimPlayerID,
            damageAmount: damageAmount,
            victimPosition: victimPosition
        )

        do {
            try await session.sendMessage(.droneDamage(damageMessage))
        } catch {
            gameLog("Failed to send drone damage: \(error)")
        }
    }

    public func sendDroneKill(killedPlayerID: String, killPosition: SIMD3<Float>) async {
        guard let session = currentSession else { return }

        let killMessage = DroneKillMessage(
            killerPlayerID: localPlayerID,
            killedPlayerID: killedPlayerID,
            killPosition: killPosition
        )

        do {
            try await session.sendMessage(.droneKill(killMessage))
        } catch {
            gameLog("Failed to send drone kill: \(error)")
        }
    }

    public func sendDroneRespawn(respawnPosition: SIMD3<Float>) async {
        guard let session = currentSession else { return }

        let respawnMessage = DroneRespawnMessage(
            playerID: localPlayerID,
            respawnPosition: respawnPosition
        )

        do {
            try await session.sendMessage(.droneRespawn(respawnMessage))
        } catch {
            gameLog("Failed to send drone respawn: \(error)")
        }
    }

    // MARK: - Lobby Messages

    public func sendPlayerReady(isReady: Bool) async {
        guard let session = currentSession else { return }

        let readyMessage = PlayerReadyMessage(
            playerID: localPlayerID,
            isReady: isReady
        )

        do {
            try await session.sendMessage(.playerReady(readyMessage))
            gameLog("✅ [MultiplayerNetworking] Sent player ready status: \(isReady)")
        } catch {
            gameLog("❌ [MultiplayerNetworking] Failed to send player ready: \(error)")
        }
    }

    public func sendGameStart() async {
        guard let session = currentSession else { return }

        let startMessage = GameStartMessage(initiatorPlayerID: localPlayerID)

        do {
            try await session.sendMessage(.gameStart(startMessage))
            gameLog("🚀 [MultiplayerNetworking] Sent game start message")
        } catch {
            gameLog("❌ [MultiplayerNetworking] Failed to send game start: \(error)")
        }
    }

    public func sendGameStatus(gameState: GameStatusMessage.GameState, players: [RoomPlayer], countdownValue: Int? = nil) async {
        guard let session = currentSession else { return }

        let statusMessage = GameStatusMessage(
            senderPlayerID: localPlayerID,
            gameState: gameState,
            players: players,
            countdownValue: countdownValue
        )

        do {
            try await session.sendMessage(.gameStatus(statusMessage))
            gameLog("📊 [MultiplayerNetworking] Sent game status: \(gameState)")
        } catch {
            gameLog("❌ [MultiplayerNetworking] Failed to send game status: \(error)")
        }
    }

    private func handleIncomingMessage(_ message: MultiplayerMessage) {
        // Forward message to subscribers
        messageSubject.send(message)

        // Handle internally for remote drones tracking
        switch message {
        case .dronePosition(let positionMessage):
            // Don't process our own messages
            if positionMessage.playerID != localPlayerID {
                remoteDrones[positionMessage.playerID] = positionMessage
            }
        case .roomJoin(let joinMessage):
            gameLog("Player joined: \(joinMessage.playerName)")
        case .roomLeave(let leaveMessage):
            gameLog("Player left: \(leaveMessage.playerID)")
            remoteDrones.removeValue(forKey: leaveMessage.playerID)
        case .roomJoinSuccess(let successMessage):
            gameLog("Room join successful for player: \(successMessage.playerID)")
        case .playerJoined(let playerMessage):
            gameLog("New player joined room: \(playerMessage.playerName)")
        case .playerLeft(let leftMessage):
            gameLog("Player left room: \(leftMessage.playerID)")
            remoteDrones.removeValue(forKey: leftMessage.playerID)
        case .error(let errorMessage):
            gameLog("Server error: \(errorMessage.code) - \(errorMessage.message)")
        case .fireDroneMissile(let missileMessage):
            gameLog("Drone missile fired by player: \(missileMessage.playerID)")
        case .droneDamage(let damageMessage):
            gameLog("Drone damage: \(damageMessage.attackerPlayerID) hit \(damageMessage.victimPlayerID) for \(damageMessage.damageAmount) damage")
        case .droneKill(let killMessage):
            gameLog("Drone kill: \(killMessage.killerPlayerID) killed \(killMessage.killedPlayerID)")
        case .droneRespawn(let respawnMessage):
            gameLog("Drone respawn: \(respawnMessage.playerID) respawned")
        case .ping(let pingMessage):
            gameLog("🏓 [MultiplayerNetworking] Ping received from \(pingMessage.playerID) at \(pingMessage.timestamp)")
            // Server should respond with pong - clients typically don't handle pings
        case .pong(let pongMessage):
            gameLog("🏓 [MultiplayerNetworking] Pong received:")
            gameLog("   Player: \(pongMessage.playerID)")
            gameLog("   Round trip time: \(pongMessage.roundTripTime * 1000)ms")
            gameLog("   Latency: \(pongMessage.latencyMs)ms")
            gameLog("   Average latency: \(pongMessage.averageLatency)ms")
            gameLog("   Ping count: \(pongMessage.pingCount)")

            // Update connection health based on pong response
            if let webSocketSession = currentSession as? WebSocketMultiplayerSession {
                webSocketSession.handlePongReceived(pong: pongMessage)
            }
        case .playerReady(let readyMessage):
            gameLog("✅ [MultiplayerNetworking] Player ready status: \(readyMessage.playerID) - Ready: \(readyMessage.isReady)")
        case .gameStart(let startMessage):
            gameLog("🚀 [MultiplayerNetworking] Game start initiated by: \(startMessage.initiatorPlayerID)")
        case .gameCountdown(let countdownMessage):
            gameLog("⏰ [MultiplayerNetworking] Game countdown: \(countdownMessage.countdown)")
        case .gameStatus(let statusMessage):
            gameLog("📊 [MultiplayerNetworking] Game status received: \(statusMessage.gameState) from \(statusMessage.senderPlayerID)")
        }
    }

    public var isConnected: Bool {
        currentSession?.isConnected ?? false
    }

    public var connectedPlayers: [String] {
        currentSession?.connectedPlayers ?? []
    }

    // MARK: - App Lifecycle Support

    public func handleAppDidEnterBackground() {
        if let webSocketSession = currentSession as? WebSocketMultiplayerSession {
            webSocketSession.handleAppDidEnterBackground()
        }
    }

    public func handleAppWillEnterForeground() {
        if let webSocketSession = currentSession as? WebSocketMultiplayerSession {
            webSocketSession.handleAppWillEnterForeground()
        }
    }
}