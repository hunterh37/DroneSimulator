//
//  RingEntity.swift
//  HelicopterGame
//
//  Created by Claude on 10/6/25.
//

import RealityKit
import simd
import Foundation
import UIKit

// Typealias for entities that can have collision components
//public typealias HasCollision = Entity

public class RingEntity: Entity, HasModel, HasCollision {
    public let ringID: String
    public var isCollected: Bool = false
    public var ringValue: Int = 100
    private var pulseSpeed: Float = 2.0
    private var glowIntensity: Float = 1.0

    public required init() {
        self.ringID = UUID().uuidString
        super.init()
        setupRingVisual()
        setupPhysics()
        setupGlowAnimation()
    }

    public init(ringID: String, value: Int = 100) {
        self.ringID = ringID
        self.ringValue = value
        super.init()
        setupRingVisual()
        setupPhysics()
        setupGlowAnimation()
    }

    private func setupRingVisual() {
        // Create a blue sphere as the ring
        setupBlueSphereVisual()
    }

    private func setupBlueSphereVisual() {

        // Create a simple blue sphere
        let sphereMesh = MeshResource.generateSphere(radius: 0.3) // 0.3m radius = 0.6m diameter

        // Create a bright blue emissive material
        var blueMaterial = UnlitMaterial()
        blueMaterial.color = .init(tint: .blue, texture: nil)

        let sphereModel = ModelEntity(mesh: sphereMesh, materials: [blueMaterial])

        addChild(sphereModel)
    }

    private func setupPhysics() {

        // Create collision shape for ring collection detection
        // Use a slightly larger sphere for forgiving collection
        let shape = ShapeResource.generateSphere(radius: 0.5) // Larger than the 0.3m visual sphere

        self.components.set(CollisionComponent(shapes: [shape], mode: .trigger))

        // Configure for interaction
        self.configureRingCollision()
    }

    private func setupGlowAnimation() {
        // Create a pulsing glow effect
        let scaleAnimation = FromToByAnimation<Transform>(
            name: "ringPulse",
            from: .init(scale: [1.0, 1.0, 1.0]),
            to: .init(scale: [1.1, 1.1, 1.1]),
            duration: 1.0,
            timing: .easeInOut,
            isAdditive: false
        )

        // Play the animation on repeat with autoreverses
        if let animationResource = try? AnimationResource.generate(with: scaleAnimation) {
            playAnimation(animationResource.repeat(duration: .infinity))
        }
    }

    public func collect() {
        guard !isCollected else { return }

        isCollected = true

        GameContext.shared.sound.playRingCollectSound(entity: self)

        // Play collection effect
        playCollectionEffect()

        // Remove from scene after effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.removeFromParent()
        }
    }

    private func playCollectionEffect() {
        // Scale up and fade out effect
        let collectAnimation = FromToByAnimation<Transform>(
            name: "ringCollect",
            from: .init(scale: transform.scale),
            to: .init(scale: transform.scale * 2.0),
            duration: 0.5,
            timing: .easeOut,
            isAdditive: false
        )

        if let animationResource = try? AnimationResource.generate(with: collectAnimation) {
            playAnimation(animationResource)
        }

        // Change material to green to indicate collection
        if let modelEntity = children.first as? ModelEntity {
            var successMaterial = UnlitMaterial()
            successMaterial.color = .init(tint: .green, texture: nil)
            modelEntity.model?.materials = [successMaterial]
        }
    }

    // Method to reset ring if needed for reuse
    public func reset() {
        isCollected = false
        transform.scale = [1.0, 1.0, 1.0]

        // Reset material to original blue
        if let modelEntity = children.first as? ModelEntity {
            var ringMaterial = UnlitMaterial()
            ringMaterial.color = .init(tint: .blue, texture: nil)
            modelEntity.model?.materials = [ringMaterial]
        }

        setupGlowAnimation()
    }
}

// MARK: - Collision Configuration Extension

extension RingEntity {
    func configureRingCollision() {
        // First call the base configure method
        configureCollision()

        // Then add ring-specific collision configuration
        if var collision = components[CollisionComponent.self] {
            collision.filter = CollisionFilter(group: .init(rawValue: 1 << 2), mask: .init(rawValue: 1 << 0))
            components.set(collision)
        }
    }
}
