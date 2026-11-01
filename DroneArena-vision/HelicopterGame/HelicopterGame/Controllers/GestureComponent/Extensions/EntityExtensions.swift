/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
App-specific extension on Entity.
*/

import Foundation
import RealityKit

public extension Entity {
    var gestureComponent: GestureComponent? {
        get { components[GestureComponent.self] }
        set { components[GestureComponent.self] = newValue }
    }
    
    /// Returns the position of the entity specified in the app's coordinate system. On
    /// iOS and macOS, which don't have a device native coordinate system, scene
    /// space is often referred to as "world space".
    var scenePosition: SIMD3<Float> {
        get { position(relativeTo: nil) }
        set { setPosition(newValue, relativeTo: nil) }
    }
    
    /// Returns the orientation of the entity specified in the app's coordinate system. On
    /// iOS and macOS, which don't have a device native coordinate system, scene
    /// space is often referred to as "world space".
    var sceneOrientation: simd_quatf {
        get { orientation(relativeTo: nil) }
        set { setOrientation(newValue, relativeTo: nil) }
    }
    
    /// Automatically adds a collision component based on the entity's model bounds
    /// - Parameters:
    ///   - shape: The type of collision shape to create (.box, .sphere, .capsule)
    ///   - scaleFactor: Additional scale multiplier for the collision bounds (default: 1.0)
    /// - Returns: A tuple containing the calculated size, radius, and height for reference
    @discardableResult
    func addCollisionWithProperBounds(
        shape: CollisionShapeType = .box,
        scaleFactor: Float = 1.0
    ) -> (size: SIMD3<Float>, radius: Float, height: Float) {
        // Calculate bounds based on the entity's model or use default scaling
        let bounds = calculateEntityBounds()
        let size = SIMD3<Float>(bounds.x * scaleFactor, bounds.y * scaleFactor, bounds.z * scaleFactor)
        let radius = max(bounds.x, bounds.z) * 0.5 * scaleFactor
        let height = bounds.y * scaleFactor
        
        // Create collision component
        let collisionShape: ShapeResource
        switch shape {
        case .box:
            collisionShape = ShapeResource.generateBox(size: size)
        case .sphere:
            collisionShape = ShapeResource.generateSphere(radius: radius)
        case .capsule:
            collisionShape = ShapeResource.generateCapsule(height: height, radius: radius)
        }
        
        let collisionComponent = CollisionComponent(shapes: [collisionShape])
        components[CollisionComponent.self] = collisionComponent
        
        return (size: size, radius: radius, height: height)
    }
    
    /// Calculates the entity's bounds, prioritizing model bounds over entity scale
    private func calculateEntityBounds() -> SIMD3<Float> {
        // First try to get bounds from ModelComponent
        if let modelComponent = components[ModelComponent.self] {
            let modelBounds = modelComponent.mesh.bounds
            let modelSize = modelBounds.max - modelBounds.min
            return SIMD3<Float>(abs(modelSize.x), abs(modelSize.y), abs(modelSize.z))
        }
        
        // Fallback to entity scale if no model component
        let entityScale = scale
        return SIMD3<Float>(abs(entityScale.x), abs(entityScale.y), abs(entityScale.z))
    }

    /// Configures collision shapes and input handling for interactive entities
    func configureCollision() {
        self.generateCollisionShapes(recursive: true)
        self.components.set(InputTargetComponent(allowedInputTypes: .all))
#if os(visionOS)
        self.components.set(GestureComponent())
#endif
    }
}

/// Collision shape types for convenience
public enum CollisionShapeType: String, CaseIterable {
    case box = "box"
    case sphere = "sphere" 
    case capsule = "capsule"
}
