//
//  DockPadEntity.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import RealityKit
import UIKit
import simd

public class DockPadEntity: Entity, HasCollision {
    public var isPlayerInRange: Bool = false
    public var rechargingRadius: Float = 1.0
    private var indicatorEntity: ModelEntity?

    public required init() {
        super.init()
        setupDockPadVisual()
        setupCollision()
    }

    private func setupDockPadVisual() {
        // Load the DockPad.usdz model
        guard let dockPadURL = Bundle.main.url(forResource: "DockPad", withExtension: "usdz") else {
            gameLog("Error: Could not find DockPad.usdz in bundle")
            setupFallbackDockPadVisual()
            return
        }

        Task {
            do {
                let dockPadEntity = try await Entity(contentsOf: dockPadURL)

                // Scale the dock pad to appropriate size if needed
                dockPadEntity.transform.scale = [1.0, 1.0, 1.0] // Adjust scale as needed

                await MainActor.run {
                    self.addChild(dockPadEntity)

                    // Still create the recharge indicator for visual feedback
                    self.setupRechargeIndicator()
                }
            } catch {
                gameLog("Error loading DockPad.usdz: \(error)")
                await MainActor.run {
                    self.setupFallbackDockPadVisual()
                }
            }
        }
    }

    private func setupFallbackDockPadVisual() {
        // Fallback to simple shapes if USDZ fails to load
        let platformMesh = MeshResource.generateCylinder(height: 0.1, radius: 0.8)
        let platformMaterial = SimpleMaterial(color: .green, roughness: 0.2, isMetallic: true)
        let platform = ModelEntity(mesh: platformMesh, materials: [platformMaterial])

        // Landing pad markings
        let centerMesh = MeshResource.generateCylinder(height: 0.11, radius: 0.1)
        let centerMaterial = SimpleMaterial(color: .white, roughness: 0.1, isMetallic: false)
        let center = ModelEntity(mesh: centerMesh, materials: [centerMaterial])

        addChild(platform)
        addChild(center)

        // Add recharge indicator
        setupRechargeIndicator()
    }

    private func setupRechargeIndicator() {
        // Recharge indicator (initially hidden)
        let indicatorMesh = MeshResource.generateCylinder(height: 0.02, radius: 0.9)
        let indicatorMaterial = SimpleMaterial(color: .cyan, roughness: 0.0, isMetallic: false)
        indicatorEntity = ModelEntity(mesh: indicatorMesh, materials: [indicatorMaterial])
        indicatorEntity?.transform.translation = SIMD3<Float>(0, 0.06, 0)
        indicatorEntity?.isEnabled = false

        if let indicator = indicatorEntity {
            addChild(indicator)
        }
    }

    private func setupCollision() {
        let shape = ShapeResource.generateBox(width: 1.6, height: 0.1, depth: 1.6)
        self.components.set(CollisionComponent(shapes: [shape]))
    }


    public func checkPlayerProximity(to dronePosition: SIMD3<Float>) -> Bool {
        let distance = length(dronePosition - transform.translation)
        let wasInRange = isPlayerInRange
        isPlayerInRange = distance <= rechargingRadius

        // Update visual indicator
        if isPlayerInRange != wasInRange {
            updateIndicator()
        }

        return isPlayerInRange
    }

    private func updateIndicator() {
        indicatorEntity?.isEnabled = isPlayerInRange

        if isPlayerInRange {
            // Start pulsing animation - simplified for now
            indicatorEntity?.transform.scale = [1.1, 1.1, 1.1]
        } else {
            indicatorEntity?.transform.scale = [1, 1, 1]
        }
    }

    public func startRecharging() {
        // Visual feedback for recharging
        if let indicator = indicatorEntity {
            indicator.model?.materials = [SimpleMaterial(color: .green, roughness: 0.0, isMetallic: false)]
        }
    }

    public func stopRecharging() {
        // Reset visual state
        if let indicator = indicatorEntity {
            indicator.model?.materials = [SimpleMaterial(color: .cyan, roughness: 0.0, isMetallic: false)]
        }
    }
}