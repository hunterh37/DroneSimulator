//
//  MultiplayerPositionComponent.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import RealityKit
import Foundation
import simd
import QuartzCore

// MARK: - Multiplayer Position Component

/// Component that marks an entity for multiplayer position broadcasting
public struct MultiplayerPositionComponent: Component {
    /// Player ID for this entity
    public let playerID: String

    /// How often to send position updates (in seconds)
    public let updateInterval: TimeInterval

    /// Last time a position was sent
    public var lastUpdateTime: TimeInterval = 0

    /// Whether this entity should send position updates
    public let isBroadcaster: Bool

    /// Whether this entity should receive position updates
    public let isReceiver: Bool

    public init(
        playerID: String,
        updateInterval: TimeInterval = 1.0 / 30.0, // 30 FPS
        isBroadcaster: Bool = false,
        isReceiver: Bool = false
    ) {
        self.playerID = playerID
        self.updateInterval = updateInterval
        self.isBroadcaster = isBroadcaster
        self.isReceiver = isReceiver
    }

    /// Create component for local player (broadcaster)
    public static func localPlayer(playerID: String, updateInterval: TimeInterval = 1.0 / 30.0) -> MultiplayerPositionComponent {
        return MultiplayerPositionComponent(
            playerID: playerID,
            updateInterval: updateInterval,
            isBroadcaster: true,
            isReceiver: false
        )
    }

    /// Create component for remote player (receiver)
    public static func remotePlayer(playerID: String) -> MultiplayerPositionComponent {
        return MultiplayerPositionComponent(
            playerID: playerID,
            updateInterval: 0, // Not used for receivers
            isBroadcaster: false,
            isReceiver: true
        )
    }
}

// MARK: - Remote Position Component

/// Component that stores target position for smooth interpolation
public struct RemotePositionComponent: Component {
    /// Target position to interpolate towards
    public var targetPosition: SIMD3<Float>

    /// Target rotation to interpolate towards
    public var targetRotation: simd_quatf

    /// Target drone state
    public var targetDroneState: DroneState

    /// Interpolation speed
    public let interpolationSpeed: Float

    /// Timestamp of the last update
    public var lastUpdateTimestamp: TimeInterval

    public init(
        targetPosition: SIMD3<Float> = .zero,
        targetRotation: simd_quatf = simd_quatf(),
        targetDroneState: DroneState = .idle,
        interpolationSpeed: Float = 10.0
    ) {
        self.targetPosition = targetPosition
        self.targetRotation = targetRotation
        self.targetDroneState = targetDroneState
        self.interpolationSpeed = interpolationSpeed
        self.lastUpdateTimestamp = CACurrentMediaTime()
    }

    public mutating func updateTarget(
        position: SIMD3<Float>,
        rotation: simd_quatf,
        droneState: DroneState
    ) {
        self.targetPosition = position
        self.targetRotation = rotation
        self.targetDroneState = droneState
        self.lastUpdateTimestamp = CACurrentMediaTime()
    }
}

// MARK: - Multiplayer Metadata Component

/// Additional metadata for multiplayer entities
public struct MultiplayerMetadataComponent: Component {
    /// Display name for this player
    public let playerName: String

    /// Visual color/theme for this player
    public let playerColor: SIMD3<Float>

    /// When this player joined the session
    public let joinedAt: TimeInterval

    /// Whether this player is the host
    public let isHost: Bool

    public init(
        playerName: String,
        playerColor: SIMD3<Float> = SIMD3<Float>(1.0, 0.5, 0.0), // Orange default
        isHost: Bool = false
    ) {
        self.playerName = playerName
        self.playerColor = playerColor
        self.joinedAt = CACurrentMediaTime()
        self.isHost = isHost
    }
}