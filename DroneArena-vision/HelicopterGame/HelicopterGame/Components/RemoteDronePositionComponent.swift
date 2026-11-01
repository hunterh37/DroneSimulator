//
//  RemoteDronePositionComponent.swift
//  HelicopterGame
//
//  Created by Claude on 10/3/25.
//  ECS component and system for managing remote drone position updates with smooth interpolation
//

import RealityKit
import simd
import Foundation
import QuartzCore

// MARK: - Component

public struct RemoteDronePositionComponent: Component {
    public var playerID: String
    public var targetPosition: SIMD3<Float>
    public var targetRotation: simd_quatf
    public var interpolationSpeed: Float
    public var lastUpdateTime: TimeInterval

    public init(playerID: String, interpolationSpeed: Float = 3.0) {
        self.playerID = playerID
        self.targetPosition = SIMD3<Float>.zero
        self.targetRotation = simd_quatf()
        self.interpolationSpeed = interpolationSpeed
        self.lastUpdateTime = 0
    }

    public mutating func updateTarget(position: SIMD3<Float>, rotation: simd_quatf) {
        self.targetPosition = position
        self.targetRotation = rotation
        self.lastUpdateTime = CACurrentMediaTime()
    }
}

// MARK: - System

public class RemoteDronePositionSystem: System {
    // Query for all entities with RemoteDronePositionComponent
    private static let query = EntityQuery(where: .has(RemoteDronePositionComponent.self))

    public required init(scene: Scene) { }

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)

        // Interpolate all remote drones toward their targets
        for entity in context.entities(
            matching: Self.query,
            updatingSystemWhen: .rendering
        ) {
            guard var component = entity.components[RemoteDronePositionComponent.self] else { continue }

            interpolateToTarget(entity: entity, component: &component, deltaTime: deltaTime)

            // Update the component back to the entity
            entity.components[RemoteDronePositionComponent.self] = component
        }
    }

    private func interpolateToTarget(entity: Entity, component: inout RemoteDronePositionComponent, deltaTime: Float) {
        let currentPosition = entity.transform.translation
        let currentRotation = entity.transform.rotation

        // Smooth interpolation toward target position with distance-based smoothing
        let positionDifference = component.targetPosition - currentPosition
        let positionDistance = length(positionDifference)

        // Only interpolate if there's a meaningful difference
        if positionDistance > 0.001 {
            // Use a smoother interpolation that's more gradual for larger distances
            let baseSpeed = component.interpolationSpeed
            let distanceModifier = min(positionDistance * 0.5, 1.0) // Slower for short distances
            let adjustedSpeed = baseSpeed * distanceModifier

            let interpolationFactor = min(adjustedSpeed * deltaTime, 0.8) // Cap at 80% per frame
            let newPosition = currentPosition + positionDifference * interpolationFactor
            entity.transform.translation = newPosition

            // Debug log for significant movements
            if positionDistance > 0.01 {
                gameLog("🚁 [RemoteDronePositionSystem] Interpolating \(component.playerID): \(currentPosition) -> \(newPosition) (target: \(component.targetPosition), dist: \(positionDistance))")
            }
        }

        // Smooth interpolation toward target rotation
        let rotationDifference = abs(simd_angle(simd_mul(simd_inverse(currentRotation), component.targetRotation)))

        if rotationDifference > 0.01 { // Only interpolate if there's a meaningful difference
            let interpolationFactor = min(component.interpolationSpeed * deltaTime * 0.5, 0.6) // Slower rotation
            let newRotation = simd_slerp(currentRotation, component.targetRotation, interpolationFactor)
            entity.transform.rotation = newRotation
        }
    }
}

// MARK: - Entity Extension
// Note: RemoteDroneEntity extension is defined in RemoteDroneEntity.swift to avoid circular imports