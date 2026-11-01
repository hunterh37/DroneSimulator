//
//  SafariWorldBuilder.swift
//  HelicopterGame
//
//  Life-size (1 unit = 1 m) stylized low-poly island with distinct explorable areas.
//

import RealityKit
import UIKit
import simd

/// Tags an explorable area. Discovery is checked by SafariManager against the drone position.
struct SafariAreaComponent: Component {
    var area: SafariArea
}

enum SafariArea: String, CaseIterable, Identifiable {
    case meadow, pineForest, lilyPond, mushroomGrove, crystalHills

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meadow: return "Sunny Meadow"
        case .pineForest: return "Whispering Pines"
        case .lilyPond: return "Lily Pond"
        case .mushroomGrove: return "Mushroom Grove"
        case .crystalHills: return "Crystal Hills"
        }
    }

    /// Area center on the XZ plane (meters) and radius.
    var center: SIMD2<Float> {
        switch self {
        case .meadow: return [0, -9]
        case .pineForest: return [-22, -20]
        case .lilyPond: return [20, -18]
        case .mushroomGrove: return [-18, 10]
        case .crystalHills: return [18, 14]
        }
    }

    var radius: Float { self == .meadow ? 8 : 10 }

    var critterMix: [SafariCritterKind] {
        switch self {
        case .meadow: return [.bunny, .chick, .bee]
        case .pineForest: return [.bunny, .owlet, .bee]
        case .lilyPond: return [.frog, .chick]
        case .mushroomGrove: return [.shroomling, .frog, .owlet]
        case .crystalHills: return [.slime, .bee, .chick]
        }
    }
}

@MainActor
enum SafariWorldBuilder {
    static let islandRadius: Float = 42

    private static let grass = UIColor(red: 0.47, green: 0.74, blue: 0.36, alpha: 1)
    private static let grassDark = UIColor(red: 0.33, green: 0.60, blue: 0.30, alpha: 1)
    private static let dirt = UIColor(red: 0.62, green: 0.46, blue: 0.33, alpha: 1)
    private static let bark = UIColor(red: 0.48, green: 0.33, blue: 0.24, alpha: 1)
    private static let stone = UIColor(red: 0.66, green: 0.68, blue: 0.72, alpha: 1)

    static func build() -> Entity {
        let root = Entity()
        root.name = "SafariWorld"
        var rng = SplitMix(seed: 0x5AFA21)

        root.addChild(makeTerrain())
        root.addChild(makeSun())

        for area in SafariArea.allCases {
            let marker = Entity()
            marker.name = "SafariArea_\(area.rawValue)"
            marker.position = [area.center.x, 0, area.center.y]
            marker.components.set(SafariAreaComponent(area: area))
            root.addChild(marker)
        }

        decorateMeadow(root, &rng)
        decorateForest(root, &rng)
        decoratePond(root, &rng)
        decorateMushrooms(root, &rng)
        decorateCrystals(root, &rng)
        decorateRim(root, &rng)
        return root
    }

    /// Terrain height in meters. Flat (0) near spawn and area floors, rolling toward the rim.
    static func height(x: Float, z: Float) -> Float {
        let d = sqrt(x * x + z * z)
        let rolling = (sin(x * 0.23) * cos(z * 0.19) + sin((x + z) * 0.11)) * 0.35
        let rimRise = max(0, d - islandRadius * 0.72) * 0.35
        let spawnFlatten = min(1, max(0, (d - 4) / 6))
        let pondDip = max(0, 1 - simd_length(SIMD2(x, z) - SafariArea.lilyPond.center) / 7) * -0.6
        return (rolling * spawnFlatten) + rimRise + pondDip
    }

    // MARK: - Base

    private static func makeTerrain() -> Entity {
        let mesh = LowPolyMesh.terrain(radius: islandRadius, rings: 22, segments: 56, heightFn: height)
        let e = ModelEntity(mesh: mesh, materials: [LowPolyMesh.material(grass, roughness: 0.9, clearcoat: 0)])
        e.name = "SafariTerrain"
        return e
    }

    private static func makeSun() -> Entity {
        let sun = Entity()
        var light = DirectionalLightComponent(color: UIColor(red: 1, green: 0.95, blue: 0.86, alpha: 1), intensity: 2800)
        sun.components.set(light)
        sun.components.set(DirectionalLightComponent.Shadow(maximumDistance: 30, depthBias: 2))
        sun.look(at: .zero, from: [12, 25, 10], relativeTo: nil)
        return sun
    }

    // MARK: - Props

    private static func place(_ e: Entity, _ root: Entity, x: Float, z: Float, yaw: Float = 0, scale: Float = 1) {
        e.position = [x, height(x: x, z: z), z]
        e.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        e.scale = .init(repeating: scale)
        root.addChild(e)
    }

    private static func scatter(around c: SIMD2<Float>, radius: Float, _ rng: inout SplitMix) -> SIMD2<Float> {
        let a = Float.random(in: 0..<(2 * .pi), using: &rng)
        let r = sqrt(Float.random(in: 0...1, using: &rng)) * radius
        return c + SIMD2(cos(a), sin(a)) * r
    }

    static func model(_ mesh: MeshResource, _ color: UIColor, y: Float = 0, rough: Float = 0.7, emissive: Float = 0, shadow: Bool = true) -> ModelEntity {
        let m = ModelEntity(mesh: mesh, materials: [LowPolyMesh.material(color, roughness: rough, emissive: emissive)])
        m.position.y = y
        if shadow { m.components.set(GroundingShadowComponent(castsShadow: true)) }
        return m
    }

    private static func pineTree(height h: Float, _ rng: inout SplitMix) -> Entity {
        let tree = Entity()
        tree.addChild(model(LowPolyMesh.frustum(bottomRadius: 0.35, topRadius: 0.22, height: h * 0.3, segments: 6), bark))
        let tint = [grassDark, UIColor(red: 0.24, green: 0.52, blue: 0.36, alpha: 1), UIColor(red: 0.30, green: 0.58, blue: 0.32, alpha: 1)]
        let color = tint[Int.random(in: 0..<tint.count, using: &rng)]
        for i in 0..<3 {
            let t = Float(i)
            let tier = model(LowPolyMesh.frustum(bottomRadius: h * (0.26 - t * 0.06), topRadius: 0, height: h * 0.42, segments: 7), color, y: h * (0.22 + t * 0.2))
            tree.addChild(tier)
        }
        return tree
    }

    private static func roundTree(height h: Float, _ rng: inout SplitMix) -> Entity {
        let tree = Entity()
        tree.addChild(model(LowPolyMesh.frustum(bottomRadius: 0.3, topRadius: 0.2, height: h * 0.5, segments: 6), bark))
        let seed = UInt64.random(in: 0..<6, using: &rng)
        tree.addChild(model(LowPolyMesh.icosphere(radius: h * 0.32, subdivisions: 1, jitter: 0.12, seed: seed), grass, y: h * 0.68))
        tree.addChild(model(LowPolyMesh.icosphere(radius: h * 0.2, subdivisions: 1, jitter: 0.1, seed: seed + 9), grassDark, y: h * 0.52).then { $0.position.x = h * 0.22 })
        return tree
    }

    private static func flower(_ color: UIColor) -> Entity {
        let f = Entity()
        f.addChild(model(LowPolyMesh.frustum(bottomRadius: 0.012, topRadius: 0.01, height: 0.32, segments: 4), grassDark, shadow: false))
        f.addChild(model(LowPolyMesh.icosphere(radius: 0.07, subdivisions: 0), color, y: 0.34, shadow: false))
        f.addChild(model(LowPolyMesh.icosphere(radius: 0.03, subdivisions: 0), .systemYellow, y: 0.38, shadow: false))
        return f
    }

    private static func rock(_ size: Float, seed: UInt64) -> ModelEntity {
        let r = model(LowPolyMesh.icosphere(radius: size, subdivisions: 0, jitter: 0.25, seed: seed), stone, rough: 0.85)
        r.scale = [1, 0.6, 1]
        return r
    }

    // MARK: - Areas

    private static func decorateMeadow(_ root: Entity, _ rng: inout SplitMix) {
        let colors: [UIColor] = [.systemPink, .white, .systemPurple, .systemOrange, UIColor(red: 1, green: 0.5, blue: 0.6, alpha: 1)]
        for _ in 0..<70 {
            let p = scatter(around: SafariArea.meadow.center, radius: 9, &rng)
            place(flower(colors[Int.random(in: 0..<colors.count, using: &rng)]), root, x: p.x, z: p.y, yaw: Float.random(in: 0...6, using: &rng), scale: Float.random(in: 0.8...1.4, using: &rng))
        }
        for i in 0..<5 {
            let p = scatter(around: SafariArea.meadow.center, radius: 11, &rng)
            place(roundTree(height: Float.random(in: 4...6, using: &rng), &rng), root, x: p.x + (i % 2 == 0 ? 6 : -6), z: p.y)
        }
        // Wooden fence arc along the meadow edge.
        for i in 0..<10 {
            let a = Float(i) / 10 * .pi + .pi
            let x = SafariArea.meadow.center.x + cos(a) * 9.5, z = SafariArea.meadow.center.y + sin(a) * 9.5 - 2
            let post = model(LowPolyMesh.frustum(bottomRadius: 0.07, topRadius: 0.06, height: 1.1, segments: 5), bark)
            place(post, root, x: x, z: z)
        }
    }

    private static func decorateForest(_ root: Entity, _ rng: inout SplitMix) {
        for _ in 0..<26 {
            let p = scatter(around: SafariArea.pineForest.center, radius: 12, &rng)
            place(pineTree(height: Float.random(in: 7...11, using: &rng), &rng), root, x: p.x, z: p.y, yaw: Float.random(in: 0...6, using: &rng))
        }
        for i in 0..<8 {
            let p = scatter(around: SafariArea.pineForest.center, radius: 10, &rng)
            place(rock(Float.random(in: 0.4...1.1, using: &rng), seed: UInt64(i)), root, x: p.x, z: p.y)
        }
    }

    private static func decoratePond(_ root: Entity, _ rng: inout SplitMix) {
        let c = SafariArea.lilyPond.center
        let water = UIColor(red: 0.30, green: 0.66, blue: 0.86, alpha: 1)
        let pond = model(LowPolyMesh.frustum(bottomRadius: 6.5, topRadius: 6.5, height: 0.05, segments: 14), water, rough: 0.05, shadow: false)
        var mat = LowPolyMesh.material(water, roughness: 0.05, clearcoat: 1)
        mat.blending = .transparent(opacity: 0.82)
        pond.model?.materials = [mat]
        pond.position = [c.x, -0.28, c.y]
        root.addChild(pond)
        for _ in 0..<14 {
            let p = scatter(around: c, radius: 5, &rng)
            let pad = model(LowPolyMesh.frustum(bottomRadius: 0.35, topRadius: 0.35, height: 0.02, segments: 7), grassDark, shadow: false)
            pad.position = [p.x, -0.22, p.y]
            root.addChild(pad)
        }
        for i in 0..<18 {
            let a = Float(i) / 18 * 2 * .pi
            let x = c.x + cos(a) * 7, z = c.y + sin(a) * 7
            place(rock(Float.random(in: 0.3...0.6, using: &rng), seed: UInt64(i + 20)), root, x: x, z: z)
            if i % 3 == 0 {
                let reed = model(LowPolyMesh.frustum(bottomRadius: 0.05, topRadius: 0, height: 1.4, segments: 4), grassDark)
                place(reed, root, x: x * 0.98 + c.x * 0.02, z: z)
            }
        }
    }

    private static func decorateMushrooms(_ root: Entity, _ rng: inout SplitMix) {
        let caps: [UIColor] = [UIColor(red: 0.92, green: 0.26, blue: 0.28, alpha: 1), UIColor(red: 0.98, green: 0.62, blue: 0.3, alpha: 1), UIColor(red: 0.72, green: 0.45, blue: 0.9, alpha: 1)]
        for _ in 0..<16 {
            let p = scatter(around: SafariArea.mushroomGrove.center, radius: 10, &rng)
            let h = Float.random(in: 1.5...5.5, using: &rng)
            let shroom = Entity()
            shroom.addChild(model(LowPolyMesh.frustum(bottomRadius: h * 0.12, topRadius: h * 0.08, height: h, segments: 7), UIColor(red: 0.96, green: 0.92, blue: 0.84, alpha: 1)))
            let cap = model(LowPolyMesh.icosphere(radius: h * 0.42, subdivisions: 1), caps[Int.random(in: 0..<caps.count, using: &rng)], y: h, rough: 0.45, emissive: 0.08)
            cap.scale = [1, 0.55, 1]
            shroom.addChild(cap)
            for s in 0..<4 {
                let a = Float(s) * 1.7
                shroom.addChild(model(LowPolyMesh.icosphere(radius: h * 0.06, subdivisions: 0), .white, y: h + h * 0.2, shadow: false).then {
                    $0.position.x = cos(a) * h * 0.26; $0.position.z = sin(a) * h * 0.26
                })
            }
            place(shroom, root, x: p.x, z: p.y, yaw: Float.random(in: 0...6, using: &rng))
        }
    }

    private static func decorateCrystals(_ root: Entity, _ rng: inout SplitMix) {
        let tones: [UIColor] = [UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1), UIColor(red: 0.85, green: 0.6, blue: 1, alpha: 1), UIColor(red: 0.6, green: 1, blue: 0.85, alpha: 1)]
        for i in 0..<12 {
            let p = scatter(around: SafariArea.crystalHills.center, radius: 10, &rng)
            place(rock(Float.random(in: 1.2...2.6, using: &rng), seed: UInt64(i + 40)), root, x: p.x, z: p.y)
        }
        for _ in 0..<22 {
            let p = scatter(around: SafariArea.crystalHills.center, radius: 9, &rng)
            let h = Float.random(in: 0.8...3.2, using: &rng)
            let crystal = model(LowPolyMesh.frustum(bottomRadius: h * 0.18, topRadius: 0, height: h, segments: 5), tones[Int.random(in: 0..<tones.count, using: &rng)], rough: 0.1, emissive: 0.6)
            crystal.orientation = simd_quatf(angle: Float.random(in: -0.35...0.35, using: &rng), axis: normalize([1, 0, 0.4]))
            place(crystal, root, x: p.x, z: p.y, yaw: Float.random(in: 0...6, using: &rng))
        }
    }

    private static func decorateRim(_ root: Entity, _ rng: inout SplitMix) {
        for i in 0..<30 {
            let a = Float(i) / 30 * 2 * .pi + Float.random(in: -0.08...0.08, using: &rng)
            let r = islandRadius * Float.random(in: 0.8...0.93, using: &rng)
            let x = cos(a) * r, z = sin(a) * r
            if i % 2 == 0 {
                place(pineTree(height: Float.random(in: 9...13, using: &rng), &rng), root, x: x, z: z)
            } else {
                place(rock(Float.random(in: 1.5...3, using: &rng), seed: UInt64(i + 70)), root, x: x, z: z)
            }
        }
        // Dirt paths from spawn to each area.
        for area in SafariArea.allCases {
            let steps = Int(simd_length(area.center) / 1.6)
            for s in 1..<max(steps, 2) {
                let p = area.center * (Float(s) / Float(steps))
                let stoneTile = model(LowPolyMesh.frustum(bottomRadius: 0.45, topRadius: 0.4, height: 0.04, segments: 6), dirt, rough: 0.95, shadow: false)
                place(stoneTile, root, x: p.x, z: p.y, yaw: Float(s))
            }
        }
    }
}

extension Entity {
    @discardableResult
    func then(_ configure: (Self) -> Void) -> Self { configure(self); return self }
}
