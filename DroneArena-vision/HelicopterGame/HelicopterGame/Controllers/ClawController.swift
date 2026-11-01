//
//  ClawController.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import RealityKit
import simd

@MainActor
@Observable
public class ClawController {
    public var clawState: ClawState = .stowed
    public var clawEntity: GrabberAttachmentEntity?
    public var attachedPackage: PackageEntity?

    private let maxGrabDistance: Float = 1.0
    private let grabRadius: Float = 0.5
    private var animationDuration: Float = 0.3

    private weak var drone: PlayerDroneEntity?
    private weak var worldScene: WorldSceneController?

    public init() {}

    public func setup(drone: PlayerDroneEntity, worldScene: WorldSceneController) {
        self.drone = drone
        self.worldScene = worldScene
        setupClawEntity()
    }

    private func setupClawEntity() {
        guard let drone = drone else { return }

        clawEntity = GrabberAttachmentEntity()
        clawEntity?.transform.translation = SIMD3<Float>(0, 0.05, 0)

        if let claw = clawEntity {
            drone.addChild(claw)
        }
    }

    public func processClawIntent(_ intent: ClawIntent) {
        // Send intent to ECS system via ClawInputComponent
        guard let clawEntity = clawEntity else { return }

        var inputComponent = clawEntity.components[ClawInputComponent.self] ?? ClawInputComponent()
        inputComponent.pendingIntent = intent
        clawEntity.components.set(inputComponent)

        gameLog("🎮 Claw intent sent to ECS system: \(intent)")
    }

    private func handleExtendOrGrab() {
        switch clawState {
        case .stowed:
            extendClaw()
        case .extending:
            // Already extending, ignore
            break
        case .attached:
            // Already grabbed something, ignore
            break
        case .releasing, .retracting:
            // In transition, ignore
            break
        }
    }

    private func handleRelease() {
        switch clawState {
        case .attached(let packageID):
            releasePackage(packageID: packageID)
        default:
            // Nothing to release
            break
        }
    }

    private func extendClaw() {
        clawState = .extending

        // Animate claw extension
        animateClawExtension {
            self.attemptGrab()
        }
    }

    private func attemptGrab() {
        guard let drone = drone,
              let worldScene = worldScene else {
            retractClaw()
            return
        }

        // Perform raycast downward from drone
        let rayStart = drone.transform.translation
        let rayEnd = rayStart + SIMD3<Float>(0, -maxGrabDistance, 0)

        // Find packages within grab radius
        let nearbyPackages = findNearbyPackages(at: rayStart)

        if let package = nearbyPackages.first {
            grabPackage(package)
        } else {
            retractClaw()
        }
    }

    private func findNearbyPackages(at position: SIMD3<Float>) -> [PackageEntity] {
        guard let worldScene = worldScene else { return [] }

        var nearbyPackages: [PackageEntity] = []

        // Check all packages in the scene
        for package in worldScene.packages {
            let distance = length(package.transform.translation - position)
            if distance <= package.spec.gripRadius && !package.isPickedUp {
                nearbyPackages.append(package)
            }
        }

        // Sort by distance
        nearbyPackages.sort { package1, package2 in
            let dist1 = length(package1.transform.translation - position)
            let dist2 = length(package2.transform.translation - position)
            return dist1 < dist2
        }

        return nearbyPackages
    }

    private func grabPackage(_ package: PackageEntity) {
        guard let drone = drone else { return }

        attachedPackage = package
        clawState = .attached(packageID: package.packageID)

        // Remove package physics and parent to drone
        package.components.remove(PhysicsBodyComponent.self)
        package.removeFromParent()

        // Attach to claw mount point
        if let clawMount = clawEntity?.mountPoint {
            package.transform.translation = .zero
            clawMount.addChild(package)
        }

        package.pickup()

        // Update drone state
        drone.droneState = .carryingParcel

        gameLog("Grabbed package: \(package.packageID)")
    }

    private func releasePackage(packageID: String) {
        guard let package = attachedPackage,
              package.packageID == packageID,
              let drone = drone else { return }

        clawState = .releasing

        // Remove from claw
        package.removeFromParent()
        attachedPackage = nil

        // Position in world
        package.transform.translation = drone.transform.translation + SIMD3<Float>(0, -0.3, 0)

        // Re-enable physics
        let size: Float = package.spec.size == .medium ? 0.2 : 0.3
        let shape = ShapeResource.generateBox(width: size, height: size, depth: size)
        let material = PhysicsMaterialResource.generate(friction: 0.5, restitution: 0.3)

        let massProperties = PhysicsMassProperties(mass: package.spec.mass, inertia: SIMD3<Float>(1.0, 1.0, 1.0))
        package.components.set(PhysicsBodyComponent(
            massProperties: massProperties,
            material: material,
            mode: .dynamic
        ))

        // Add back to world scene
        worldScene?.rootEntity.addChild(package)

        // Apply gentle downward impulse
        // Note: RealityKit physics bodies don't have direct velocity setting in this API
        // This would typically be done through applying forces or impulses

        package.drop()

        // Update drone state
        drone.droneState = .flying

        // Start retracting claw
        retractClaw()

        gameLog("Released package: \(packageID)")
    }

    private func retractClaw() {
        clawState = .retracting

        animateClawRetraction {
            self.clawState = .stowed
        }
    }

    private func animateClawExtension(completion: @escaping () -> Void) {
        // Animate claw extending downward
        guard let claw = clawEntity else {
            completion()
            return
        }

        let targetPosition = SIMD3<Float>(0, -0.3, 0)

        // Simple position interpolation (in real implementation, use RealityKit animations)
        claw.transform.translation = targetPosition

        // Simulate animation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(animationDuration)) {
            completion()
        }
    }

    private func animateClawRetraction(completion: @escaping () -> Void) {
        // Animate claw retracting upward
        guard let claw = clawEntity else {
            completion()
            return
        }

        let targetPosition = SIMD3<Float>(0, -0.05, 0)

        // Simple position interpolation
        claw.transform.translation = targetPosition

        // Simulate animation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(animationDuration)) {
            completion()
        }
    }

    public func update(deltaTime: Float) {
        // Update claw physics and state
    }

    public var statusText: String {
        // Read status from ECS component if available
        if let clawEntity = clawEntity,
           let clawComponent = clawEntity.components[ClawComponent.self] {
            switch clawComponent.state {
            case .stowed:
                return "Stowed"
            case .extending:
                return "Grabbing"
            case .attached:
                return "Carrying"
            case .releasing:
                return "Releasing"
            case .retracting:
                return "Retracting"
            }
        }

        // Fallback to legacy state
        switch clawState {
        case .stowed:
            return "Stowed"
        case .extending:
            return "Grabbing"
        case .attached:
            return "Carrying"
        case .releasing:
            return "Releasing"
        case .retracting:
            return "Retracting"
        }
    }

    public var isCarrying: Bool {
        if case .attached = clawState {
            return true
        }
        return false
    }
}
