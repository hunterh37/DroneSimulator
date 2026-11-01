//
//  CrashPadEntity.swift
//  HelicopterGame
//
//  A glowing landing pad spawned beneath a crashed drone so it has a surface to
//  fall onto instead of dropping through the world. Fades out on recovery.
//

import RealityKit
import simd
import Foundation
import UIKit

public class CrashPadEntity: Entity, HasModel {

    public required init() {
        super.init()
        build()
        appear()
    }

    private func build() {
        // Flat translucent disc.
        let discMesh = MeshResource.generateCylinder(height: 0.04, radius: 0.6)
        var disc = UnlitMaterial()
        disc.color = .init(tint: UIColor.systemOrange.withAlphaComponent(0.45), texture: nil)
        disc.blending = .transparent(opacity: 0.6)
        let discModel = ModelEntity(mesh: discMesh, materials: [disc])
        addChild(discModel)

        // Bright rim ring for visibility.
        let ringMesh = MeshResource.generateCylinder(height: 0.05, radius: 0.62)
        var ring = UnlitMaterial()
        ring.color = .init(tint: UIColor.systemOrange, texture: nil)
        let ringModel = ModelEntity(mesh: ringMesh, materials: [ring])
        ringModel.scale = SIMD3<Float>(1, 0.9, 1)
        addChild(ringModel)
    }

    private func appear() {
        transform.scale = SIMD3<Float>(repeating: 0.2)
        let grow = FromToByAnimation<Transform>(
            name: "padAppear",
            from: .init(scale: SIMD3<Float>(repeating: 0.2)),
            to: .init(scale: SIMD3<Float>(repeating: 1.0)),
            duration: 0.25,
            timing: .easeOut,
            isAdditive: false
        )
        if let res = try? AnimationResource.generate(with: grow) {
            playAnimation(res)
        }
    }

    /// Shrink away then remove from the scene.
    public func fadeAndRemove() {
        let shrink = FromToByAnimation<Transform>(
            name: "padFade",
            from: .init(scale: transform.scale),
            to: .init(scale: SIMD3<Float>(repeating: 0.05)),
            duration: 0.3,
            timing: .easeIn,
            isAdditive: false
        )
        if let res = try? AnimationResource.generate(with: shrink) {
            playAnimation(res)
        }
        let pad = self
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            pad.removeFromParent()
        }
    }
}
