//
//  PillarHologramEntity.swift
//  HelicopterGame
//
//  A floating sci-fi "holo-table" minimap that hovers above the GamepadPillar
//  deck. It renders a glowing projection disc with a scan grid, a central BLUE
//  sphere for our own drone, and RED (or other-colored) blips for enemies /
//  objectives placed at their position RELATIVE to our drone — a little 3D radar.
//
//  The contents are game-mode agnostic: the caller hands in a list of `Blip`s
//  (world positions + colors) plus our drone's world position each frame, and the
//  hologram maps everything into its local projection volume. Visibility is
//  toggled by a deck button (see GamepadPillarEntity + ImmersiveView).
//
//  All visuals use unlit/emissive materials with partial alpha so the whole thing
//  reads as a translucent light projection rather than solid geometry, and a faint
//  point light + a slowly spinning sweep ring sell the "active scanner" look.
//

import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public final class PillarHologramEntity: Entity {

    /// One thing to plot on the radar. `worldPosition` is in scene space; the
    /// hologram converts it to a position relative to our drone internally.
    public struct Blip {
        public var worldPosition: SIMD3<Float>
        public var color: UIColor
        public init(worldPosition: SIMD3<Float>, color: UIColor) {
            self.worldPosition = worldPosition
            self.color = color
        }
    }

    /// Radius of the projection disc, in meters (deck-scale).
    private static let radius: Float = 0.09
    /// How many meters of real world map to the full disc radius.
    private static let worldRange: Float = 30.0
    /// Vertical (altitude) exaggeration so height differences read on the radar.
    private static let verticalScale: Float = 0.6

    private let projectionRoot = Entity()      // everything that should spin/pulse hangs here
    private let blipRoot = Entity()            // dynamic markers live here
    private let playerMarker = ModelEntity()   // the central blue "us" sphere
    private var sweepRing: ModelEntity?
    private var modeLabelNode = ModelEntity()
    private var lastModeLabel = ""

    /// Reusable marker pool so per-frame updates never thrash the scene graph.
    private var markerPool: [ModelEntity] = []

    public static func make() -> PillarHologramEntity {
        let holo = PillarHologramEntity()
        holo.build()
        holo.isEnabled = false   // hidden until the user toggles it on
        return holo
    }

    // MARK: - Build

    private func build() {
        name = "PillarHologram"
        addChild(projectionRoot)

        // --- Emitter base sitting just above the deck: a bright thin puck the
        // projection "beams" up from. ---
        let emitter = ModelEntity(
            mesh: .generateCylinder(height: 0.004, radius: Self.radius * 0.32),
            materials: [Self.glowMaterial(.cyan, intensity: 6.0, alpha: 0.9)]
        )
        emitter.name = "HoloEmitter"
        emitter.position = SIMD3<Float>(0, -0.06, 0)
        projectionRoot.addChild(emitter)

        // Soft volumetric "beam" cone from emitter up to the disc.
        let beam = ModelEntity(
            mesh: .generateCone(height: 0.06, radius: Self.radius * 0.85),
            materials: [Self.glowMaterial(.cyan, intensity: 1.2, alpha: 0.10)]
        )
        beam.name = "HoloBeam"
        beam.position = SIMD3<Float>(0, -0.03, 0)
        projectionRoot.addChild(beam)

        // --- Projection disc (the radar floor). ---
        let disc = ModelEntity(
            mesh: .generateCylinder(height: 0.002, radius: Self.radius),
            materials: [Self.glowMaterial(.cyan, intensity: 1.6, alpha: 0.18)]
        )
        disc.name = "HoloDisc"
        projectionRoot.addChild(disc)

        // Concentric range rings + crosshair grid drawn as thin glowing tori/bars.
        addGrid(to: projectionRoot)

        // Slowly rotating radar sweep wedge for that "scanning" feel.
        let sweep = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(Self.radius, 0.0015, 0.004), cornerRadius: 0.001),
            materials: [Self.glowMaterial(.cyan, intensity: 4.0, alpha: 0.5)]
        )
        sweep.name = "HoloSweep"
        sweep.position = SIMD3<Float>(Self.radius / 2.0, 0.001, 0)
        let sweepPivot = Entity()
        sweepPivot.addChild(sweep)
        projectionRoot.addChild(sweepPivot)
        sweepRing = sweep
        sweepPivotRef = sweepPivot

        // --- Central BLUE sphere: our drone. ---
        playerMarker.model = ModelComponent(
            mesh: .generateSphere(radius: 0.008),
            materials: [Self.glowMaterial(.systemBlue, intensity: 8.0, alpha: 1.0)]
        )
        playerMarker.name = "HoloPlayerMarker"
        playerMarker.position = SIMD3<Float>(0, 0.006, 0)
        projectionRoot.addChild(playerMarker)

        // A little vertical stem under our drone marker so its height reads clearly.
        projectionRoot.addChild(blipRoot)

        // Mode caption floating along the front rim.
        Self.applyLabel("TACTICAL", to: modeLabelNode, color: .cyan)
        modeLabelNode.name = "HoloModeLabel"
        modeLabelNode.position = SIMD3<Float>(0, 0.012, Self.radius + 0.012)
        projectionRoot.addChild(modeLabelNode)
        lastModeLabel = "TACTICAL"

        // Faint cyan point light so the projection casts a glow on the deck.
        var light = PointLightComponent(color: .cyan, intensity: 1200, attenuationRadius: 0.4)
        light.attenuationRadius = 0.4
        let lightNode = Entity()
        lightNode.components.set(light)
        lightNode.position = SIMD3<Float>(0, 0.03, 0)
        projectionRoot.addChild(lightNode)
    }

    private weak var sweepPivotRef: Entity?

    /// Adds two concentric range rings and a faint crosshair to the disc.
    private func addGrid(to parent: Entity) {
        for frac in [Float(0.5), Float(1.0)] {
            let ring = ModelEntity(
                mesh: .generateCylinder(height: 0.0008, radius: Self.radius * frac),
                materials: [Self.glowMaterial(.cyan, intensity: 2.5, alpha: 0.35)]
            )
            // Hollow look: nest a slightly smaller dark disc to fake a ring outline.
            let inner = ModelEntity(
                mesh: .generateCylinder(height: 0.001, radius: Self.radius * frac - 0.0025),
                materials: [UnlitMaterial(color: UIColor.black.withAlphaComponent(0.0))]
            )
            ring.addChild(inner)
            ring.position = SIMD3<Float>(0, 0.0006, 0)
            parent.addChild(ring)
        }

        for angle in [Float(0), Float.pi / 2] {
            let bar = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(Self.radius * 2, 0.0006, 0.0015)),
                materials: [Self.glowMaterial(.cyan, intensity: 1.5, alpha: 0.18)]
            )
            bar.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            bar.position = SIMD3<Float>(0, 0.0007, 0)
            parent.addChild(bar)
        }
    }

    // MARK: - Per-frame update

    /// Plot our drone (center) and every blip relative to it. `modeLabel` lets the
    /// caller relabel the readout per game mode. Cheap to call every HUD tick.
    public func updateHologram(playerWorld: SIMD3<Float>,
                               blips: [Blip],
                               modeLabel: String,
                               time: TimeInterval) {
        guard isEnabled else { return }

        // Spin the sweep + gently bob/pulse the whole projection.
        sweepPivotRef?.orientation = simd_quatf(angle: Float(time) * 1.6, axis: SIMD3<Float>(0, 1, 0))
        let pulse = 1.0 + 0.04 * Float(sin(time * 2.2))
        projectionRoot.scale = SIMD3<Float>(repeating: pulse)

        if modeLabel != lastModeLabel {
            Self.applyLabel(modeLabel, to: modeLabelNode, color: .cyan)
            lastModeLabel = modeLabel
        }

        let scale = Self.radius / Self.worldRange

        // Grow/shrink the reusable marker pool to fit this frame's blip count.
        ensurePool(count: blips.count)

        for (i, blip) in blips.enumerated() {
            let marker = markerPool[i]
            marker.isEnabled = true

            let delta = blip.worldPosition - playerWorld
            var local = SIMD3<Float>(delta.x * scale,
                                     0.006 + delta.y * scale * Self.verticalScale,
                                     delta.z * scale)

            // Clamp horizontal reach to the disc rim so distant contacts sit on the
            // edge instead of flying off the projection.
            let horiz = SIMD2<Float>(local.x, local.z)
            let mag = simd_length(horiz)
            if mag > Self.radius {
                let clamped = horiz / mag * Self.radius
                local.x = clamped.x
                local.z = clamped.y
            }
            marker.position = local

            // Recolor only when needed.
            marker.model?.materials = [Self.glowMaterial(blip.color, intensity: 7.0, alpha: 1.0)]
        }

        // Hide any leftover markers from a previous, busier frame.
        if blips.count < markerPool.count {
            for i in blips.count..<markerPool.count { markerPool[i].isEnabled = false }
        }
    }

    private func ensurePool(count: Int) {
        while markerPool.count < count {
            let marker = ModelEntity(
                mesh: .generateSphere(radius: 0.007),
                materials: [Self.glowMaterial(.systemRed, intensity: 7.0, alpha: 1.0)]
            )
            marker.name = "HoloBlip_\(markerPool.count)"
            marker.isEnabled = false
            blipRoot.addChild(marker)
            markerPool.append(marker)
        }
    }

    // MARK: - Materials / text

    /// Bright, partially transparent unlit material — the holographic look.
    private static func glowMaterial(_ color: UIColor, intensity: CGFloat, alpha: CGFloat) -> RealityKit.Material {
        var m = UnlitMaterial(color: color.withAlphaComponent(alpha))
        m.blending = .transparent(opacity: .init(floatLiteral: Float(alpha)))
        // UnlitMaterial already reads as emissive; intensity is folded into the
        // base color brightness for a punchy neon pop on brighter elements.
        let boosted = Self.brighten(color, by: min(intensity / 8.0, 1.0))
        m.color = .init(tint: boosted.withAlphaComponent(alpha))
        return m
    }

    private static func brighten(_ color: UIColor, by t: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if !canImport(UIKit) && canImport(AppKit)
        // NSColor.getRed traps for catalog/named colors not in an RGB space, so
        // convert into sRGB first (UIColor handles this implicitly).
        let rgb = color.usingColorSpace(.sRGB) ?? color
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return UIColor(red: min(1, r + (1 - r) * t * 0.4),
                       green: min(1, g + (1 - g) * t * 0.4),
                       blue: min(1, b + (1 - b) * t * 0.4),
                       alpha: a)
    }

    private static func applyLabel(_ string: String, to node: ModelEntity, color: UIColor) {
        let mesh = MeshResource.generateText(
            string,
            extrusionDepth: 0.0005,
            font: .monospacedSystemFont(ofSize: 0.05, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byClipping
        )
        node.model = ModelComponent(mesh: mesh, materials: [UnlitMaterial(color: color)])
        node.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        let s: Float = 0.03
        node.scale = SIMD3<Float>(repeating: s)
        let c = mesh.bounds.center
        node.position = SIMD3<Float>(-c.x * s, node.position.y, node.position.z + c.y * s)
    }
}
