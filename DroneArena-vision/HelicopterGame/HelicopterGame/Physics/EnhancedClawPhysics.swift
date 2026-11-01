//
//  EnhancedClawPhysics.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import RealityKit
import simd
import Foundation
import Observation

/// Enhanced physics system for the claw with swing damping and improved package handling
@MainActor
@Observable
public class EnhancedClawPhysics {
    private weak var clawEntity: GrabberAttachmentEntity?
    private weak var droneEntity: PlayerDroneEntity?
    private weak var grabbedPackage: PackageEntity?

    // Physics properties
    private var clawBasePosition: SIMD3<Float> = .zero
    private var clawVelocity: SIMD3<Float> = .zero
    private var pendulumAngle: Float = 0.0
    private var pendulumVelocity: Float = 0.0

    // Configuration
    private let cableLength: Float = 1.5
    private let dampingFactor: Float = 0.95
    private let swingDamping: Float = 0.98
    private let maxSwingAngle: Float = Float.pi / 4 // 45 degrees
    private let springStrength: Float = 5.0
    private let gravityStrength: Float = 9.81

    // Swing stabilization
    private var stabilizationActive: Bool = false
    private var stabilizationTimer: Float = 0.0
    private let stabilizationDuration: Float = 2.0

    // Package interaction
    private var packageMass: Float = 1.0
    private var packageDamping: Float = 0.9
    private var integrityDamage: Float = 0.0
    private let maxIntegrityDamage: Float = 100.0

    // Physics update
    private var physicsTimer: Timer?
    private let physicsUpdateRate: TimeInterval = 1.0 / 60.0

    public init() {}

    public func setup(claw: GrabberAttachmentEntity, drone: PlayerDroneEntity) {
        self.clawEntity = claw
        self.droneEntity = drone
        startPhysicsLoop()
    }

    public func cleanup() {
        physicsTimer?.invalidate()
        physicsTimer = nil
    }

    // MARK: - Physics Loop

    private func startPhysicsLoop() {
        physicsTimer = Timer.scheduledTimer(withTimeInterval: physicsUpdateRate, repeats: true) { [weak self] (_: Timer) in
            self?.updatePhysics()
        }
    }

    private func updatePhysics() {
        guard let claw = clawEntity, let drone = droneEntity else { return }

        // Update base position from drone
        clawBasePosition = drone.transform.translation

        // Update pendulum physics
        updatePendulumPhysics()

        // Update claw position based on pendulum
        updateClawPosition()

        // Update grabbed package if any
        if let package = grabbedPackage {
            updateGrabbedPackagePhysics(package)
        }

        // Apply stabilization if active
        if stabilizationActive {
            updateStabilization()
        }
    }

    private func updatePendulumPhysics() {
        guard let drone = droneEntity else { return }

        // Get drone acceleration (approximate from velocity change)
        let droneAcceleration = calculateDroneAcceleration()

        // Calculate pendulum forces
        let gravityForce = gravityStrength / cableLength
        let droneForce = length(droneAcceleration) / cableLength

        // Apply forces to pendulum
        let totalForce = gravityForce * sin(pendulumAngle) + droneForce
        pendulumVelocity += totalForce * Float(physicsUpdateRate)

        // Apply damping
        pendulumVelocity *= swingDamping

        // Update angle
        pendulumAngle += pendulumVelocity * Float(physicsUpdateRate)

        // Clamp angle to prevent unrealistic swinging
        pendulumAngle = max(-maxSwingAngle, min(maxSwingAngle, pendulumAngle))

        // Apply additional damping for large crates
        if let package = grabbedPackage {
            let massRatio = package.spec.mass / 5.0 // Normalize to medium crate
            let additionalDamping = 1.0 - (massRatio * 0.1)
            pendulumVelocity *= additionalDamping
        }
    }

    private func calculateDroneAcceleration() -> SIMD3<Float> {
        guard let drone = droneEntity else { return .zero }

        // This would ideally be calculated from actual velocity changes
        // For now, estimate based on input or flight controller state
        let currentVelocity = drone.transform.translation - clawBasePosition
        return currentVelocity * 10.0 // Simplified acceleration estimate
    }

    private func updateClawPosition() {
        guard let claw = clawEntity else { return }

        // Calculate claw position based on pendulum angle
        let x = cableLength * sin(pendulumAngle)
        let y = -cableLength * cos(pendulumAngle)

        let clawTargetPosition = clawBasePosition + SIMD3<Float>(x, y, 0)

        // Smooth the position change
        let currentPosition = claw.transform.translation
        let positionDelta = clawTargetPosition - currentPosition
        let smoothedDelta = positionDelta * 0.1

        claw.transform.translation = currentPosition + smoothedDelta
    }

    private func updateGrabbedPackagePhysics(_ package: PackageEntity) {
        guard let claw = clawEntity else { return }

        // Keep package attached to claw
        let attachmentOffset = SIMD3<Float>(0, -0.5, 0) // Below claw
        let targetPosition = claw.transform.translation + attachmentOffset

        // Apply swing forces to package
        let swingForce = SIMD3<Float>(
            pendulumVelocity * 0.1,
            0,
            0
        )

        // Update package position with smooth following
        var packageTransform = package.transform
        let positionDelta = targetPosition - packageTransform.translation
        packageTransform.translation += positionDelta * 0.2 + swingForce

        // Add slight rotation based on swing
        let swingRotation = simd_quatf(angle: pendulumAngle * 0.5, axis: [0, 0, 1])
        packageTransform.rotation = simd_slerp(packageTransform.rotation, swingRotation, 0.1)

        package.transform = packageTransform

        // Update integrity based on swinging
        let swingIntensity = abs(pendulumVelocity)
        if swingIntensity > 2.0 {
            integrityDamage += swingIntensity * Float(physicsUpdateRate)
            if integrityDamage > maxIntegrityDamage {
                // Package breaks from excessive swinging
                dropPackage(reason: .integrity)
            }
        }
    }

    private func updateStabilization() {
        stabilizationTimer += Float(physicsUpdateRate)

        if stabilizationTimer >= stabilizationDuration {
            stabilizationActive = false
            stabilizationTimer = 0.0
            return
        }

        // Apply stabilization forces
        let stabilizationStrength = 1.0 - (stabilizationTimer / stabilizationDuration)
        let stabilizationForce = -pendulumAngle * springStrength * stabilizationStrength

        pendulumVelocity += stabilizationForce * Float(physicsUpdateRate)
    }

    // MARK: - Package Interaction

    public func grabPackage(_ package: PackageEntity) -> Bool {
        guard grabbedPackage == nil else { return false }

        grabbedPackage = package
        packageMass = package.spec.mass
        integrityDamage = 0.0

        // Disable package physics while grabbed
        if var physicsBody = package.components[PhysicsBodyComponent.self] {
            physicsBody.mode = .kinematic
            package.components.set(physicsBody)
        }

        // Start with some swing damping
        activateSwingStabilization()

        gameLog("Grabbed package with mass: \(packageMass)kg")
        return true
    }

    public func dropPackage(reason: DropReason = .manual) {
        guard let package = grabbedPackage else { return }

        // Re-enable package physics
        if var physicsBody = package.components[PhysicsBodyComponent.self] {
            physicsBody.mode = .dynamic
            package.components.set(physicsBody)
        }

        // Apply drop velocity based on current swing
        let dropVelocity = SIMD3<Float>(
            pendulumVelocity * 0.5,
            -abs(pendulumVelocity) * 0.3,
            0
        )

        // Apply impulse to package
        if var physicsBody = package.components[PhysicsBodyComponent.self] {
            // In a real implementation, you'd apply an impulse here
            // physicsBody.applyImpulse(dropVelocity)
        }

        // Check for damage based on drop conditions
        let dropImpact = calculateDropImpact(velocity: dropVelocity, height: package.transform.translation.y)
        if dropImpact > 10.0 {
            // Package damaged from drop
            damagePackage(package, impact: dropImpact)
        }

        grabbedPackage = nil
        packageMass = 1.0
        integrityDamage = 0.0

        gameLog("Dropped package - Reason: \(reason), Impact: \(dropImpact)")
    }

    private func calculateDropImpact(velocity: SIMD3<Float>, height: Float) -> Float {
        let velocityImpact = length(velocity) * 2.0
        let heightImpact = max(0, height - 0.5) * 5.0 // No damage below 0.5m
        return velocityImpact + heightImpact
    }

    private func damagePackage(_ package: PackageEntity, impact: Float) {
        // Visual feedback for damaged package
        // In a real implementation, you'd change materials or add broken effects
        gameLog("Package damaged! Impact: \(impact)")

        // Could trigger particle effects, sound, or material changes here
    }

    // MARK: - Stabilization Controls

    public func activateSwingStabilization() {
        stabilizationActive = true
        stabilizationTimer = 0.0
        gameLog("Swing stabilization activated")
    }

    public func emergencyStabilization() {
        // Immediate dampening for emergency situations
        pendulumVelocity *= 0.5
        pendulumAngle *= 0.8
        activateSwingStabilization()
        gameLog("Emergency stabilization applied")
    }

    // MARK: - Configuration

    public func adjustDampingForCrateSize(_ spec: PackageSpec) {
        switch spec.size {
        case .small:
            packageDamping = 0.95
        case .medium:
            packageDamping = 0.90
        case .large:
            packageDamping = 0.85
        }
    }

    public func setPhysicsQuality(_ quality: PhysicsQuality) {
        switch quality {
        case .low:
            physicsTimer?.invalidate()
            physicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] (_: Timer) in
                self?.updatePhysics()
            }
        case .medium:
            physicsTimer?.invalidate()
            physicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] (_: Timer) in
                self?.updatePhysics()
            }
        case .high:
            physicsTimer?.invalidate()
            physicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] (_: Timer) in
                self?.updatePhysics()
            }
        }
    }

    // MARK: - State Queries

    public var isSwinging: Bool {
        return abs(pendulumAngle) > 0.1 || abs(pendulumVelocity) > 0.1
    }

    public var swingIntensity: Float {
        return min(1.0, (abs(pendulumAngle) + abs(pendulumVelocity)) / 2.0)
    }

    public var packageIntegrity: Float {
        return max(0.0, 1.0 - (integrityDamage / maxIntegrityDamage))
    }

    public var hasPackage: Bool {
        return grabbedPackage != nil
    }

    public var currentPackageMass: Float {
        return packageMass
    }
}

// MARK: - Supporting Types

public enum DropReason {
    case manual
    case integrity
    case collision
    case delivery
}

public enum PhysicsQuality {
    case low
    case medium
    case high
}