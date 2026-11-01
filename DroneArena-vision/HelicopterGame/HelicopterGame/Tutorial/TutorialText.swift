//
//  TutorialText.swift
//  HelicopterGame
//
//  Small factory for the floating, always-readable 3D instruction text used by
//  the tutorial. Mirrors the centered-billboard approach already proven out in
//  HandTutorialVisualizer, kept here so tutorial steps/controller share one
//  implementation.
//

#if os(visionOS)
import RealityKit
import UIKit
import simd

public enum TutorialText {

    /// Builds a centered, unlit, billboarded 3D text entity. The returned
    /// entity's origin is the visual center of the glyphs, so callers can place
    /// it by its midpoint.
    public static func make(_ string: String,
                            color: UIColor = .white,
                            fontSize: Float = 0.05,
                            maxWidth: CGFloat = 0.9) -> Entity {
        let mesh = MeshResource.generateText(
            string,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: CGFloat(fontSize), weight: .bold),
            containerFrame: CGRect(x: 0, y: 0, width: maxWidth, height: 0.4),
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: 1.0))
        let textEntity = ModelEntity(mesh: mesh, materials: [material])

        // Center glyphs around the container origin.
        let bounds = mesh.bounds
        textEntity.position = SIMD3<Float>(-bounds.center.x, -bounds.center.y, 0)

        let container = Entity()
        container.addChild(textEntity)
        container.components.set(BillboardComponent())
        container.components.set(OpacityComponent(opacity: 1))
        return container
    }
}
#endif
