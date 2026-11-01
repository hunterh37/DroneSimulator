//
//  ParcelEntity.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import RealityKit
import UIKit
import simd

public enum PackageSize {
    case small
    case medium
    case large
}

public struct PackageSpec {
    let size: PackageSize
    let mass: Float
    let gripRadius: Float

    static let small = PackageSpec(size: .small, mass: 2.0, gripRadius: 0.12)
    static let medium = PackageSpec(size: .medium, mass: 4.0, gripRadius: 0.18)
    static let large = PackageSpec(size: .large, mass: 10.0, gripRadius: 0.24)
}

public class PackageEntity: Entity, HasCollision, HasPhysics {
    public let packageID: String
    public let spec: PackageSpec
    public var isPickedUp: Bool = false
    public var isDelivered: Bool = false
    public var deliveryLocation: SIMD3<Float>
    private var glowIndicator: ModelEntity?

    public required init() {
        self.packageID = ""
        self.spec = .medium
        self.deliveryLocation = .zero
        super.init()
        setupPackageVisual()
        setupPhysics()
        setupCollision()
    }

    public init(id: String, spec: PackageSpec, deliveryLocation: SIMD3<Float>) {
        self.packageID = id
        self.spec = spec
        self.deliveryLocation = deliveryLocation
        super.init()
        setupPackageVisual()
        setupPhysics()
        setupCollision()
        setupGrabbableComponent()
    }

    private func setupPackageVisual() {
        // Determine which USDZ model to load based on size
        let modelName: String
        switch spec.size {
        case .large:
            modelName = "Package1" // Largest package
        case .medium:
            modelName = "Package2" // Medium package
        case .small:
            modelName = "Package3" // Smallest package
        }

        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "usdz") else {
            gameLog("Error: Could not find \(modelName).usdz in bundle")
            setupFallbackVisual()
            setupGlowIndicator()
            return
        }

        Task {
            do {
                // Load the USDZ model
                let packageModel = try await Entity(contentsOf: modelURL)
                await MainActor.run {
                    self.addChild(packageModel)
                    self.setupGlowIndicator()
                }
            } catch {
                gameLog("Failed to load package model \(modelName): \(error)")
                // Fallback to procedural geometry
                await MainActor.run {
                    self.setupFallbackVisual()
                    self.setupGlowIndicator()
                }
            }
        }
    }

    private func setupFallbackVisual() {
        // Size based on package spec
        let size: Float
        switch spec.size {
        case .small:
            size = 0.15
        case .medium:
            size = 0.2
        case .large:
            size = 0.3
        }

        // Main box
        let boxMesh = MeshResource.generateBox(width: size, height: size, depth: size)
        let boxMaterial = SimpleMaterial(color: .orange, roughness: 0.3, isMetallic: false)
        let box = ModelEntity(mesh: boxMesh, materials: [boxMaterial])

        // Strapping/tape details
        let strapSize = size + 0.02
        let strapOffset = size * 0.25
        let strapMesh = MeshResource.generateBox(width: strapSize, height: 0.02, depth: 0.02)
        let strapMaterial = SimpleMaterial(color: .brown, roughness: 0.8, isMetallic: false)

        let strap1 = ModelEntity(mesh: strapMesh, materials: [strapMaterial])
        strap1.transform.translation = SIMD3<Float>(0, 0, strapOffset)

        let strap2 = ModelEntity(mesh: strapMesh, materials: [strapMaterial])
        strap2.transform.translation = SIMD3<Float>(0, 0, -strapOffset)

        let strap3 = ModelEntity(mesh: strapMesh, materials: [strapMaterial])
        strap3.transform.translation = SIMD3<Float>(0, strapOffset, 0)
        strap3.transform.rotation = simd_quatf(angle: .pi/2, axis: [0, 1, 0])

        let strap4 = ModelEntity(mesh: strapMesh, materials: [strapMaterial])
        strap4.transform.translation = SIMD3<Float>(0, -strapOffset, 0)
        strap4.transform.rotation = simd_quatf(angle: .pi/2, axis: [0, 1, 0])

        addChild(box)
        addChild(strap1)
        addChild(strap2)
        addChild(strap3)
        addChild(strap4)
    }

    private func setupGlowIndicator() {
        // Size for glow indicator based on package spec
        let baseSize: Float
        switch spec.size {
        case .small:
            baseSize = 0.15
        case .medium:
            baseSize = 0.2
        case .large:
            baseSize = 0.3
        }

        // Glow indicator for interaction
        let glowSize = baseSize + 0.04
        let glowMesh = MeshResource.generateBox(width: glowSize, height: glowSize, depth: glowSize)
        let glowMaterial = SimpleMaterial(color: .yellow, roughness: 0.0, isMetallic: false)
        glowIndicator = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        glowIndicator?.isEnabled = false

        if let glow = glowIndicator {
            addChild(glow)
        }
    }

    private func setupPhysics() {
        let size: Float
        switch spec.size {
        case .small:
            size = 0.15
        case .medium:
            size = 0.2
        case .large:
            size = 0.3
        }

        let material = PhysicsMaterialResource.generate(friction: 0.5, restitution: 0.3)

        let massProperties = PhysicsMassProperties(mass: spec.mass, inertia: SIMD3<Float>(1.0, 1.0, 1.0))
        self.components.set(PhysicsBodyComponent(
            massProperties: massProperties,
            material: material,
            mode: .dynamic
        ))
    }

    private func setupCollision() {
        let size: Float
        switch spec.size {
        case .small:
            size = 0.15
        case .medium:
            size = 0.2
        case .large:
            size = 0.3
        }

        let shape = ShapeResource.generateBox(width: size, height: size, depth: size)
        self.components.set(CollisionComponent(shapes: [shape]))
    }

    public func highlightForInteraction(_ highlight: Bool) {
        glowIndicator?.isEnabled = highlight

        if highlight {
            // Start pulsing animation
            // Note: In a real implementation, you'd use RealityKit's animation system
        }
    }

    public func pickup() {
        guard !isPickedUp else { return }
        isPickedUp = true
        highlightForInteraction(false)

        // Change visual state to indicate pickup
        if let box = children.first(where: { $0 is ModelEntity }) as? ModelEntity {
            box.model?.materials = [SimpleMaterial(color: .green, roughness: 0.3, isMetallic: false)]
        }
    }

    public func drop() {
        guard isPickedUp else { return }
        isPickedUp = false

        // Restore original visual state
        if let box = children.first(where: { $0 is ModelEntity }) as? ModelEntity {
            box.model?.materials = [SimpleMaterial(color: .orange, roughness: 0.3, isMetallic: false)]
        }
    }

    public func deliver() {
        guard isPickedUp, !isDelivered else { return }
        isDelivered = true

        // Visual feedback for successful delivery
        if let box = children.first(where: { $0 is ModelEntity }) as? ModelEntity {
            box.model?.materials = [SimpleMaterial(color: .blue, roughness: 0.1, isMetallic: true)]
        }
    }

    public func checkDeliveryProximity(to position: SIMD3<Float>, threshold: Float = 1.0) -> Bool {
        let distance = length(position - deliveryLocation)
        return distance <= threshold
    }

    private func setupGrabbableComponent() {
        // Add GrabbableComponent for ECS claw system
        self.components.set(GrabbableComponent(
            gripRadius: spec.gripRadius,
            isPickedUp: isPickedUp
        ))
    }
}
