//
//  GrabberAttachmentEntity.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import RealityKit
import UIKit
import simd

public class GrabberAttachmentEntity: Entity, HasPhysics, HasCollision {
    public var mountPoint: Entity?

    public required init() {
        super.init()
        //setupClawVisual()
        setupPhysics()
        setupCollision()
        setupMountPoint()
        setupClawComponents()
    }

    private func setupClawVisual() {
        // Claw arm - vertical rod (using box since cylinder not available)
        let armMesh = MeshResource.generateBox(width: 0.04, height: 0.2, depth: 0.04)
        let armMaterial = SimpleMaterial(color: .darkGray, roughness: 0.3, isMetallic: true)
        let arm = ModelEntity(mesh: armMesh, materials: [armMaterial])
        arm.transform.translation = SIMD3<Float>(0, -0.1, 0)

        // Claw grabber - simple hook shape
        let grabberMesh = MeshResource.generateBox(width: 0.15, height: 0.03, depth: 0.03)
        let grabberMaterial = SimpleMaterial(color: .gray, roughness: 0.2, isMetallic: true)
        let grabber = ModelEntity(mesh: grabberMesh, materials: [grabberMaterial])
        grabber.transform.translation = SIMD3<Float>(0, -0.2, 0)

        // Claw tips - two small prongs
        let tipMesh = MeshResource.generateBox(width: 0.02, height: 0.05, depth: 0.02)
        let tipMaterial = SimpleMaterial(color: .orange, roughness: 0.1, isMetallic: false)

        let leftTip = ModelEntity(mesh: tipMesh, materials: [tipMaterial])
        leftTip.transform.translation = SIMD3<Float>(-0.06, -0.225, 0)

        let rightTip = ModelEntity(mesh: tipMesh, materials: [tipMaterial])
        rightTip.transform.translation = SIMD3<Float>(0.06, -0.225, 0)

        addChild(arm)
        addChild(grabber)
        addChild(leftTip)
        addChild(rightTip)
    }

    private func setupPhysics() {
        let material = PhysicsMaterialResource.generate(friction: 0.2, restitution: 0.1)

        self.components.set(PhysicsBodyComponent(
            massProperties: .default,
            material: material,
            mode: .kinematic
        ))
    }

    private func setupCollision() {
        let shape = ShapeResource.generateBox(width: 0.04, height: 0.2, depth: 0.04)
        self.components.set(CollisionComponent(shapes: [shape]))
    }

    private func setupMountPoint() {
        mountPoint = Entity()
        mountPoint?.name = "MountPoint"
        mountPoint?.transform.translation = SIMD3<Float>(0, -0.25, 0)
        if let mount = mountPoint {
            addChild(mount)
        }
    }

    private func setupClawComponents() {
        // Add ClawComponent for ECS System processing
        self.components.set(ClawComponent())

        // Add ClawInputComponent for input handling
        self.components.set(ClawInputComponent())
    }

    public func setGrabbing(_ grabbing: Bool) {
        // Animate claw tips closing/opening
        guard let leftTip = children.first(where: { child in
            abs(child.transform.translation.x + 0.06) < 0.01
        }),
              let rightTip = children.first(where: { child in
            abs(child.transform.translation.x - 0.06) < 0.01
        }) else { return }

        if grabbing {
            // Close claw tips
            leftTip.transform.translation.x = -0.03
            rightTip.transform.translation.x = 0.03
        } else {
            // Open claw tips
            leftTip.transform.translation.x = -0.06
            rightTip.transform.translation.x = 0.06
        }
    }
}
