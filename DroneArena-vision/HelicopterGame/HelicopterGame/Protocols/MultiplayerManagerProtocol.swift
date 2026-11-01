//
//  MultiplayerManagerProtocol.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import Foundation
import Combine

// MARK: - Multiplayer Manager Protocol

/// Protocol that both MultiplayerManager and ECSMultiplayerManager can conform to
/// This allows UI components to work with either implementation
@MainActor
public protocol MultiplayerManagerProtocol: ObservableObject {
    var isConnected: Bool { get }
    var connectionStatus: String { get }
    var connectedPlayerCount: Int { get }
    var localPlayerID: String { get }
    var localPlayerName: String { get }

    func quickConnectToRoom(roomID: String?) async throws
    func startWebSocketSession(host: String, port: UInt16) async throws
    func startSharePlaySession() async throws
    func endMultiplayerSession() async
}

// MARK: - Default Implementations

extension MultiplayerManagerProtocol {
    public func quickConnectToRoom() async throws {
        try await quickConnectToRoom(roomID: nil)
    }
}

// MARK: - Conform Existing Managers

extension MultiplayerManager: MultiplayerManagerProtocol {
    public var localPlayerID: String {
        networking.localPlayerID
    }

    public var localPlayerName: String {
        networking.localPlayerName
    }
}

