//
//  BossPositionIndicatorSystem.swift
//  HelicopterGame
//
//  Created by Claude on 10/15/25.
//  System for tracking boss position relative to device camera and displaying UI indicator
//

import RealityKit
import SwiftUI
import Combine
import Foundation

// MARK: - Boss Position Indicator Component

public struct BossPositionIndicatorComponent: Component {
    public var lastUpdateTime: TimeInterval = 0
    public var updateInterval: TimeInterval = 0.1 // 10 times per second

    public init() {}
}

// MARK: - Boss Position Data

@Observable
public class BossPositionData {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `BossPositionData.shared` directly; everyone else must
    // go through GameContext.shared.bossPosition.
    fileprivate static let shared = BossPositionData()

    // Screen-space position (0-1 normalized, where 0.5 is center)
    public var screenX: CGFloat = 0.5
    public var screenY: CGFloat = 0.5

    // Distance to boss in meters
    public var distance: Float = 0

    // Whether the boss is in front of or behind the camera
    public var isInFront: Bool = true

    // Whether the boss is visible (within reasonable field of view)
    public var isVisible: Bool = false

    // Whether a boss exists in the scene
    public var bossExists: Bool = false

    // Boss health tracking
    public var currentHealth: Float = 500.0
    public var maxHealth: Float = 500.0
    public var healthPercentage: Float {
        guard maxHealth > 0 else { return 0 }
        return currentHealth / maxHealth
    }

    private init() {}

    public func update(
        cameraPosition: SIMD3<Float>,
        cameraForward: SIMD3<Float>,
        cameraRight: SIMD3<Float>,
        cameraUp: SIMD3<Float>,
        bossPosition: SIMD3<Float>,
        currentHealth: Float,
        maxHealth: Float
    ) {
        // Calculate vector from camera to boss
        let toBoss = bossPosition - cameraPosition
        distance = length(toBoss)

        // Normalize direction to boss
        let direction = normalize(toBoss)

        // Check if boss is in front of camera (dot product > 0 means in front)
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
            // Boss is in front - use perspective projection
            // Use a simple approximation: divide by forward distance for perspective
            let perspectiveFactor = max(0.1, forwardDot) // Avoid division by zero

            // Map to screen space with perspective
            // FOV approximation: ±1 at the edges with perspective
            screenX = CGFloat(0.5 + (rightDot / perspectiveFactor) * 0.4) // 0.4 is FOV scaling factor
            screenY = CGFloat(0.5 - (upDot / perspectiveFactor) * 0.4) // Invert Y for screen space

            // Clamp to screen bounds with some margin for edge indicators
            screenX = max(0.05, min(0.95, screenX))
            screenY = max(0.05, min(0.95, screenY))

            // Boss is visible if it's reasonably in front and within FOV
            isVisible = forwardDot > 0.3 && abs(rightDot) < 1.5 && abs(upDot) < 1.5
        } else {
            // Boss is behind - position at screen edges based on direction
            // Point toward the boss from the opposite side
            screenX = CGFloat(0.5 - (rightDot * 0.4)) // Flip direction for behind
            screenY = CGFloat(0.5 + (upDot * 0.4)) // Flip both for behind

            // Clamp to screen edges
            screenX = max(0.05, min(0.95, screenX))
            screenY = max(0.05, min(0.95, screenY))

            isVisible = true // Always show indicator when boss is behind
        }

        // Update health data
        self.currentHealth = currentHealth
        self.maxHealth = maxHealth

        bossExists = true
    }

    public func clearBoss() {
        bossExists = false
        distance = 0
        currentHealth = 0
        maxHealth = 500.0
    }
}

// MARK: - Boss Position Indicator System

public class BossPositionIndicatorSystem: System {
    private var cameraAnchorEntity: Entity?
    private var bossEntity: Entity?
    private weak var rootEntity: Entity?
    private static let bossQuery = EntityQuery(where: .has(EnemyAIBossComponent.self))

    public required init(scene: RealityKit.Scene) {
        gameLog("👑🎯 [BossPositionIndicator] System initialized")
    }

    public func update(context: SceneUpdateContext) {
        let currentTime = CACurrentMediaTime()

        // Create camera anchor if it doesn't exist
        if cameraAnchorEntity == nil {
            setupCameraAnchor(in: context.scene)
        }

        // Find boss entity via component query (O(bosses), not a full scene walk)
        bossEntity = context.scene.performQuery(Self.bossQuery).first(where: { _ in true })

        // If no boss exists, clear the position data once
        guard let boss = bossEntity else {
            if GameContext.shared.bossPosition.bossExists {
                GameContext.shared.bossPosition.clearBoss()
            }
            return
        }

        // Update position data
        guard let cameraAnchor = cameraAnchorEntity else {
            return
        }

        // Throttle updates to 10 times per second
        let component = cameraAnchor.components[BossPositionIndicatorComponent.self] ?? BossPositionIndicatorComponent()

        if currentTime - component.lastUpdateTime < component.updateInterval {
            return
        }

        // Update component timestamp
        var updatedComponent = component
        updatedComponent.lastUpdateTime = currentTime
        cameraAnchor.components[BossPositionIndicatorComponent.self] = updatedComponent

        // Get camera world position and orientation
        let cameraPosition = cameraAnchor.position(relativeTo: nil)

        // Calculate camera forward, right, and up vectors from orientation
        let cameraOrientation = cameraAnchor.orientation(relativeTo: nil)
        let cameraForward = cameraOrientation.act(SIMD3<Float>(0, 0, -1)) // Negative Z is forward
        let cameraRight = cameraOrientation.act(SIMD3<Float>(1, 0, 0)) // Positive X is right
        let cameraUp = cameraOrientation.act(SIMD3<Float>(0, 1, 0)) // Positive Y is up

        // Get boss world position
        let bossPosition = boss.position(relativeTo: nil)

        // Get boss health if it's an EnemyDroneBossEntity
        var bossHealth: Float = 500.0
        var bossMaxHealth: Float = 500.0

        if let bossEntity = boss as? EnemyDroneBossEntity {
            bossHealth = bossEntity.health
            bossMaxHealth = bossEntity.maxHealth
        }

        // Update shared position data (used by UI)
        GameContext.shared.bossPosition.update(
            cameraPosition: cameraPosition,
            cameraForward: cameraForward,
            cameraRight: cameraRight,
            cameraUp: cameraUp,
            bossPosition: bossPosition,
            currentHealth: bossHealth,
            maxHealth: bossMaxHealth
        )
    }

    private func setupCameraAnchor(in scene: RealityKit.Scene) {
        gameLog("👑🎯 [BossPositionIndicator] Setting up camera anchor entity")

        // Create entity anchored to camera
        let anchor = Entity()
        anchor.name = "BossPositionIndicatorCameraAnchor"

#if os(visionOS)
        anchor.components.set(AnchoringComponent(.head, trackingMode: .continuous))
#else
        // Add camera anchoring component
        anchor.components.set(AnchoringComponent(.camera, trackingMode: .continuous))
#endif
        // Add our tracking component
        anchor.components.set(BossPositionIndicatorComponent())

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
            gameLog("👑🎯 [BossPositionIndicator] Added camera anchor to root entity")
        }
    }

    private func findBossEntity(in scene: RealityKit.Scene) -> Entity? {
        // Look for EnemyDroneBossEntity in the scene
        let allEntities = Array(scene.performQuery(EntityQuery(where: .has(ModelComponent.self))))

        for entity in allEntities {
            // Traverse up to check all ancestors
            var current: Entity? = entity
            while let node = current {
                if node is EnemyDroneBossEntity {
                    return node
                }
                current = node.parent
            }

            // Also check if the entity itself is an EnemyDroneBossEntity
            if entity is EnemyDroneBossEntity {
                return entity
            }
        }

        return nil
    }
}

// MARK: - Boss Position Indicator UI View

public struct BossPositionIndicatorView: View {
    @State private var positionData = GameContext.shared.bossPosition

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            // Only show indicator if boss exists and has position
            if positionData.bossExists && positionData.distance > 0 {
                ZStack {
                    // Boss indicator with health bar
                    VStack(spacing: 4) {
                        // Main indicator icon - menacing red/orange for boss
                        ZStack {
                            // Background circle with pulsing effect
                            Circle()
                                .fill(positionData.isInFront ? Color.red.opacity(0.4) : Color.orange.opacity(0.4))
                                .frame(width: 60, height: 60)

                            // Border with warning style
                            Circle()
                                .stroke(positionData.isInFront ? Color.red : Color.orange, lineWidth: 3)
                                .frame(width: 60, height: 60)

                            // Boss icon and distance
                            VStack(spacing: 2) {
                                // Crown icon for boss
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.yellow)
                                    .shadow(color: .red, radius: 4)

                                // Distance text
                                Text("\(Int(positionData.distance))m")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2)
                            }
                        }

                        // Health bar container
                        VStack(spacing: 2) {
                            // Health bar with fill
                            ZStack(alignment: .leading) {
                                // Background bar
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 80, height: 12)

                                // Health fill with color gradient based on health percentage
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(healthBarColor(for: positionData.healthPercentage))
                                    .frame(width: 80 * CGFloat(positionData.healthPercentage), height: 12)
                                    .animation(.easeOut(duration: 0.2), value: positionData.healthPercentage)

                                // Border
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                                    .frame(width: 80, height: 12)
                            }

                            // Health text
                            Text("\(Int(positionData.currentHealth))/\(Int(positionData.maxHealth))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2)
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.5))
                        )
                    }
                    .position(
                        x: positionData.screenX * geometry.size.width,
                        y: positionData.screenY * geometry.size.height
                    )
                    .shadow(color: .red.opacity(0.8), radius: 8, x: 0, y: 0)
                    .animation(.easeOut(duration: 0.1), value: positionData.screenX)
                    .animation(.easeOut(duration: 0.1), value: positionData.screenY)
                }
            }
        }
        .allowsHitTesting(false) // Don't intercept touch events
    }

    // Helper function to determine health bar color based on percentage
    private func healthBarColor(for percentage: Float) -> Color {
        if percentage > 0.6 {
            return Color.green // Healthy
        } else if percentage > 0.3 {
            return Color.orange // Damaged
        } else {
            return Color.red // Critical
        }
    }
}

extension GameContext {
    public var bossPosition: BossPositionData { BossPositionData.shared }
}
