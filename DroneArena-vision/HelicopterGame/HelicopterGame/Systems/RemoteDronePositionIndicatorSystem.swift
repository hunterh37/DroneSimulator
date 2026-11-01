//
//  RemoteDronePositionIndicatorSystem.swift
//  HelicopterGame
//
//  Created by Claude on 10/15/25.
//  System for tracking remote drone positions relative to device camera and displaying UI indicators
//

import RealityKit
import SwiftUI
import Combine
import Foundation

// MARK: - Remote Drone Position Indicator Component

public struct RemoteDronePositionIndicatorComponent: Component {
    public var lastUpdateTime: TimeInterval = 0
    public var updateInterval: TimeInterval = 0.1 // 10 times per second

    public init() {}
}

// MARK: - Individual Remote Drone Position Data

public struct RemoteDronePosition: Identifiable {
    public let id: String // playerID
    public var playerName: String
    public var playerColor: String // Hex color

    // Screen-space position (0-1 normalized, where 0.5 is center)
    public var screenX: CGFloat = 0.5
    public var screenY: CGFloat = 0.5

    // Distance to drone in meters
    public var distance: Float = 0

    // Whether the drone is in front of or behind the camera
    public var isInFront: Bool = true

    // Whether the drone is visible (within reasonable field of view)
    public var isVisible: Bool = false

    // Calculate opacity based on distance from screen center
    // Returns 0.0 (transparent) at center, 1.0 (opaque) at edges
    public var edgeBasedOpacity: CGFloat {
        // Calculate distance from center (0.5, 0.5)
        let dx = screenX - 0.5
        let dy = screenY - 0.5
        let distanceFromCenter = sqrt(dx * dx + dy * dy)

        // Maximum distance from center to corner is ~0.707 (sqrt(0.5^2 + 0.5^2))
        // But we'll use a smaller radius for fade zone
        let fadeRadius: CGFloat = 0.35 // Fade zone radius (0.35 = 70% of half-screen)
        let centerDeadZone: CGFloat = 0.1 // Center zone where it's almost invisible

        if distanceFromCenter < centerDeadZone {
            // Very close to center - almost completely transparent
            return 0.05
        } else if distanceFromCenter < fadeRadius {
            // In fade zone - interpolate from transparent to opaque
            let fadeProgress = (distanceFromCenter - centerDeadZone) / (fadeRadius - centerDeadZone)
            return 0.05 + (fadeProgress * 0.95) // 0.05 to 1.0
        } else {
            // Beyond fade zone - fully opaque
            return 1.0
        }
    }

    public init(id: String, playerName: String, playerColor: String) {
        self.id = id
        self.playerName = playerName
        self.playerColor = playerColor
    }

    public mutating func update(
        cameraPosition: SIMD3<Float>,
        cameraForward: SIMD3<Float>,
        cameraRight: SIMD3<Float>,
        cameraUp: SIMD3<Float>,
        dronePosition: SIMD3<Float>
    ) {
        // Calculate vector from camera to drone
        let toDrone = dronePosition - cameraPosition
        distance = length(toDrone)

        // Normalize direction to drone
        let direction = normalize(toDrone)

        // Check if drone is in front of camera (dot product > 0 means in front)
        let forwardDot = dot(direction, cameraForward)
        isInFront = forwardDot > 0

        // Calculate position on screen using dot products with camera axes
        // Right dot product maps to X axis (-1 left, +1 right)
        let rightDot = dot(direction, cameraRight)
        // Up dot product maps to Y axis (-1 down, +1 up)
        let upDot = dot(direction, cameraUp)

        // Convert to screen coordinates (0-1, where 0.5 is center)
        // Note: In screen space, Y increases downward, so we invert upDot
        if isInFront {
            // Drone is in front - use perspective projection
            // Use a simple approximation: divide by forward distance for perspective
            let perspectiveFactor = max(0.1, forwardDot) // Avoid division by zero

            // Map to screen space with perspective
            // FOV approximation: ±1 at the edges with perspective
            screenX = CGFloat(0.5 + (rightDot / perspectiveFactor) * 0.4) // 0.4 is FOV scaling factor
            screenY = CGFloat(0.5 - (upDot / perspectiveFactor) * 0.4) // Invert Y for screen space

            // Clamp to screen bounds with some margin for edge indicators
            screenX = max(0.05, min(0.95, screenX))
            screenY = max(0.05, min(0.95, screenY))

            // Drone is visible if it's reasonably in front and within FOV
            isVisible = forwardDot > 0.3 && abs(rightDot) < 1.5 && abs(upDot) < 1.5
        } else {
            // Drone is behind - position at screen edges based on direction
            // Point toward the drone from the opposite side
            screenX = CGFloat(0.5 - (rightDot * 0.4)) // Flip direction for behind
            screenY = CGFloat(0.5 + (upDot * 0.4)) // Flip both for behind

            // Clamp to screen edges
            screenX = max(0.05, min(0.95, screenX))
            screenY = max(0.05, min(0.95, screenY))

            isVisible = true // Always show indicator when drone is behind
        }
    }
}

// MARK: - Remote Drone Position Data Manager

@Observable
public class RemoteDronePositionData {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `RemoteDronePositionData.shared` directly; everyone
    // else must go through GameContext.shared.remoteDronePosition.
    fileprivate static let shared = RemoteDronePositionData()

    // Dictionary of remote drone positions, keyed by playerID
    public var drones: [String: RemoteDronePosition] = [:]

    private init() {}

    public func addDrone(playerID: String, playerName: String, playerColor: String) {
        drones[playerID] = RemoteDronePosition(
            id: playerID,
            playerName: playerName,
            playerColor: playerColor
        )
        gameLog("🎯 [RemoteDronePositionData] Added tracking for drone: \(playerName) (\(playerID))")
    }

    public func removeDrone(playerID: String) {
        drones.removeValue(forKey: playerID)
        gameLog("🎯 [RemoteDronePositionData] Removed tracking for drone: \(playerID)")
    }

    public func updateDrone(
        playerID: String,
        cameraPosition: SIMD3<Float>,
        cameraForward: SIMD3<Float>,
        cameraRight: SIMD3<Float>,
        cameraUp: SIMD3<Float>,
        dronePosition: SIMD3<Float>
    ) {
        guard var drone = drones[playerID] else { return }

        drone.update(
            cameraPosition: cameraPosition,
            cameraForward: cameraForward,
            cameraRight: cameraRight,
            cameraUp: cameraUp,
            dronePosition: dronePosition
        )

        drones[playerID] = drone
    }

    public func clear() {
        drones.removeAll()
        gameLog("🎯 [RemoteDronePositionData] Cleared all remote drone tracking")
    }
}

// MARK: - Remote Drone Position Indicator System

public class RemoteDronePositionIndicatorSystem: System {
    private var cameraAnchorEntity: Entity?
    private weak var rootEntity: Entity?

    public required init(scene: RealityKit.Scene) {
        gameLog("🎯 [RemoteDronePositionIndicator] System initialized")
    }

    public func update(context: SceneUpdateContext) {
        let currentTime = CACurrentMediaTime()

        // Create camera anchor if it doesn't exist
        if cameraAnchorEntity == nil {
            setupCameraAnchor(in: context.scene)
        }

        // Update position data
        guard let cameraAnchor = cameraAnchorEntity else {
            return
        }

        // Throttle updates to 10 times per second
        let component = cameraAnchor.components[RemoteDronePositionIndicatorComponent.self] ?? RemoteDronePositionIndicatorComponent()

        if currentTime - component.lastUpdateTime < component.updateInterval {
            return
        }

        // Update component timestamp
        var updatedComponent = component
        updatedComponent.lastUpdateTime = currentTime
        cameraAnchor.components[RemoteDronePositionIndicatorComponent.self] = updatedComponent

        // Get camera world position and orientation
        let cameraPosition = cameraAnchor.position(relativeTo: nil)

        // Calculate camera forward, right, and up vectors from orientation
        let cameraOrientation = cameraAnchor.orientation(relativeTo: nil)
        let cameraForward = cameraOrientation.act(SIMD3<Float>(0, 0, -1)) // Negative Z is forward
        let cameraRight = cameraOrientation.act(SIMD3<Float>(1, 0, 0)) // Positive X is right
        let cameraUp = cameraOrientation.act(SIMD3<Float>(0, 1, 0)) // Positive Y is up

        // Find all remote drones and update their positions
        let remoteDrones = findRemoteDrones(in: context.scene)

        for remoteDrone in remoteDrones {
            let dronePosition = remoteDrone.position(relativeTo: nil)

            // Update shared position data (used by UI)
            GameContext.shared.remoteDronePosition.updateDrone(
                playerID: remoteDrone.playerID,
                cameraPosition: cameraPosition,
                cameraForward: cameraForward,
                cameraRight: cameraRight,
                cameraUp: cameraUp,
                dronePosition: dronePosition
            )
        }
    }

    private func setupCameraAnchor(in scene: RealityKit.Scene) {
        gameLog("🎯 [RemoteDronePositionIndicator] Setting up camera anchor entity")

        // Create entity anchored to camera
        let anchor = Entity()
        anchor.name = "RemoteDronePositionIndicatorCameraAnchor"

#if os(visionOS)
        anchor.components.set(AnchoringComponent(.head, trackingMode: .continuous))
        #else
        // Add camera anchoring component
        anchor.components.set(AnchoringComponent(.camera, trackingMode: .continuous))
        #endif

        // Add our tracking component
        anchor.components.set(RemoteDronePositionIndicatorComponent())

        // Add to scene by finding root entity
        let entities = Array(scene.performQuery(EntityQuery(where: .has(ModelComponent.self))))
        if let firstEntity = entities.first {
            // Find root entity by traversing up
            var root = firstEntity
            while let parent = root.parent {
                root = parent
            }
            root.addChild(anchor)
            rootEntity = root
            cameraAnchorEntity = anchor
            gameLog("🎯 [RemoteDronePositionIndicator] Added camera anchor to root entity")
        }
    }

    private func findRemoteDrones(in scene: RealityKit.Scene) -> [RemoteDroneEntity] {
        // Look for RemoteDroneEntity instances in the scene
        let allEntities = Array(scene.performQuery(EntityQuery(where: .has(ModelComponent.self))))
        var remoteDrones: [RemoteDroneEntity] = []

        for entity in allEntities {
            // Traverse up to check all ancestors
            var current: Entity? = entity
            while let node = current {
                if let remoteDrone = node as? RemoteDroneEntity {
                    if !remoteDrones.contains(where: { $0.playerID == remoteDrone.playerID }) {
                        remoteDrones.append(remoteDrone)

                        // Ensure this drone is registered in the position data
                        if GameContext.shared.remoteDronePosition.drones[remoteDrone.playerID] == nil {
                            GameContext.shared.remoteDronePosition.addDrone(
                                playerID: remoteDrone.playerID,
                                playerName: remoteDrone.playerName,
                                playerColor: remoteDrone.playerColor
                            )
                        }
                    }
                    break
                }
                current = node.parent
            }

            // Also check if the entity itself is a RemoteDroneEntity
            if let remoteDrone = entity as? RemoteDroneEntity {
                if !remoteDrones.contains(where: { $0.playerID == remoteDrone.playerID }) {
                    remoteDrones.append(remoteDrone)

                    // Ensure this drone is registered in the position data
                    if GameContext.shared.remoteDronePosition.drones[remoteDrone.playerID] == nil {
                        GameContext.shared.remoteDronePosition.addDrone(
                            playerID: remoteDrone.playerID,
                            playerName: remoteDrone.playerName,
                            playerColor: remoteDrone.playerColor
                        )
                    }
                }
            }
        }

        return remoteDrones
    }
}

// MARK: - Remote Drone Position Indicator UI View

public struct RemoteDronePositionIndicatorView: View {
    @State private var positionData = GameContext.shared.remoteDronePosition

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            // Show an indicator for each remote drone
            ForEach(Array(positionData.drones.values), id: \.id) { drone in
                if drone.distance > 0 {
                    RemoteDroneIndicator(drone: drone)
                        .position(
                            x: drone.screenX * geometry.size.width,
                            y: drone.screenY * geometry.size.height
                        )
                        .opacity(drone.edgeBasedOpacity) // Fade based on distance from center
                        .animation(.easeOut(duration: 0.1), value: drone.screenX)
                        .animation(.easeOut(duration: 0.1), value: drone.screenY)
                        .animation(.easeOut(duration: 0.2), value: drone.edgeBasedOpacity)
                }
            }
        }
        .allowsHitTesting(false) // Don't intercept touch events
    }
}

// MARK: - Individual Remote Drone Indicator

private struct RemoteDroneIndicator: View {
    let drone: RemoteDronePosition

    var body: some View {
        ZStack {
            // Get player color from hex string
            let playerUIColor = Color(hex: drone.playerColor) ?? .cyan

            // Background circle
            Circle()
                .fill(drone.isInFront ? playerUIColor.opacity(0.3) : playerUIColor.opacity(0.2))
                .frame(width: 44, height: 44)

            // Border with player color
            Circle()
                .stroke(playerUIColor, lineWidth: 2)
                .frame(width: 44, height: 44)

            // Drone icon and distance
            VStack(spacing: 1) {
                Image(systemName: "airplane")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)

                // Distance text
                Text("\(Int(drone.distance))m")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
    }
}

extension GameContext {
    public var remoteDronePosition: RemoteDronePositionData { RemoteDronePositionData.shared }
}
