//
//  MockRoomService.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import Foundation
import Combine

// MARK: - Mock Room Service for UI Development

@MainActor
public class MockRoomService: RoomService, ObservableObject {
    @Published public var availableRooms: [GameRoom] = []
    @Published public var isLoading: Bool = false
    @Published public var error: String? = nil

    public init() {
        generateMockRooms()
    }

    public func refreshRooms() async {
        isLoading = true
        error = nil

        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        generateMockRooms()
        isLoading = false
    }

    public func createRoom(_ room: GameRoom) async throws -> GameRoom {
        isLoading = true

        // Simulate room creation delay
        try? await Task.sleep(nanoseconds: 500_000_000)

        let createdRoom = room
        availableRooms.insert(createdRoom, at: 0)
        isLoading = false

        return createdRoom
    }

    public func joinRoom(_ roomID: String) async throws {
        isLoading = true

        // Simulate join delay
        try? await Task.sleep(nanoseconds: 500_000_000)

        guard let roomIndex = availableRooms.firstIndex(where: { $0.id == roomID }) else {
            isLoading = false
            throw RoomError.roomNotFound
        }

        var room = availableRooms[roomIndex]
        if room.isFull {
            isLoading = false
            throw RoomError.roomFull
        }

        // Update player count (simplified)
        let updatedRoom = GameRoom(
            id: room.id,
            name: room.name,
            hostPlayerID: room.hostPlayerID,
            hostPlayerName: room.hostPlayerName,
            currentPlayers: room.currentPlayers + 1,
            maxPlayers: room.maxPlayers,
            gameMode: room.gameMode,
            isPrivate: room.isPrivate,
            roomCode: room.roomCode
        )

        availableRooms[roomIndex] = updatedRoom
        isLoading = false
    }

    public func leaveRoom() async {
        // Implementation for leaving room
    }

    public func quickConnect() async throws {
        isLoading = true

        // Simulate quick connect
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Find an available room or create one
        if let availableRoom = availableRooms.first(where: { !$0.isFull && !$0.isPrivate }) {
            try await joinRoom(availableRoom.id)
        } else {
            // Create a new room for quick connect
            let quickRoom = GameRoom(
                name: "Quick Game \(Int.random(in: 1000...9999))",
                hostPlayerID: "quick-connect-host",
                hostPlayerName: "QuickHost",
                gameMode: MultiplayerGameMode.freeFlight.rawValue
            )
            _ = try await createRoom(quickRoom)
        }

        isLoading = false
    }

    private func generateMockRooms() {
        availableRooms = [
            GameRoom(
                name: "Sky Racers Arena",
                hostPlayerID: "host1",
                hostPlayerName: "SkyPilot",
                currentPlayers: 3,
                maxPlayers: 6,
                gameMode: MultiplayerGameMode.racing.rawValue
            ),
            GameRoom(
                name: "Delivery Masters",
                hostPlayerID: "host2",
                hostPlayerName: "PackageKing",
                currentPlayers: 2,
                maxPlayers: 4,
                gameMode: MultiplayerGameMode.delivery.rawValue
            ),
            GameRoom(
                name: "Free Flight Zone",
                hostPlayerID: "host3",
                hostPlayerName: "DroneExplorer",
                currentPlayers: 1,
                maxPlayers: 8,
                gameMode: MultiplayerGameMode.freeFlight.rawValue
            ),
            GameRoom(
                name: "Battle Arena",
                hostPlayerID: "host4",
                hostPlayerName: "WarDrone",
                currentPlayers: 4,
                maxPlayers: 4,
                gameMode: MultiplayerGameMode.battle.rawValue
            ),
            GameRoom(
                name: "Chill Flight",
                hostPlayerID: "host5",
                hostPlayerName: "RelaxedPilot",
                currentPlayers: 2,
                maxPlayers: 6,
                gameMode: MultiplayerGameMode.freeFlight.rawValue
            )
        ]
    }
}

public enum RoomError: LocalizedError {
    case roomNotFound
    case roomFull
    case connectionFailed
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .roomNotFound:
            return "Room not found"
        case .roomFull:
            return "Room is full"
        case .connectionFailed:
            return "Failed to connect to room"
        case .unauthorized:
            return "Not authorized to join this room"
        }
    }
}