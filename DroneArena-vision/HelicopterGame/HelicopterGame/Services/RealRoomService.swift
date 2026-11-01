//
//  RealRoomService.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import Foundation
import Combine

@MainActor
public class RealRoomService: ObservableObject, RoomService {
    @Published public var availableRooms: [GameRoom] = []
    @Published public var isLoading: Bool = false
    @Published public var error: String?

    private let baseURL = NetworkConfig.backendBaseURL
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()

    public init() {}

    // MARK: - RoomService Implementation

    public func refreshRooms() async {
        gameLog("🌐 [RealRoomService] Starting room refresh...")
        isLoading = true
        error = nil

        do {
            let rooms = try await fetchRooms()
            gameLog("🌐 [RealRoomService] Successfully fetched \(rooms.count) rooms from API")
            for room in rooms {
                gameLog("🌐 [RealRoomService] Room: \(room.id) | Players: \(room.playerCount)/\(room.maxPlayers) | Status: \(room.status)")
            }
            self.availableRooms = rooms.map { $0.toGameRoom() }
            gameLog("🌐 [RealRoomService] Converted to \(self.availableRooms.count) UI room models")
        } catch {
            self.error = "Failed to load rooms: \(error.localizedDescription)"
            gameLog("❌ [RealRoomService] Failed to refresh rooms: \(error)")
        }

        isLoading = false
        gameLog("🌐 [RealRoomService] Room refresh completed. Loading: \(isLoading)")
    }

    public func createRoom(_ room: GameRoom) async throws -> GameRoom {
        gameLog("🏗️ [RealRoomService] Creating room: \(room.name)")

        let request = CreateRoomRequest(
            maxPlayers: room.maxPlayers,
            name: room.name.isEmpty ? nil : room.name,
            gameMode: room.gameMode
        )

        let response = try await createRoomAPI(request)
        let createdRoom = response.toGameRoom()

        gameLog("🏗️ [RealRoomService] Successfully created room ID: \(response.roomId)")
        return createdRoom
    }

    public func joinRoom(_ roomID: String) async throws {
        gameLog("🚪 [RealRoomService] Attempting to join room: \(roomID)")
        // Room joining is handled via WebSocket in MultiplayerNetworking
        // This method could be used for validation or pre-join checks
        let room = try await fetchRoom(roomID)
        gameLog("🚪 [RealRoomService] Room \(roomID) has \(room.playerCount)/\(room.maxPlayers) players, status: \(room.status)")

        if room.playerCount >= room.maxPlayers {
            gameLog("❌ [RealRoomService] Room \(roomID) is full!")
            throw RoomServiceError.roomFull
        }

        gameLog("✅ [RealRoomService] Ready to join room: \(roomID)")
    }

    public func leaveRoom() async {
        // Room leaving is handled via WebSocket disconnection
        gameLog("🚶 [RealRoomService] Leaving current room")
    }

    public func quickConnect() async throws {
        gameLog("⚡ [RealRoomService] Starting quick connect...")
        // Find the first available room with space, or suggest creating one
        try await refreshRooms()

        let availableRoom = availableRooms.first { !$0.isFull }

        if let room = availableRoom {
            gameLog("⚡ [RealRoomService] Found available room: \(room.id) (\(room.currentPlayers)/\(room.maxPlayers))")
            try await joinRoom(room.id)
        } else {
            gameLog("❌ [RealRoomService] No available rooms found for quick connect")
            // No available rooms, could create a new one or return error
            throw RoomServiceError.noAvailableRooms
        }
    }

    // MARK: - Private API Methods

    private func fetchRooms() async throws -> [APIRoom] {
        let urlString = "\(baseURL)/rooms"
        gameLog("📡 [RealRoomService] GET \(urlString)")

        guard let url = URL(string: urlString) else {
            gameLog("❌ [RealRoomService] Invalid URL: \(urlString)")
            throw RoomServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        gameLog("📡 [RealRoomService] Sending request...")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            gameLog("❌ [RealRoomService] Invalid HTTP response")
            throw RoomServiceError.invalidResponse
        }

        gameLog("📡 [RealRoomService] Response: HTTP \(httpResponse.statusCode)")

        if let responseBody = String(data: data, encoding: .utf8) {
            gameLog("📡 [RealRoomService] Response body: \(responseBody)")
        }

        guard httpResponse.statusCode == 200 else {
            gameLog("❌ [RealRoomService] Server error: HTTP \(httpResponse.statusCode)")
            throw RoomServiceError.serverError(httpResponse.statusCode)
        }

        do {
            let roomsResponse = try JSONDecoder().decode(RoomsResponse.self, from: data)
            gameLog("📡 [RealRoomService] Successfully decoded \(roomsResponse.rooms.count) rooms")
            return roomsResponse.rooms
        } catch {
            gameLog("❌ [RealRoomService] JSON decode error: \(error)")
            throw error
        }
    }

    private func fetchRoom(_ roomId: String) async throws -> APIRoom {
        let urlString = "\(baseURL)/rooms/\(roomId)"
        gameLog("📡 [RealRoomService] GET \(urlString)")

        guard let url = URL(string: urlString) else {
            gameLog("❌ [RealRoomService] Invalid URL: \(urlString)")
            throw RoomServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            gameLog("❌ [RealRoomService] Invalid HTTP response for room \(roomId)")
            throw RoomServiceError.invalidResponse
        }

        gameLog("📡 [RealRoomService] Room \(roomId) response: HTTP \(httpResponse.statusCode)")

        if let responseBody = String(data: data, encoding: .utf8) {
            gameLog("📡 [RealRoomService] Room \(roomId) body: \(responseBody)")
        }

        if httpResponse.statusCode == 404 {
            gameLog("❌ [RealRoomService] Room \(roomId) not found")
            throw RoomServiceError.roomNotFound
        }

        guard httpResponse.statusCode == 200 else {
            gameLog("❌ [RealRoomService] Room \(roomId) server error: HTTP \(httpResponse.statusCode)")
            throw RoomServiceError.serverError(httpResponse.statusCode)
        }

        do {
            let room = try JSONDecoder().decode(APIRoom.self, from: data)
            gameLog("📡 [RealRoomService] Successfully decoded room \(roomId)")
            return room
        } catch {
            gameLog("❌ [RealRoomService] Room \(roomId) JSON decode error: \(error)")
            throw error
        }
    }

    public func checkHealth() async throws -> HealthResponse {
        let urlString = "\(baseURL)/health"
        gameLog("🏥 [RealRoomService] GET \(urlString)")

        guard let url = URL(string: urlString) else {
            gameLog("❌ [RealRoomService] Invalid health URL: \(urlString)")
            throw RoomServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            gameLog("❌ [RealRoomService] Invalid HTTP response for health check")
            throw RoomServiceError.invalidResponse
        }

        gameLog("🏥 [RealRoomService] Health check response: HTTP \(httpResponse.statusCode)")

        if let responseBody = String(data: data, encoding: .utf8) {
            gameLog("🏥 [RealRoomService] Health response body: \(responseBody)")
        }

        guard httpResponse.statusCode == 200 else {
            gameLog("❌ [RealRoomService] Health check failed: HTTP \(httpResponse.statusCode)")
            throw RoomServiceError.serverError(httpResponse.statusCode)
        }

        do {
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            gameLog("🏥 [RealRoomService] Backend status: \(health.status), Rooms: \(health.rooms), Connections: \(health.connections)")
            return health
        } catch {
            gameLog("❌ [RealRoomService] Health JSON decode error: \(error)")
            throw error
        }
    }

    private func createRoomAPI(_ request: CreateRoomRequest) async throws -> CreateRoomResponse {
        let urlString = "\(baseURL)/rooms"
        gameLog("📡 [RealRoomService] POST \(urlString)")

        guard let url = URL(string: urlString) else {
            gameLog("❌ [RealRoomService] Invalid create room URL: \(urlString)")
            throw RoomServiceError.invalidURL
        }

        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let requestBody = try JSONEncoder().encode(request)
            httpRequest.httpBody = requestBody

            if let requestString = String(data: requestBody, encoding: .utf8) {
                gameLog("📡 [RealRoomService] Request body: \(requestString)")
            }
        } catch {
            gameLog("❌ [RealRoomService] Failed to encode create room request: \(error)")
            throw error
        }

        gameLog("📡 [RealRoomService] Sending create room request...")
        let (data, response) = try await session.data(for: httpRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            gameLog("❌ [RealRoomService] Invalid HTTP response for room creation")
            throw RoomServiceError.invalidResponse
        }

        gameLog("📡 [RealRoomService] Create room response: HTTP \(httpResponse.statusCode)")

        if let responseBody = String(data: data, encoding: .utf8) {
            gameLog("📡 [RealRoomService] Create room response body: \(responseBody)")
        }

        if httpResponse.statusCode == 400 {
            // Try to decode error message
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorData["error"] {
                gameLog("❌ [RealRoomService] Bad request: \(errorMessage)")
                throw RoomServiceError.badRequest(errorMessage)
            }
            throw RoomServiceError.badRequest("Invalid request parameters")
        }

        guard httpResponse.statusCode == 201 else {
            gameLog("❌ [RealRoomService] Create room server error: HTTP \(httpResponse.statusCode)")
            throw RoomServiceError.serverError(httpResponse.statusCode)
        }

        do {
            let createResponse = try JSONDecoder().decode(CreateRoomResponse.self, from: data)
            gameLog("📡 [RealRoomService] Successfully created room: \(createResponse.roomId)")
            return createResponse
        } catch {
            gameLog("❌ [RealRoomService] Create room JSON decode error: \(error)")
            throw error
        }
    }

    // MARK: - Helper Methods

    private func generateRoomId() -> String {
        return "room_\(UUID().uuidString.prefix(8))"
    }

    private func generateRoomCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - Room Service Errors

public enum RoomServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case roomNotFound
    case roomFull
    case noAvailableRooms
    case badRequest(String)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .roomNotFound:
            return "Room not found"
        case .roomFull:
            return "Room is full"
        case .noAvailableRooms:
            return "No available rooms found"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}