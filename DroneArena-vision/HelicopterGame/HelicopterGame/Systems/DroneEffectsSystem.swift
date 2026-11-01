//
//  DroneEffectsSystem.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import RealityKit
import simd
import QuartzCore
import UIKit
import Foundation

/// Enhanced visual effects system for drone and claw
@MainActor
@Observable
public class DroneEffectsSystem {
    private weak var droneEntity: PlayerDroneEntity?
    private weak var clawEntity: GrabberAttachmentEntity?

    // Effect entities
    private var rotorEffects: [Entity] = []
    private var thrusterEffects: [Entity] = []
    private var clawGrabBeams: [Entity] = []
    private var statusLights: [Entity] = []

    // Animation properties
    private var rotorSpeed: Float = 0.0
    private var targetRotorSpeed: Float = 0.0
    private var thrusterIntensity: Float = 0.0
    private var clawGlowIntensity: Float = 0.0

    // Effect configuration
    private let maxRotorSpeed: Float = 20.0
    private let rotorAcceleration: Float = 5.0
    private let effectsUpdateRate: TimeInterval = 1.0 / 60.0

    // Timers
    private var effectsTimer: Timer?

    public init() {}

    public func setup(drone: PlayerDroneEntity, claw: GrabberAttachmentEntity) {
        self.droneEntity = drone
        self.clawEntity = claw

        setupRotorEffects()
        setupThrusterEffects()
        setupClawEffects()
        setupStatusLights()
        startEffectsLoop()
    }

    public func cleanup() {
        effectsTimer?.invalidate()
        effectsTimer = nil

        // Remove all effect entities
        rotorEffects.forEach { $0.removeFromParent() }
        thrusterEffects.forEach { $0.removeFromParent() }
        clawGrabBeams.forEach { $0.removeFromParent() }
        statusLights.forEach { $0.removeFromParent() }

        rotorEffects.removeAll()
        thrusterEffects.removeAll()
        clawGrabBeams.removeAll()
        statusLights.removeAll()
    }

    // MARK: - Setup Methods

    private func setupRotorEffects() {
        guard let drone = droneEntity else { return }

        // Create rotor disk effects (representing spinning blades)
        let rotorPositions: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0.3, 0),    // Main rotor
            SIMD3<Float>(0.8, 0.1, 0),  // Right rotor
            SIMD3<Float>(-0.8, 0.1, 0), // Left rotor
            SIMD3<Float>(0, 0.1, 0.6),  // Front rotor
            SIMD3<Float>(0, 0.1, -0.6)  // Rear rotor
        ]

        for (index, position) in rotorPositions.enumerated() {
            let rotorEffect = createRotorEffect(at: position, size: index == 0 ? 0.8 : 0.4)
            drone.addChild(rotorEffect)
            rotorEffects.append(rotorEffect)
        }
    }

    private func createRotorEffect(at position: SIMD3<Float>, size: Float) -> Entity {
        let rotorEntity = Entity()
        rotorEntity.transform.translation = position

        // Create spinning disk visual
        let diskMesh = MeshResource.generatePlane(width: size, depth: size)
        let diskMaterial = SimpleMaterial(
            color: UIColor.white.withAlphaComponent(0.1),
            roughness: 0.0,
            isMetallic: false
        )

        let diskModel = ModelEntity(mesh: diskMesh, materials: [diskMaterial])
        rotorEntity.addChild(diskModel)

        // Add blur lines for motion effect
        for i in 0..<8 {
            let angle = Float(i) * (2 * Float.pi / 8)
            let lineEntity = createRotorBlurLine(angle: angle, radius: size / 2)
            rotorEntity.addChild(lineEntity)
        }

        return rotorEntity
    }

    private func createRotorBlurLine(angle: Float, radius: Float) -> Entity {
        let lineEntity = Entity()

        let lineMesh = MeshResource.generateBox(width: 0.02, height: 0.02, depth: radius)
        let lineMaterial = SimpleMaterial(
            color: UIColor.cyan.withAlphaComponent(0.3),
            roughness: 0.0,
            isMetallic: false
        )

        let lineModel = ModelEntity(mesh: lineMesh, materials: [lineMaterial])
        lineModel.transform.translation = SIMD3<Float>(0, 0, radius / 2)
        lineModel.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])

        lineEntity.addChild(lineModel)
        return lineEntity
    }

    private func setupThrusterEffects() {
        guard let drone = droneEntity else { return }

        // Create thruster glow effects
        let thrusterPositions: [SIMD3<Float>] = [
            SIMD3<Float>(0.4, -0.2, 0.4),   // Front right
            SIMD3<Float>(-0.4, -0.2, 0.4),  // Front left
            SIMD3<Float>(0.4, -0.2, -0.4),  // Rear right
            SIMD3<Float>(-0.4, -0.2, -0.4)  // Rear left
        ]

        for position in thrusterPositions {
            let thrusterEffect = createThrusterEffect(at: position)
            drone.addChild(thrusterEffect)
            thrusterEffects.append(thrusterEffect)
        }
    }

    private func createThrusterEffect(at position: SIMD3<Float>) -> Entity {
        let thrusterEntity = Entity()
        thrusterEntity.transform.translation = position

        // Main thruster glow
        let glowMesh = MeshResource.generateSphere(radius: 0.1)
        let glowMaterial = SimpleMaterial(
            color: UIColor.blue.withAlphaComponent(0.6),
            roughness: 0.0,
            isMetallic: false
        )

        let glowModel = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        thrusterEntity.addChild(glowModel)

        // Thruster cone effect
        let coneMesh = MeshResource.generateBox(width: 0.05, height: 0.3, depth: 0.05)
        let coneMaterial = SimpleMaterial(
            color: UIColor.cyan.withAlphaComponent(0.4),
            roughness: 0.0,
            isMetallic: false
        )

        let coneModel = ModelEntity(mesh: coneMesh, materials: [coneMaterial])
        coneModel.transform.translation = SIMD3<Float>(0, -0.15, 0)
        thrusterEntity.addChild(coneModel)

        return thrusterEntity
    }

    private func setupClawEffects() {
        guard let claw = clawEntity else { return }

        // Create grabber beam effects
        let beamPositions: [SIMD3<Float>] = [
            SIMD3<Float>(0.15, 0, 0),   // Right beam
            SIMD3<Float>(-0.15, 0, 0),  // Left beam
            SIMD3<Float>(0, 0, 0.15),   // Front beam
            SIMD3<Float>(0, 0, -0.15)   // Rear beam
        ]

        for position in beamPositions {
            let beamEffect = createClawBeamEffect(at: position)
            claw.addChild(beamEffect)
            clawGrabBeams.append(beamEffect)
        }
    }

    private func createClawBeamEffect(at position: SIMD3<Float>) -> Entity {
        let beamEntity = Entity()
        beamEntity.transform.translation = position

        // Beam line
        let beamMesh = MeshResource.generateBox(width: 0.02, height: 0.5, depth: 0.02)
        let beamMaterial = SimpleMaterial(
            color: UIColor.purple.withAlphaComponent(0.7),
            roughness: 0.0,
            isMetallic: false
        )

        let beamModel = ModelEntity(mesh: beamMesh, materials: [beamMaterial])
        beamModel.transform.translation = SIMD3<Float>(0, -0.25, 0)
        beamEntity.addChild(beamModel)

        // Beam glow sphere
        let glowMesh = MeshResource.generateSphere(radius: 0.05)
        let glowMaterial = SimpleMaterial(
            color: UIColor.purple.withAlphaComponent(0.8),
            roughness: 0.0,
            isMetallic: false
        )

        let glowModel = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        beamEntity.addChild(glowModel)

        beamEntity.isEnabled = false // Start disabled
        return beamEntity
    }

    private func setupStatusLights() {
        guard let drone = droneEntity else { return }

        // Status light positions
        let lightPositions: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0.2, 0.5),   // Front
            SIMD3<Float>(0, 0.2, -0.5),  // Rear
            SIMD3<Float>(0.5, 0.2, 0),   // Right
            SIMD3<Float>(-0.5, 0.2, 0)   // Left
        ]

        for position in lightPositions {
            let statusLight = createStatusLight(at: position)
            drone.addChild(statusLight)
            statusLights.append(statusLight)
        }
    }

    private func createStatusLight(at position: SIMD3<Float>) -> Entity {
        let lightEntity = Entity()
        lightEntity.transform.translation = position

        let lightMesh = MeshResource.generateSphere(radius: 0.03)
        let lightMaterial = SimpleMaterial(
            color: UIColor.green,
            roughness: 0.0,
            isMetallic: false
        )

        let lightModel = ModelEntity(mesh: lightMesh, materials: [lightMaterial])
        lightEntity.addChild(lightModel)

        return lightEntity
    }

    // MARK: - Effects Loop

    private func startEffectsLoop() {
        effectsTimer = Timer.scheduledTimer(withTimeInterval: effectsUpdateRate, repeats: true) { [weak self] (_: Timer) in
            self?.updateEffects()
        }
    }

    private func updateEffects() {
        updateRotorEffects()
        updateThrusterEffects()
        updateClawEffects()
        updateStatusLights()
    }

    private func updateRotorEffects() {
        // Smoothly transition rotor speed
        let speedDifference = targetRotorSpeed - rotorSpeed
        rotorSpeed += speedDifference * rotorAcceleration * Float(effectsUpdateRate)

        // Rotate rotor effects
        for rotorEffect in rotorEffects {
            var transform = rotorEffect.transform
            transform.rotation *= simd_quatf(angle: rotorSpeed * Float(effectsUpdateRate), axis: [0, 1, 0])
            rotorEffect.transform = transform

            // Update opacity based on speed
            let opacity = min(0.8, rotorSpeed / maxRotorSpeed)
            updateEntityOpacity(rotorEffect, opacity: opacity)
        }
    }

    private func updateThrusterEffects() {
        for thrusterEffect in thrusterEffects {
            // Pulsing thruster effect
            let time = CACurrentMediaTime()
            let pulse = (sin(Float(time * 10.0)) + 1.0) / 2.0
            let intensity = thrusterIntensity * pulse

            updateEntityOpacity(thrusterEffect, opacity: intensity)

            // Add slight movement for thrust effect
            let offset = intensity * 0.1 * sin(Float(time * 8.0))
            var transform = thrusterEffect.transform
            transform.translation.y += offset
            thrusterEffect.transform = transform
        }
    }

    private func updateClawEffects() {
        let isGrabbing = clawGlowIntensity > 0.0

        for beamEffect in clawGrabBeams {
            beamEffect.isEnabled = isGrabbing

            if isGrabbing {
                // Pulsing grab beam effect
                let time = CACurrentMediaTime()
                let pulse = (sin(Float(time * 15.0)) + 1.0) / 2.0
                let intensity = clawGlowIntensity * pulse

                updateEntityOpacity(beamEffect, opacity: intensity)
            }
        }
    }

    private func updateStatusLights() {
        guard let drone = droneEntity else { return }

        // Update status light colors based on drone state
        let statusColor: UIColor
        if rotorSpeed > maxRotorSpeed * 0.8 {
            statusColor = .red // High speed warning
        } else if rotorSpeed > maxRotorSpeed * 0.4 {
            statusColor = .yellow // Medium speed
        } else {
            statusColor = .green // Normal operation
        }

        for statusLight in statusLights {
            updateEntityColor(statusLight, color: statusColor)
        }

        // Blinking pattern for warnings
        if rotorSpeed > maxRotorSpeed * 0.8 {
            let time = CACurrentMediaTime()
            let blink = sin(Float(time * 8.0)) > 0
            for statusLight in statusLights {
                statusLight.isEnabled = blink
            }
        } else {
            for statusLight in statusLights {
                statusLight.isEnabled = true
            }
        }
    }

    // MARK: - Public Control Methods

    public func setRotorSpeed(_ speed: Float) {
        targetRotorSpeed = min(maxRotorSpeed, max(0, speed))
    }

    public func setThrusterIntensity(_ intensity: Float) {
        thrusterIntensity = min(1.0, max(0, intensity))
    }

    public func setClawGrabbing(_ isGrabbing: Bool) {
        clawGlowIntensity = isGrabbing ? 1.0 : 0.0
    }

    public func triggerSpecialEffect(_ effect: SpecialEffect) {
        switch effect {
        case .boost:
            triggerBoostEffect()
        case .pickup:
            triggerPickupEffect()
        case .delivery:
            triggerDeliveryEffect()
        case .warning:
            triggerWarningEffect()
        }
    }

    // MARK: - Special Effects

    private func triggerBoostEffect() {
        // Temporarily increase all effects
        let originalRotorSpeed = targetRotorSpeed
        let originalThrusterIntensity = thrusterIntensity

        setRotorSpeed(maxRotorSpeed)
        setThrusterIntensity(1.0)

        // Flash status lights
        for statusLight in statusLights {
            updateEntityColor(statusLight, color: .cyan)
        }

        // Reset after boost duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            setRotorSpeed(originalRotorSpeed)
            setThrusterIntensity(originalThrusterIntensity)
        }
    }

    private func triggerPickupEffect() {
        // Pulse claw beams
        setClawGrabbing(true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            setClawGrabbing(false)
        }
    }

    private func triggerDeliveryEffect() {
        // Success light pattern
        for (index, statusLight) in statusLights.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) { [self] in
                updateEntityColor(statusLight, color: .green)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                    updateEntityColor(statusLight, color: .white)
                }
            }
        }
    }

    private func triggerWarningEffect() {
        // Red warning flash
        for statusLight in statusLights {
            updateEntityColor(statusLight, color: .red)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            for statusLight in statusLights {
                updateEntityColor(statusLight, color: .green)
            }
        }
    }

    // MARK: - Utility Methods

    private func updateEntityOpacity(_ entity: Entity, opacity: Float) {
        // Update all ModelEntity materials in the entity hierarchy
        updateEntityMaterials(entity) { material in
            if var simpleMaterial = material as? SimpleMaterial {
                let currentColor = simpleMaterial.color.tint
                simpleMaterial.color.tint = UIColor(
                    red: currentColor.cgColor.components?[0] ?? 1.0,
                    green: currentColor.cgColor.components?[1] ?? 1.0,
                    blue: currentColor.cgColor.components?[2] ?? 1.0,
                    alpha: CGFloat(opacity)
                )
                return simpleMaterial
            }
            return material
        }
    }

    private func updateEntityColor(_ entity: Entity, color: UIColor) {
        updateEntityMaterials(entity) { material in
            if var simpleMaterial = material as? SimpleMaterial {
                simpleMaterial.color.tint = color
                return simpleMaterial
            }
            return material
        }
    }

    private func updateEntityMaterials(_ entity: Entity, transform: (Material) -> Material) {
        if let modelEntity = entity as? ModelEntity {
            modelEntity.model?.materials = modelEntity.model?.materials.map(transform) ?? []
        }

        for child in entity.children {
            updateEntityMaterials(child, transform: transform)
        }
    }
}

// MARK: - Supporting Types

public enum SpecialEffect {
    case boost
    case pickup
    case delivery
    case warning
}