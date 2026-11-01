//
//  RoomModels.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import Foundation
import QuartzCore

// MARK: - Room Management Models

public struct GameRoom: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let hostPlayerID: String
    public let hostPlayerName: String
    public let currentPlayers: Int
    public let maxPlayers: Int
    public let gameMode: String
    public let isPrivate: Bool
    public let createdAt: TimeInterval
    public let roomCode: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        hostPlayerID: String,
        hostPlayerName: String,
        currentPlayers: Int = 1,
        maxPlayers: Int = 8,
        gameMode: String = "free_flight",
        isPrivate: Bool = false,
        roomCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.hostPlayerID = hostPlayerID
        self.hostPlayerName = hostPlayerName
        self.currentPlayers = currentPlayers
        self.maxPlayers = maxPlayers
        self.gameMode = gameMode
        self.isPrivate = isPrivate
        self.createdAt = CACurrentMediaTime()
        self.roomCode = roomCode
    }

    public var isFull: Bool {
        return currentPlayers >= maxPlayers
    }

    public var playerCountText: String {
        return "\(currentPlayers)/\(maxPlayers) players"
    }
}

public struct ConnectedPlayer: Identifiable, Codable {
    public let id: String
    public let name: String
    public let isHost: Bool
    public let joinedAt: TimeInterval
    public let isReady: Bool
    public let rank: PlayerRank?

    public init(id: String, name: String, isHost: Bool = false, isReady: Bool = false, rank: PlayerRank? = nil) {
        self.id = id
        self.name = name
        self.isHost = isHost
        self.joinedAt = CACurrentMediaTime()
        self.isReady = isReady
        self.rank = rank
    }
}

public enum MultiplayerGameMode: String, CaseIterable, Identifiable {
    case freeFlight = "free_flight"
    case racing = "racing"
    case delivery = "delivery"
    case battle = "battle"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .freeFlight: return "Free Flight"
        case .racing: return "Racing"
        case .delivery: return "Delivery Challenge"
        case .battle: return "Drone Battle"
        }
    }

    public var description: String {
        switch self {
        case .freeFlight: return "Fly around together with no objectives"
        case .racing: return "Race through checkpoint courses"
        case .delivery: return "Compete to deliver packages fastest"
        case .battle: return "Battle other drones with special abilities"
        }
    }

    public var maxPlayers: Int {
        switch self {
        case .freeFlight: return 8
        case .racing: return 6
        case .delivery: return 4
        case .battle: return 4
        }
    }
}

// MARK: - API Response Models

public struct RoomsResponse: Codable {
    public let rooms: [APIRoom]
}

// MARK: - Room Creation Models

public struct CreateRoomRequest: Codable {
    public let maxPlayers: Int?
    public let name: String?
    public let gameMode: String?

    public init(maxPlayers: Int? = nil, name: String? = nil, gameMode: String? = nil) {
        self.maxPlayers = maxPlayers
        self.name = name
        self.gameMode = gameMode
    }
}

public struct CreateRoomResponse: Codable {
    public let roomId: String
    public let name: String?
    public let maxPlayers: Int
    public let gameMode: String
    public let status: String
    public let playerCount: Int
    public let players: [APIPlayer]
    public let createdAt: String

    public init(roomId: String, name: String?, maxPlayers: Int, gameMode: String, status: String, playerCount: Int, players: [APIPlayer], createdAt: String) {
        self.roomId = roomId
        self.name = name
        self.maxPlayers = maxPlayers
        self.gameMode = gameMode
        self.status = status
        self.playerCount = playerCount
        self.players = players
        self.createdAt = createdAt
    }
}

public struct APIRoom: Codable, Identifiable {
    public let id: String
    public let name: String?
    public let playerCount: Int
    public let maxPlayers: Int
    public let gameMode: String
    public let status: String
    public let createdAt: String
    public let players: [APIPlayer]?

    public init(id: String, name: String?, playerCount: Int, maxPlayers: Int, gameMode: String, status: String, createdAt: String, players: [APIPlayer]? = nil) {
        self.id = id
        self.name = name
        self.playerCount = playerCount
        self.maxPlayers = maxPlayers
        self.gameMode = gameMode
        self.status = status
        self.createdAt = createdAt
        self.players = players
    }
}

public struct APIPlayer: Codable, Identifiable {
    public let id: String
    public let name: String
    public let joinedAt: String
    public let rank: PlayerRank?

    public init(id: String, name: String, joinedAt: String, rank: PlayerRank? = nil) {
        self.id = id
        self.name = name
        self.joinedAt = joinedAt
        self.rank = rank
    }
}

public struct HealthResponse: Codable {
    public let status: String
    public let timestamp: String
    public let rooms: Int
    public let connections: Int
}

// MARK: - WebSocket Message Models are now in MultiplayerNetworking.swift

// MARK: - Extension to convert API models to UI models

extension APIRoom {
    public func toGameRoom() -> GameRoom {
        return GameRoom(
            id: id,
            name: name ?? "Room \(id)", // Provide fallback name if API doesn't include one
            hostPlayerID: players?.first?.id ?? "unknown",
            hostPlayerName: players?.first?.name ?? "Unknown Host",
            currentPlayers: playerCount,
            maxPlayers: maxPlayers,
            gameMode: gameMode, // Use actual game mode from API
            isPrivate: false, // API doesn't specify, default to false
            roomCode: nil
        )
    }
}

extension CreateRoomResponse {
    public func toGameRoom() -> GameRoom {
        return GameRoom(
            id: roomId,
            name: name ?? "Room \(roomId.suffix(4))",
            hostPlayerID: "local", // Will be set when joining
            hostPlayerName: "You", // Will be set when joining
            currentPlayers: playerCount,
            maxPlayers: maxPlayers,
            gameMode: gameMode,
            isPrivate: false, // API doesn't specify privacy in creation response
            roomCode: nil
        )
    }
}

// MARK: - Room Service Protocol

public protocol RoomService: ObservableObject {
    var availableRooms: [GameRoom] { get }
    var isLoading: Bool { get }
    var error: String? { get }

    func refreshRooms() async
    func createRoom(_ room: GameRoom) async throws -> GameRoom
    func joinRoom(_ roomID: String) async throws
    func leaveRoom() async
    func quickConnect() async throws
}