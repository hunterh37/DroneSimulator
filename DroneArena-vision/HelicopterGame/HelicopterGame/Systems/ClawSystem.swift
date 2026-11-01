//
//  ClawSystem.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import RealityKit
import simd
import Foundation
import QuartzCore

/// RealityKit System that handles claw movement, animation, and package grabbing
public class ClawSystem: System {
    private static let query = EntityQuery(where: .has(ClawComponent.self))

    public required init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let currentTime = CACurrentMediaTime() // Use absolute time

        // Process all entities with ClawComponent
        for entity in context.scene.performQuery(Self.query) {
            guard var clawComponent = entity.components[ClawComponent.self] else { continue }

            // Process pending input
            processClawInput(entity: entity, clawComponent: &clawComponent, currentTime: currentTime)

            // Update claw animation
            updateClawAnimation(entity: entity, clawComponent: &clawComponent, currentTime: currentTime)

            // Check for package collisions during grab
            switch clawComponent.state {
            case .extending:
                checkForPackageGrab(entity: entity, clawComponent: &clawComponent)
            default:
                break
            }

            // Update the component
            entity.components.set(clawComponent)
        }
    }

    private func processClawInput(entity: Entity, clawComponent: inout ClawComponent, currentTime: TimeInterval) {
        guard let inputComponent = entity.components[ClawInputComponent.self],
              let intent = inputComponent.pendingIntent else { return }

        switch intent {
        case .extendOrGrab:
            switch clawComponent.state {
            case .stowed:
                startClawExtension(entity: entity, clawComponent: &clawComponent, currentTime: currentTime)
            default:
                break
            }

        case .release:
            switch clawComponent.state {
            case .attached(let packageID):
                releasePackage(entity: entity, clawComponent: &clawComponent, packageID: packageID, currentTime: currentTime)
            default:
                break
            }
        }

        // Clear processed input
        var updatedInputComponent = inputComponent
        updatedInputComponent.pendingIntent = nil
        updatedInputComponent.lastProcessedTime = currentTime
        entity.components.set(updatedInputComponent)
    }

    private func startClawExtension(entity: Entity, clawComponent: inout ClawComponent, currentTime: TimeInterval) {
        clawComponent.state = .extending
        clawComponent.animationStartTime = currentTime
        clawComponent.targetPosition = SIMD3<Float>(0, -clawComponent.maxGrabDistance, 0)

        gameLog("🤖 Claw extending to grab packages")
    }

    private func updateClawAnimation(entity: Entity, clawComponent: inout ClawComponent, currentTime: TimeInterval) {
        switch clawComponent.state {
        case .extending, .retracting:
            break
        default:
            return
        }

        let elapsed = Float(currentTime - clawComponent.animationStartTime)
        let progress = min(elapsed / clawComponent.animationDuration, 1.0)

        // Smooth animation using ease-out curve
        let smoothProgress = 1 - pow(1 - progress, 3)

        let currentPosition = mix(
            clawComponent.originalPosition,
            clawComponent.targetPosition,
            t: smoothProgress
        )

        entity.transform.translation = currentPosition

        // Check if animation is complete
        if progress >= 1.0 {
            switch clawComponent.state {
            case .extending:
                // Extension complete - attempt grab
                attemptPackageGrab(entity: entity, clawComponent: &clawComponent, currentTime: currentTime)

            case .retracting:
                // Retraction complete - back to stowed
                clawComponent.state = .stowed
                entity.transform.translation = clawComponent.originalPosition
                gameLog("🤖 Claw retracted to stowed position")

            default:
                break
            }
        }
    }

    private func attemptPackageGrab(entity: Entity, clawComponent: inout ClawComponent, currentTime: TimeInterval) {
        let grabbedPackage = findNearestGrabbablePackage(clawPosition: entity.transform.translation, clawComponent: clawComponent)

        if let package = grabbedPackage {
            grabPackage(entity: entity, clawComponent: &clawComponent, package: package)
        } else {
            // No package found - start retracting
            startClawRetraction(entity: entity, clawComponent: &clawComponent, currentTime: currentTime)
        }
    }

    private func findNearestGrabbablePackage(clawPosition: SIMD3<Float>, clawComponent: ClawComponent) -> Entity? {
        // Find all entities with GrabbableComponent in grab radius
        // Note: In a real implementation, you'd access the scene through the system context
        // For now, this is a simplified approach that would need proper scene access
        return nil // Placeholder - would need scene access to query all grabbable entities
    }

    private func checkForPackageGrab(entity: Entity, clawComponent: inout ClawComponent) {
        // Use collision events instead of distance checking
        // This would be triggered by CollisionEvents subscription
        // For now, we'll rely on the attemptPackageGrab when animation completes
    }

    private func grabPackage(entity: Entity, clawComponent: inout ClawComponent, package: Entity) {
        guard var grabbableComponent = package.components[GrabbableComponent.self] else { return }

        // Update package state
        grabbableComponent.isPickedUp = true
        grabbableComponent.attachedToClawID = entity.id
        package.components.set(grabbableComponent)

        // Remove package physics and parent to claw
        package.components.remove(PhysicsBodyComponent.self)
        package.removeFromParent()

        // Find claw mount point
        if let mountPoint = entity.children.first(where: { $0.name == "MountPoint" }) {
            mountPoint.addChild(package)
            package.transform.translation = .zero
        } else {
            // Fallback to direct parenting
            entity.addChild(package)
            package.transform.translation = SIMD3<Float>(0, -0.1, 0)
        }

        // Update claw state
        clawComponent.state = .attached(packageID: String(package.id))
        clawComponent.attachedPackageID = String(package.id)

        gameLog("📦 Package grabbed successfully!")
    }

    private func releasePackage(entity: Entity, clawComponent: inout ClawComponent, packageID: String, currentTime: TimeInterval) {
        // Find the attached package
        guard let package = findAttachedPackage(entity: entity, packageID: packageID) else { return }

        var grabbableComponent = package.components[GrabbableComponent.self] ?? GrabbableComponent()
        grabbableComponent.isPickedUp = false
        grabbableComponent.attachedToClawID = nil
        package.components.set(grabbableComponent)

        // Remove from claw and position in world
        package.removeFromParent()

        // Get world position from claw
        let worldPosition = entity.convert(position: SIMD3<Float>(0, -0.3, 0), to: nil)

        // Add back to world scene (would need proper scene reference)
        // entity.scene?.addChild(package) // Placeholder
        package.transform.translation = worldPosition

        // Restore physics
        restorePackagePhysics(package: package)

        // Update claw state
        clawComponent.state = .releasing
        clawComponent.attachedPackageID = nil

        // Start retraction
        startClawRetraction(entity: entity, clawComponent: &clawComponent, currentTime: currentTime)

        gameLog("📦 Package released!")
    }

    private func findAttachedPackage(entity: Entity, packageID: String) -> Entity? {
        // Search through claw children for the package
        return entity.children.first { child in
            if let grabbableComponent = child.components[GrabbableComponent.self],
               grabbableComponent.attachedToClawID == entity.id {
                return String(child.id) == packageID
            }
            return false
        }
    }

    private func startClawRetraction(entity: Entity, clawComponent: inout ClawComponent, currentTime: TimeInterval) {
        clawComponent.state = .retracting
        clawComponent.animationStartTime = currentTime
        clawComponent.targetPosition = clawComponent.originalPosition

        gameLog("🤖 Claw retracting")
    }

    private func restorePackagePhysics(package: Entity) {
        // Restore physics body for dropped package
        let material = PhysicsMaterialResource.generate(friction: 0.5, restitution: 0.3)

        // Use a default size - in real implementation, would get from PackageComponent
        let size: Float = 0.2
        let shape = ShapeResource.generateBox(width: size, height: size, depth: size)

        let massProperties = PhysicsMassProperties(mass: 4.0, inertia: SIMD3<Float>(1.0, 1.0, 1.0))
        package.components.set(PhysicsBodyComponent(
            massProperties: massProperties,
            material: material,
            mode: .dynamic
        ))
        package.components.set(CollisionComponent(shapes: [shape]))
    }

    // Helper function for linear interpolation
    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        return a + t * (b - a)
    }
}

// MARK: - System Registration Extension

extension ClawSystem {
    /// Register the ClawSystem with a RealityKit scene
    public static func register(in scene: RealityKit.Scene) {
        // RealityKit Systems are automatically registered when entities have matching components
        // This method is a placeholder for future explicit registration if needed
        gameLog("🎯 ClawSystem ready for ECS processing")
    }
}