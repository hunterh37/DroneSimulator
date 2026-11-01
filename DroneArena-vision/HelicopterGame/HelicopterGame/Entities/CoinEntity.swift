//
//  CoinEntity.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import RealityKit
import simd
import Foundation
import UIKit

public class CoinEntity: Entity, HasModel, HasCollision {
    public let coinID: String
    public var coinValue: Int = 10
    private var rotationSpeed: Float = 1.0 // Radians per second

    public required init() {
        self.coinID = UUID().uuidString
        super.init()
        setupCoinVisual()
        setupPhysics()
        setupRotationAnimation()
    }

    public init(coinID: String, value: Int = 10) {
        self.coinID = coinID
        self.coinValue = value
        super.init()
        setupCoinVisual()
        setupPhysics()
        setupRotationAnimation()
    }

    private func setupCoinVisual() {
        // Load the Coin.usdz model
        guard let coinURL = Bundle.main.url(forResource: "Coin", withExtension: "usdz") else {
            setupFallbackCoinVisual()
            return
        }

        Task {
            do {
                let coinModel = try await Entity(contentsOf: coinURL)

                // Scale the coin to appropriate size
                coinModel.transform.scale = [0.15, 0.15, 0.15] // Adjust scale as needed

                await MainActor.run {
                    self.addChild(coinModel)
                    if let modelComponent = coinModel.components[ModelComponent.self] {
                        self.components.set(modelComponent)
                    }
                }
            } catch {
                await MainActor.run {
                    self.setupFallbackCoinVisual()
                }
            }
        }
    }

    private func setupFallbackCoinVisual() {
        // Fallback to simple flat box if USDZ fails to load (coin-like shape)
        let coinMesh = MeshResource.generateBox(width: 0.2, height: 0.02, depth: 0.2)
        let coinMaterial = SimpleMaterial(color: .yellow, roughness: 0.1, isMetallic: true)
        let coinModel = ModelEntity(mesh: coinMesh, materials: [coinMaterial])

        self.components.set(coinModel.model!)
        addChild(coinModel)
    }

    private func setupPhysics() {
        // Create collision shape for coin pickup detection
        let shape = ShapeResource.generateBox(width: 0.2, height: 0.02, depth: 0.2)
        self.components.set(CollisionComponent(shapes: [shape], mode: .trigger))

        // Configure for interaction
        self.configureCollision()
    }

    private func setupRotationAnimation() {
        // Create a slow rotation animation around Y axis
        let rotationAnimation = FromToByAnimation<Transform>(
            name: "coinRotation",
            from: .init(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
            to: .init(rotation: simd_quatf(angle: 2 * .pi, axis: [0, 1, 0])),
            duration: 2.0, // 2 seconds for full rotation
            timing: .linear,
            isAdditive: false
        )

        // Play the animation on repeat
        let animationResource = try! AnimationResource.generate(with: rotationAnimation)
        playAnimation(animationResource.repeat())
    }

    public func updateRotation(deltaTime: Float) {
        // Manual rotation update if animation doesn't work as expected
        let rotationDelta = simd_quatf(angle: rotationSpeed * deltaTime, axis: [0, 1, 0])
        transform.rotation *= rotationDelta
    }

    public func collect() {
        // Add coin collection effects here if needed
        removeFromParent()
    }
}