//
//  PillarSkin.swift
//  HelicopterGame
//
//  Visual "skins" for the GamepadPillarEntity column + foot. Each skin pairs a
//  physically-based metal material with arcade-style lighting accents (vertical
//  neon light strips running up the column and stacked emissive glow rings) so
//  the controller stand reads like a cabinet pulled off an arcade floor.
//
//  Add a new look by adding a case + an entry in `style`. The accents are built
//  generically from the style, so a new skin is purely data — no new geometry
//  code required.
//

import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum PillarSkin: String, CaseIterable, Sendable {

    /// Polished chrome with electric-cyan neon — the default arcade look.
    case neonChrome

    /// Dark gunmetal / carbon with molten orange-red glow rings.
    case magmaCarbon

    /// Brushed titanium with a holographic violet/magenta pulse.
    case holoViolet

    /// The skin applied when a pillar is built without an explicit choice.
    public static let `default`: PillarSkin = .neonChrome

    // MARK: - Style data

    /// Tunable appearance values backing each skin.
    public struct Style {
        public var columnColor: UIColor
        public var columnRoughness: Float
        public var columnMetallic: Float
        public var footColor: UIColor
        public var footRoughness: Float
        public var footMetallic: Float
        /// Emissive color shared by the light strips, glow rings and base halo.
        public var accentColor: UIColor
        /// Emissive intensity for the accents (higher = brighter bloom).
        public var accentIntensity: Float
        /// Number of vertical neon strips spaced evenly around the column.
        public var stripCount: Int
        /// Number of horizontal glow rings stacked up the column.
        public var ringCount: Int
    }

    public var style: Style {
        switch self {
        case .neonChrome:
            return Style(
                columnColor: UIColor(white: 0.78, alpha: 1.0),
                columnRoughness: 0.12,
                columnMetallic: 1.0,
                footColor: UIColor(white: 0.10, alpha: 1.0),
                footRoughness: 0.35,
                footMetallic: 0.9,
                accentColor: UIColor(red: 0.10, green: 0.95, blue: 1.0, alpha: 1.0),
                accentIntensity: 3.0,
                stripCount: 4,
                ringCount: 3
            )
        case .magmaCarbon:
            return Style(
                columnColor: UIColor(white: 0.06, alpha: 1.0),
                columnRoughness: 0.45,
                columnMetallic: 0.85,
                footColor: UIColor(white: 0.03, alpha: 1.0),
                footRoughness: 0.6,
                footMetallic: 0.7,
                accentColor: UIColor(red: 1.0, green: 0.32, blue: 0.05, alpha: 1.0),
                accentIntensity: 4.0,
                stripCount: 6,
                ringCount: 4
            )
        case .holoViolet:
            return Style(
                columnColor: UIColor(white: 0.55, alpha: 1.0),
                columnRoughness: 0.25,
                columnMetallic: 0.95,
                footColor: UIColor(white: 0.08, alpha: 1.0),
                footRoughness: 0.4,
                footMetallic: 0.85,
                accentColor: UIColor(red: 0.72, green: 0.25, blue: 1.0, alpha: 1.0),
                accentIntensity: 3.5,
                stripCount: 5,
                ringCount: 5
            )
        }
    }

    // MARK: - Materials

    public func columnMaterial() -> RealityKit.Material {
        let s = style
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: s.columnColor)
        m.roughness = .init(floatLiteral: s.columnRoughness)
        m.metallic = .init(floatLiteral: s.columnMetallic)
        return m
    }

    public func footMaterial() -> RealityKit.Material {
        let s = style
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: s.footColor)
        m.roughness = .init(floatLiteral: s.footRoughness)
        m.metallic = .init(floatLiteral: s.footMetallic)
        return m
    }

    /// Bright, self-lit material used for every accent (strips, rings, halo).
    public func accentMaterial() -> RealityKit.Material {
        let s = style
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: s.accentColor)
        m.roughness = .init(floatLiteral: 0.2)
        m.metallic = .init(floatLiteral: 0.0)
        m.emissiveColor = .init(color: s.accentColor)
        m.emissiveIntensity = s.accentIntensity
        return m
    }

    // MARK: - Accent geometry

    /// Builds the arcade lighting accents for a column of the given height/radius
    /// and parents them under `column` (whose local origin is its own center).
    /// Returns the entities added so callers could animate them later.
    @discardableResult
    public func addAccents(to column: Entity, columnHeight: Float, columnRadius: Float) -> [Entity] {
        let s = style
        var added: [Entity] = []

        // --- Vertical neon light strips inset into the column surface ---
        let stripHeight = columnHeight * 0.82
        let stripRadius = columnRadius + 0.001
        for i in 0..<max(s.stripCount, 0) {
            let angle = (Float(i) / Float(s.stripCount)) * 2.0 * .pi
            let strip = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.005, stripHeight, 0.005), cornerRadius: 0.0025),
                materials: [accentMaterial()]
            )
            strip.name = "PillarStrip_\(i)"
            strip.position = SIMD3<Float>(cos(angle) * stripRadius, 0, sin(angle) * stripRadius)
            column.addChild(strip)
            added.append(strip)
        }

        // --- Horizontal glow rings stacked up the column ---
        // Flattened, slightly oversized cylinders read as glowing bands.
        if s.ringCount > 0 {
            let ringRadius = columnRadius + 0.004
            let usable = columnHeight * 0.8
            let spacing = usable / Float(s.ringCount + 1)
            for i in 0..<s.ringCount {
                let ring = ModelEntity(
                    mesh: .generateCylinder(height: 0.006, radius: ringRadius),
                    materials: [accentMaterial()]
                )
                ring.name = "PillarRing_\(i)"
                let y = -usable / 2.0 + spacing * Float(i + 1)
                ring.position = SIMD3<Float>(0, y, 0)
                column.addChild(ring)
                added.append(ring)
            }
        }

        return added
    }

    /// A wide, flat glowing halo to sit just above the foot for floor bloom.
    public func makeBaseHalo(columnRadius: Float) -> Entity {
        let halo = ModelEntity(
            mesh: .generateCylinder(height: 0.004, radius: columnRadius * 3.0),
            materials: [accentMaterial()]
        )
        halo.name = "PillarBaseHalo"
        return halo
    }
}
